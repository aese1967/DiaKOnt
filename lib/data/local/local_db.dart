import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;

import 'default_data.dart';

/// Tablas sincronizadas y sus columnas (se copian tal cual al archivo de
/// datos de cada dispositivo en la nube).
///
/// Orden lógico: grupos y categorías antes que los
/// gastos que los referencian.
const Map<String, List<String>> kSyncTables = {
  'expense_groups': [
    'id',
    'user_id',
    'name',
    'color',
    'icon',
    'sort_order',
    'created_at',
    'updated_at',
    'deleted',
  ],
  'categories': [
    'id',
    'user_id',
    'name',
    'color',
    'icon',
    'default_group_id',
    'sort_order',
    'created_at',
    'updated_at',
    'deleted',
  ],
  'expenses': [
    'id',
    'user_id',
    'date',
    'concept',
    'category_id',
    'group_id',
    'subtotal_cents',
    'vat_cents',
    'total_cents',
    'vat_rate_bp',
    'vat_included',
    'notes',
    'created_at',
    'updated_at',
    'deleted',
  ],
  'user_settings': [
    'id',
    'user_id',
    'default_vat_rate_bp',
    'monthly_budget_cents',
    'currency',
    'default_vat_included',
    'created_at',
    'updated_at',
    'deleted',
  ],
};

/// Columnas booleanas: SQLite las guarda como 0/1, Postgres como boolean.
const Set<String> kBoolColumns = {
  'deleted',
  'vat_included',
  'default_vat_included',
};

/// Base de datos local (SQLite) — la "fuente de verdad" de la interfaz.
///
/// La app SIEMPRE lee y escribe aquí, por lo que funciona igual con o sin
/// conexión. Cada escritura del usuario marca la fila con `dirty = 1`; el
/// [SyncService] sube esas filas a Drive/OneDrive y baja los cambios de los
/// otros dispositivos.
///
/// Hay un archivo por usuario (`diakont_<uid>.db`), así cerrar sesión y entrar
/// con otra cuenta nunca mezcla datos.
class LocalDb {
  LocalDb._(this.raw);

  /// Acceso directo a sqflite (usado por repositorios y sincronización).
  final Database raw;

  final _changes = StreamController<String>.broadcast();
  final _localWrites = StreamController<String>.broadcast();

  /// Emite el nombre de la tabla cada vez que cambia (por el usuario o por la
  /// sincronización). La interfaz lo usa para refrescarse sola.
  Stream<String> get changes => _changes.stream;

  /// Emite solo cuando el cambio lo hizo el usuario en ESTE dispositivo.
  /// El motor de sincronización lo usa para subir cambios casi al instante.
  Stream<String> get localWrites => _localWrites.stream;

  static Future<LocalDb> open(String userId) async {
    // En Android sqflite usa el SQLite del sistema. En Windows (y otros
    // escritorios) se usa la implementación FFI con sqlite3 empaquetado.
    final DatabaseFactory factory;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    } else {
      factory = databaseFactory;
    }

    final dir = await getApplicationSupportDirectory();
    return openWith(factory, p.join(dir.path, 'diakont_$userId.db'), userId);
  }

  /// Abre una base en una ruta concreta (usado también por los tests).
  static Future<LocalDb> openWith(
    DatabaseFactory factory,
    String path,
    String userId,
  ) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, v) async {
          await _onCreate(db, v);
          await seedDefaults(db, userId);
        },
      ),
    );
    return LocalDb._(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    // Columnas de control comunes a todas las tablas sincronizadas.
    const sync = '''
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      dirty INTEGER NOT NULL DEFAULT 0''';

    batch.execute('''
      CREATE TABLE expense_groups (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        icon TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        $sync
      )''');
    batch.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        icon TEXT NOT NULL,
        default_group_id TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        $sync
      )''');
    batch.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        date TEXT NOT NULL,
        concept TEXT NOT NULL,
        category_id TEXT,
        group_id TEXT,
        subtotal_cents INTEGER NOT NULL,
        vat_cents INTEGER NOT NULL,
        total_cents INTEGER NOT NULL,
        vat_rate_bp INTEGER NOT NULL,
        vat_included INTEGER NOT NULL,
        notes TEXT,
        $sync
      )''');
    batch.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    batch.execute('''
      CREATE TABLE user_settings (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        default_vat_rate_bp INTEGER NOT NULL DEFAULT 2200,
        monthly_budget_cents INTEGER NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'UYU',
        default_vat_included INTEGER NOT NULL DEFAULT 1,
        $sync
      )''');
    // Índice parcial para encontrar rápido lo pendiente de subir.
    for (final t in kSyncTables.keys) {
      batch.execute('CREATE INDEX idx_${t}_dirty ON $t(dirty) WHERE dirty = 1');
    }
    // Clave/valor para metadatos de sincronización (cursores).
    batch.execute('CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT)');
    await batch.commit(noResult: true);
  }

  /// Devuelve un stream que ejecuta [query] al suscribirse y de nuevo cada
  /// vez que cambia alguna de las [tables].
  Stream<T> watch<T>(Set<String> tables, Future<T> Function() query) async* {
    yield await query();
    await for (final table in changes) {
      if (tables.contains(table)) yield await query();
    }
  }

  /// Guarda (inserta o reemplaza) una fila editada por el usuario y la marca
  /// como pendiente de sincronizar.
  Future<void> writeLocal(String table, Map<String, Object?> row) async {
    final data = Map<String, Object?>.from(row)
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String()
      ..['dirty'] = 1;
    await raw.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyLocal(table);
  }

  /// Borrado lógico: se marca `deleted = 1` para que el borrado viaje a la
  /// nube y a los otros dispositivos.
  Future<void> softDelete(String table, String id) async {
    await raw.update(
      table,
      {
        'deleted': 1,
        'dirty': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyLocal(table);
  }

  /// Notifica a la UI un cambio que vino de la sincronización.
  void notifyRemote(String table) => _changes.add(table);

  void _notifyLocal(String table) {
    _changes.add(table);
    _localWrites.add(table);
  }

  Future<String?> getKv(String key) async {
    final rows = await raw.query('kv', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setKv(String key, String value) => raw.insert('kv', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  /// Cantidad de filas pendientes de subir (se muestra en Ajustes).
  Future<int> pendingCount() async {
    var total = 0;
    for (final t in kSyncTables.keys) {
      final r = await raw.rawQuery(
        'SELECT COUNT(*) AS c FROM $t WHERE dirty = 1',
      );
      total += (r.first['c'] as int?) ?? 0;
    }
    return total;
  }

  Future<void> close() async {
    await _changes.close();
    await _localWrites.close();
    await raw.close();
  }
}
