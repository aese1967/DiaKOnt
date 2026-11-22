import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Archivo remoto en la carpeta privada de la app.
class RemoteFile {
  const RemoteFile({
    required this.id,
    required this.name,
    required this.version,
  });
  final String id;
  final String name;

  /// Cambia cada vez que el archivo cambia (md5/modifiedTime en Drive, eTag
  /// en OneDrive). Sirve para no volver a bajar lo que ya se procesó.
  final String version;
}

class CloudException implements Exception {
  const CloudException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Contrato mínimo de almacenamiento: listar, bajar y subir archivos en una
/// carpeta que solo DiaKont puede ver. Implementado para Google Drive y
/// OneDrive con sus APIs REST (sin SDKs pesados).
abstract class CloudStore {
  Future<List<RemoteFile>> list();
  Future<Uint8List> download(RemoteFile file);
  Future<void> upload(String name, Uint8List bytes, {RemoteFile? existing});
}

typedef TokenGetter = Future<String> Function({bool forceRefresh});

/// Ejecuta una petición con el token y reintenta una vez si vence (401).
Future<http.Response> _authed(
  TokenGetter token,
  Future<http.Response> Function(Map<String, String> headers) send,
) async {
  var res = await send({'Authorization': 'Bearer ${await token()}'});
  if (res.statusCode == 401) {
    res = await send({
      'Authorization': 'Bearer ${await token(forceRefresh: true)}',
    });
  }
  if (res.statusCode >= 400) {
    throw CloudException(
      'Error de la nube (${res.statusCode}): ${res.body}',
      status: res.statusCode,
    );
  }
  return res;
}

// ---------------------------------------------------------------------------
// Google Drive: carpeta oculta "appDataFolder". El usuario no la ve en su
// Drive, no ocupa su lista de archivos y solo DiaKont puede leerla.
// ---------------------------------------------------------------------------
class GoogleDriveStore implements CloudStore {
  GoogleDriveStore(this._token);
  final TokenGetter _token;

  static const _api = 'https://www.googleapis.com/drive/v3/files';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';

  @override
  Future<List<RemoteFile>> list() async {
    final uri = Uri.parse(_api).replace(
      queryParameters: {
        'spaces': 'appDataFolder',
        'fields': 'files(id,name,modifiedTime,md5Checksum)',
        'pageSize': '1000',
      },
    );
    final res = await _authed(_token, (h) => http.get(uri, headers: h));
    final files = (jsonDecode(res.body)['files'] as List)
        .cast<Map<String, dynamic>>();
    return [
      for (final f in files)
        RemoteFile(
          id: f['id'] as String,
          name: f['name'] as String,
          version: '${f['md5Checksum'] ?? ''}@${f['modifiedTime']}',
        ),
    ];
  }

  @override
  Future<Uint8List> download(RemoteFile file) async {
    final res = await _authed(
      _token,
      (h) => http.get(Uri.parse('$_api/${file.id}?alt=media'), headers: h),
    );
    return res.bodyBytes;
  }

  @override
  Future<void> upload(
    String name,
    Uint8List bytes, {
    RemoteFile? existing,
  }) async {
    if (existing != null) {
      // Reemplaza el contenido del archivo existente.
      await _authed(
        _token,
        (h) => http.patch(
          Uri.parse('$_upload/${existing.id}?uploadType=media'),
          headers: {...h, 'Content-Type': 'application/octet-stream'},
          body: bytes,
        ),
      );
      return;
    }
    // Alta: subida multipart (metadatos + contenido) dentro de appDataFolder.
    const boundary = 'diakont_boundary_7f3a';
    final meta = jsonEncode({
      'name': name,
      'parents': ['appDataFolder'],
    });
    final body = BytesBuilder()
      ..add(
        utf8.encode(
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$meta\r\n',
        ),
      )
      ..add(
        utf8.encode(
          '--$boundary\r\nContent-Type: application/octet-stream\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));
    await _authed(
      _token,
      (h) => http.post(
        Uri.parse('$_upload?uploadType=multipart'),
        headers: {
          ...h,
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: body.toBytes(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OneDrive: carpeta de la app "Aplicaciones/DiaKont" (special/approot). Con
// el permiso Files.ReadWrite.AppFolder la app no puede ver otros archivos.
// ---------------------------------------------------------------------------
class OneDriveStore implements CloudStore {
  OneDriveStore(this._token);
  final TokenGetter _token;

  static const _root =
      'https://graph.microsoft.com/v1.0/me/drive/special/approot';

  /// Límite de la subida simple de Graph. Un hogar típico genera unos pocos
  /// KB por mes (comprimido), así que es holgado por muchos años.
  static const _simpleUploadLimit = 4 * 1024 * 1024;

  @override
  Future<List<RemoteFile>> list() async {
    final res = await _authed(
      _token,
      (h) => http.get(
        Uri.parse('$_root/children?\$select=id,name,eTag&\$top=999'),
        headers: h,
      ),
    );
    final items = (jsonDecode(res.body)['value'] as List)
        .cast<Map<String, dynamic>>();
    return [
      for (final f in items)
        RemoteFile(
          id: f['id'] as String,
          name: f['name'] as String,
          version: f['eTag'] as String? ?? '',
        ),
    ];
  }

  @override
  Future<Uint8List> download(RemoteFile file) async {
    final res = await _authed(
      _token,
      (h) => http.get(
        Uri.parse(
          'https://graph.microsoft.com/v1.0/me/drive/items/${file.id}/content',
        ),
        headers: h,
      ),
    );
    return res.bodyBytes;
  }

  @override
  Future<void> upload(
    String name,
    Uint8List bytes, {
    RemoteFile? existing,
  }) async {
    if (bytes.length > _simpleUploadLimit) {
      throw const CloudException('El archivo de datos supera 4 MB.');
    }
    await _authed(
      _token,
      (h) => http.put(
        Uri.parse('$_root:/${Uri.encodeComponent(name)}:/content'),
        headers: {...h, 'Content-Type': 'application/octet-stream'},
        body: bytes,
      ),
    );
  }
}
