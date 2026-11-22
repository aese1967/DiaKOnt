import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart' show AppLifecycleListener;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../cloud/cloud_store.dart';
import '../local/local_db.dart';

enum SyncPhase { idle, syncing, offline, error }

/// Estado visible del motor de sincronización.
class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.pending = 0,
    this.lastSyncAt,
    this.error,
  });

  final SyncPhase phase;

  /// Cambios locales que todavía no llegaron a la nube.
  final int pending;
  final DateTime? lastSyncAt;
  final String? error;

  SyncStatus copyWith({
    SyncPhase? phase,
    int? pending,
    DateTime? lastSyncAt,
    String? error,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    pending: pending ?? this.pending,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    error: error,
  );
}

/// Sincronización offline-first SIN servidor, usando la nube del usuario.
///
/// ### Modelo: "un archivo por dispositivo"
/// Cada dispositivo (celular, PC…) escribe SOLO su propio archivo
/// `dk-device-<id>.json.gz` en la carpeta privada de la app, con una copia
/// completa de sus datos (incluidos los borrados lógicos). Para enterarse de
/// los cambios de los demás, lee los archivos de los otros dispositivos y los
/// fusiona fila por fila: **gana la versión con `updated_at` más reciente**.
///
/// Ventajas de este diseño:
/// * Dos dispositivos nunca escriben el mismo archivo → no hay choques de
///   escritura ni datos pisados, aunque ambos estén offline días.
/// * La fusión es idempotente y conmutativa: todos convergen al mismo
///   resultado, en cualquier orden.
/// * Funciona igual con Google Drive y con OneDrive (solo necesita listar,
///   bajar y subir archivos).
///
/// ### Cuándo sincroniza
/// * Al abrir la app y al volver a primer plano.
/// * ~3 s después de un cambio local (agrupando ráfagas).
/// * Al recuperar la conexión.
/// * Cada 60 s mientras la app está abierta (Drive/OneDrive no avisan en
///   tiempo real a apps sin servidor, así que se consulta periódicamente;
///   la consulta es una sola llamada liviana de "listar").
class SyncService {
  SyncService({required this.db, required this.store});

  final LocalDb db;
  final CloudStore store;

  static const _filePrefix = 'dk-device-';
  static const _fileSuffix = '.json.gz';
  static const _formatVersion = 1;

  final _statusCtrl = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = const SyncStatus();

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<String>? _localSub;
  AppLifecycleListener? _lifecycle;
  Timer? _debounce;
  Timer? _periodic;
  bool _running = false;
  bool _rerun = false;
  bool _disposed = false;
  String? _deviceId;

  SyncStatus get status => _status;

  Stream<SyncStatus> watchStatus() async* {
    yield _status;
    yield* _statusCtrl.stream;
  }

  void start() {
    _localSub = db.localWrites.listen(
      (_) => _schedule(const Duration(seconds: 3)),
    );
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        _schedule(const Duration(seconds: 1));
      } else {
        _emit(_status.copyWith(phase: SyncPhase.offline));
      }
    });
    _lifecycle = AppLifecycleListener(
      onResume: () => _schedule(const Duration(milliseconds: 500)),
    );
    _periodic = Timer.periodic(const Duration(seconds: 60), (_) => syncNow());
    unawaited(syncNow());
  }

  void _schedule(Duration delay) {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(delay, syncNow);
  }

  /// Id estable de ESTE dispositivo para esta cuenta.
  Future<String> _myDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    var id = await db.getKv('device_id');
    if (id == null) {
      id = const Uuid().v4();
      await db.setKv('device_id', id);
    }
    return _deviceId = id;
  }

  /// Un ciclo completo: bajar y fusionar lo de otros dispositivos, y subir
  /// el archivo propio si hay cambios locales. Nunca corren dos a la vez.
  Future<void> syncNow() async {
    if (_disposed) return;
    if (_running) {
      _rerun = true;
      return;
    }
    _running = true;
    try {
      do {
        _rerun = false;
        _emit(_status.copyWith(phase: SyncPhase.syncing));
        await _cycle();
      } while (_rerun && !_disposed);
      _emit(
        _status.copyWith(
          phase: SyncPhase.idle,
          lastSyncAt: DateTime.now(),
          pending: await db.pendingCount(),
        ),
      );
    } catch (e) {
      if (_disposed) return;
      final offline = _looksOffline(e);
      _emit(
        _status.copyWith(
          phase: offline ? SyncPhase.offline : SyncPhase.error,
          pending: await db.pendingCount(),
          error: offline ? null : e.toString(),
        ),
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _cycle() async {
    final me = await _myDeviceId();
    final myName = '$_filePrefix$me$_fileSuffix';
    final files = await store.list();

    // ---- 1. PULL: fusionar archivos de otros dispositivos que cambiaron.
    final changedTables = <String>{};
    for (final f in files) {
      if (!f.name.startsWith(_filePrefix) || f.name == myName) continue;
      final seenKey = 'seen:${f.name}';
      if (await db.getKv(seenKey) == f.version) continue; // sin cambios
      final snapshot = decodeSnapshot(await store.download(f));
      changedTables.addAll(await _merge(snapshot));
      await db.setKv(seenKey, f.version);
    }
    for (final t in changedTables) {
      db.notifyRemote(t);
    }

    // ---- 2. PUSH: subir el archivo propio si hay cambios o no existe aún.
    RemoteFile? mine;
    for (final f in files) {
      if (f.name == myName) mine = f;
    }
    if (mine != null && await db.pendingCount() == 0) return;

    final (bytes, uploaded) = await _buildSnapshot(me);
    await store.upload(myName, bytes, existing: mine);

    // Limpia `dirty` solo en filas que no se volvieron a editar mientras subía.
    final batch = db.raw.batch();
    for (final MapEntry(key: table, value: rows) in uploaded.entries) {
      for (final (id, updatedAt) in rows) {
        batch.update(
          table,
          {'dirty': 0},
          where: 'id = ? AND updated_at = ? AND dirty = 1',
          whereArgs: [id, updatedAt],
        );
      }
    }
    await batch.commit(noResult: true);
  }

  /// Arma el archivo propio: todas las filas de todas las tablas, comprimido.
  Future<(Uint8List, Map<String, List<(String, String)>>)> _buildSnapshot(
    String me,
  ) async {
    final tables = <String, List<Map<String, Object?>>>{};
    final dirty = <String, List<(String, String)>>{};
    for (final MapEntry(key: table, value: cols) in kSyncTables.entries) {
      final rows = await db.raw.query(table, columns: [...cols, 'dirty']);
      tables[table] = [
        for (final r in rows) {for (final c in cols) c: r[c]},
      ];
      dirty[table] = [
        for (final r in rows)
          if (r['dirty'] == 1) (r['id'] as String, r['updated_at'] as String),
      ];
    }
    return (encodeSnapshot(me, tables), dirty);
  }

  /// Fusiona un archivo remoto en la base local. Devuelve las tablas tocadas.
  Future<Set<String>> _merge(Map<String, List<Map<String, Object?>>> snapshot) {
    return db.raw.transaction((txn) async {
      final touched = <String>{};
      for (final MapEntry(key: table, value: cols) in kSyncTables.entries) {
        for (final remote
            in snapshot[table] ?? const <Map<String, Object?>>[]) {
          final id = remote['id'];
          final remoteUpdated = remote['updated_at'];
          if (id is! String || remoteUpdated is! String) continue;
          final local = await txn.query(
            table,
            columns: ['updated_at'],
            where: 'id = ?',
            whereArgs: [id],
          );
          if (local.isNotEmpty &&
              !isNewer(remoteUpdated, local.first['updated_at'] as String)) {
            continue; // lo local es igual o más nuevo
          }
          await txn.insert(table, {
            for (final c in cols) c: remote[c],
            'dirty': 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          touched.add(table);
        }
      }
      return touched;
    });
  }

  /// ¿`a` es estrictamente más reciente que `b`? (ISO-8601 UTC)
  static bool isNewer(String a, String b) =>
      DateTime.parse(a).isAfter(DateTime.parse(b));

  static Uint8List encodeSnapshot(
    String deviceId,
    Map<String, List<Map<String, Object?>>> tables,
  ) {
    final json = jsonEncode({
      'format': _formatVersion,
      'app': 'DiaKont',
      'device': deviceId,
      'written_at': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    });
    return Uint8List.fromList(gzip.encode(utf8.encode(json)));
  }

  static Map<String, List<Map<String, Object?>>> decodeSnapshot(
    Uint8List bytes,
  ) {
    final j =
        jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
    if ((j['format'] as int? ?? 0) > _formatVersion) {
      throw const CloudException(
        'Otro dispositivo usa una versión más nueva de DiaKont. Actualizá la app.',
      );
    }
    final tables = (j['tables'] as Map<String, dynamic>? ?? const {});
    return {
      for (final e in tables.entries)
        e.key: (e.value as List).cast<Map<String, dynamic>>(),
    };
  }

  bool _looksOffline(Object e) {
    if (e is SocketException ||
        e is TimeoutException ||
        e is HandshakeException) {
      return true;
    }
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection refused') ||
        s.contains('Network is unreachable');
  }

  void _emit(SyncStatus s) {
    _status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  Future<void> dispose() async {
    _disposed = true;
    _debounce?.cancel();
    _periodic?.cancel();
    _lifecycle?.dispose();
    await _connSub?.cancel();
    await _localSub?.cancel();
    await _statusCtrl.close();
  }
}
