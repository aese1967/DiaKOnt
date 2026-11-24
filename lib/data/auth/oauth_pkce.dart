import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Registro de los pasos del inicio de sesión. Si algo falla o se traba, el
/// mensaje de error dice en qué paso quedó y el detalle queda en
/// `%LOCALAPPDATA%\\DiaKont\\login.log` (Windows) para poder diagnosticarlo.
class AuthLog {
  AuthLog._();

  static String step = '';

  static void mark(String s) {
    step = s;
    _append(s);
  }

  static void error(Object e) => _append('ERROR en "$step": $e');

  static void _append(String line) {
    try {
      if (!Platform.isWindows) return;
      final base = Platform.environment['LOCALAPPDATA'];
      if (base == null) return;
      final dir = Directory('$base\\DiaKont')..createSync(recursive: true);
      File('${dir.path}\\login.log').writeAsStringSync(
        '${DateTime.now().toIso8601String()}  $line\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      /* el registro nunca debe romper el login */
    }
  }
}

/// Error de autenticación con mensaje listo para mostrar.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Configuración de un proveedor OAuth 2.0 (Google o Microsoft).
class OAuthConfig {
  const OAuthConfig({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.clientId,
    required this.scopes,
    this.clientSecret,
    this.mobileRedirectUri,
    this.mobileCallbackScheme,
    this.extraAuthParams = const {},
  });

  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String clientId;
  final String? clientSecret;
  final List<String> scopes;

  /// Redirect en Android (esquema propio de la app). En Windows se usa
  /// siempre un redirect loopback `http://localhost:<puerto>`.
  final String? mobileRedirectUri;
  final String? mobileCallbackScheme;
  final Map<String, String> extraAuthParams;
}

class OAuthTokens {
  const OAuthTokens({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
    this.idToken,
  });

  final String accessToken;
  final DateTime expiresAt;
  final String? refreshToken;
  final String? idToken;

  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 2)));

  factory OAuthTokens.fromJson(
    Map<String, dynamic> j, {
    String? previousRefresh,
  }) => OAuthTokens(
    accessToken: j['access_token'] as String,
    expiresAt: DateTime.now().add(
      Duration(seconds: (j['expires_in'] as num?)?.toInt() ?? 3600),
    ),
    // Microsoft rota el refresh token; Google a veces no devuelve uno nuevo.
    refreshToken: (j['refresh_token'] as String?) ?? previousRefresh,
    idToken: j['id_token'] as String?,
  );

  /// Lee el contenido (sin verificar firma) de un id_token JWT. Es seguro
  /// para datos de presentación porque el token llegó directo del proveedor
  /// por HTTPS en el canje del código.
  static Map<String, dynamic> decodeJwtPayload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length < 2) return const {};
    final normalized = base64Url.normalize(parts[1]);
    return jsonDecode(utf8.decode(base64Url.decode(normalized)))
        as Map<String, dynamic>;
  }
}

/// Flujo "Authorization Code + PKCE" (RFC 7636), el estándar para apps
/// instaladas, sin servidor propio:
/// * **Windows**: abre el navegador del sistema y recibe el código en un
///   mini servidor HTTP local (loopback, RFC 8252).
/// * **Android**: usa Custom Tabs / Auth Tab mediante `flutter_web_auth_2`
///   y vuelve a la app por un esquema propio.
class PkceOAuth {
  PkceOAuth._();

  static final _rnd = Random.secure();

  /// Permite al usuario abandonar un inicio de sesión en curso (por ejemplo,
  /// si cerró el navegador sin terminar).
  static Completer<void>? _cancel;
  static void cancel() {
    final c = _cancel;
    if (c != null && !c.isCompleted) c.complete();
  }

  static String _randomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    return List.generate(
      length,
      (_) => chars[_rnd.nextInt(chars.length)],
    ).join();
  }

  static String _challenge(String verifier) => base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');

  static Future<OAuthTokens> authorize(OAuthConfig cfg) async {
    AuthLog.mark('Preparando el inicio de sesión');
    final cancel = _cancel = Completer<void>();
    final verifier = _randomString(64);
    final state = _randomString(24);

    HttpServer? server;
    final String redirectUri;
    if (Platform.isAndroid || Platform.isIOS) {
      redirectUri = cfg.mobileRedirectUri!;
    } else {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      redirectUri = 'http://localhost:${server.port}';
    }

    final authUrl = Uri.parse(cfg.authorizationEndpoint).replace(
      queryParameters: {
        'client_id': cfg.clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': cfg.scopes.join(' '),
        'state': state,
        'code_challenge': _challenge(verifier),
        'code_challenge_method': 'S256',
        ...cfg.extraAuthParams,
      },
    );

    try {
      final Uri callback;
      if (server == null) {
        final result = await FlutterWebAuth2.authenticate(
          url: authUrl.toString(),
          callbackUrlScheme: cfg.mobileCallbackScheme!,
        );
        callback = Uri.parse(result);
      } else {
        AuthLog.mark('Abriendo el navegador');
        final launched = await launchUrl(
          authUrl,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          throw const AuthFailure('No se pudo abrir el navegador.');
        }
        AuthLog.mark('Esperando la respuesta del navegador');
        // Se atienden todas las peticiones (el navegador también pide
        // /favicon.ico y a veces abre conexiones de más): se responde a cada
        // una y se cierra, para que ninguna quede colgada.
        final got = Completer<HttpRequest>();
        final sub = server.listen((r) {
          final q = r.uri.queryParameters;
          if (!got.isCompleted &&
              (q.containsKey('code') || q.containsKey('error'))) {
            got.complete(r);
          } else {
            r.response.statusCode = HttpStatus.noContent;
            unawaited(r.response.close().catchError((_) {}));
          }
        });
        final HttpRequest request;
        try {
          request = await Future.any<HttpRequest?>([
            got.future,
            cancel.future.then((_) => null),
          ]).timeout(const Duration(minutes: 5)).then((r) {
            if (r == null) {
              throw const AuthFailure('Inicio de sesión cancelado.');
            }
            return r;
          });
        } finally {
          await sub.cancel().timeout(
            const Duration(seconds: 2),
            onTimeout: () {},
          );
        }
        callback = request.uri;
        final ok = callback.queryParameters['code'] != null;
        AuthLog.mark('Respuesta recibida (${ok ? 'con código' : 'sin código'})');
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..headers.set(HttpHeaders.connectionHeader, 'close')
          ..write(_callbackPage(ok));
        // No esperar indefinidamente a que el navegador cierre la conexión.
        await request.response
            .close()
            .timeout(const Duration(seconds: 5), onTimeout: () {})
            .catchError((_) {});
      }

      final params = callback.queryParameters;
      if (params['state'] != state) {
        throw const AuthFailure('Respuesta de inicio de sesión inválida.');
      }
      final code = params['code'];
      if (code == null) {
        throw AuthFailure(
          params['error_description'] ?? 'Inicio de sesión cancelado.',
        );
      }
      AuthLog.mark('Canjeando el código por los permisos');
      return await _token(cfg, {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': verifier,
      });
    } on TimeoutException {
      throw AuthFailure(
        'Se agotó el tiempo para iniciar sesión (${AuthLog.step}).',
      );
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
      await server
          ?.close(force: true)
          .timeout(const Duration(seconds: 2), onTimeout: () {})
          .catchError((_) {});
    }
  }

  static Future<OAuthTokens> refresh(OAuthConfig cfg, String refreshToken) =>
      _token(cfg, {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        // Microsoft pide repetir los scopes al refrescar.
        'scope': cfg.scopes.join(' '),
      }, previousRefresh: refreshToken);

  static Future<OAuthTokens> _token(
    OAuthConfig cfg,
    Map<String, String> body, {
    String? previousRefresh,
  }) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(cfg.tokenEndpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'client_id': cfg.clientId,
              if (cfg.clientSecret != null && cfg.clientSecret!.isNotEmpty)
                'client_secret': cfg.clientSecret!,
              ...body,
            },
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const AuthFailure(
        'El servidor de inicio de sesión no respondió. Revisá tu conexión '
        '(o la VPN/antivirus) y probá de nuevo.',
      );
    } on SocketException catch (e) {
      throw AuthFailure('Sin conexión con el servidor de inicio de sesión: '
          '${e.message}');
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } on FormatException {
      throw AuthFailure('Respuesta inesperada del servidor (${res.statusCode}).');
    }
    if (res.statusCode != 200) {
      final err = json['error'] as String?;
      if (err == 'invalid_grant') {
        throw const AuthFailure('La sesión expiró. Volvé a iniciar sesión.');
      }
      throw AuthFailure(
        json['error_description'] as String? ??
            'Error de autenticación ($err).',
      );
    }
    return OAuthTokens.fromJson(json, previousRefresh: previousRefresh);
  }

  static String _callbackPage(bool ok) =>
      '''
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>DiaKont</title>
<style>body{font-family:Segoe UI,system-ui,sans-serif;background:#0B2A55;color:#fff;
display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
.c{text-align:center}.b{font-size:56px}</style></head><body><div class="c">
<div class="b">${ok ? '✅' : '⚠️'}</div>
<h2>${ok ? '¡Listo! Ya podés volver a DiaKont.' : 'No se pudo iniciar sesión.'}</h2>
<p>Podés cerrar esta pestaña.</p></div></body></html>''';
}
