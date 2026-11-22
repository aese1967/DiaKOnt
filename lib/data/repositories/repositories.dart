/// Repositorios: la única puerta de la interfaz hacia los datos.
///
/// Leen y escriben SIEMPRE en la base local; la sincronización con la nube
/// ocurre sola en segundo plano. Los métodos `watch…` devuelven streams que
/// se actualizan cuando cambian los datos (local o remotamente).
library;

import '../local/local_db.dart';
import '../models/models.dart';

class ExpenseRepository {
  ExpenseRepository(this._db, this.userId);
  final LocalDb _db;
  final String userId;

  /// Todos los gastos vigentes, del más reciente al más antiguo.
  /// (Una casa genera pocos miles de registros por año: filtrar en memoria
  /// es instantáneo y simplifica los gráficos.)
  Stream<List<Expense>> watchAll() => _db.watch({'expenses'}, () async {
    final rows = await _db.raw.query(
      'expenses',
      where: 'deleted = 0',
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(Expense.fromRow).toList();
  });

  Future<void> save(Expense e) => _db.writeLocal('expenses', e.toRow());

  Future<void> delete(String id) => _db.softDelete('expenses', id);

  /// Deshacer un borrado (botón "Deshacer" del aviso).
  Future<void> restore(Expense e) =>
      _db.writeLocal('expenses', e.toRow()..['deleted'] = 0);

  /// Cantidad de gastos que usan una categoría o grupo (para avisar antes de
  /// borrarlos).
  Future<int> countUsing({String? categoryId, String? groupId}) async {
    final col = categoryId != null ? 'category_id' : 'group_id';
    final r = await _db.raw.rawQuery(
      'SELECT COUNT(*) AS c FROM expenses WHERE deleted = 0 AND $col = ?',
      [categoryId ?? groupId],
    );
    return (r.first['c'] as int?) ?? 0;
  }
}

class CategoryRepository {
  CategoryRepository(this._db, this.userId);
  final LocalDb _db;
  final String userId;

  /// Todas las categorías, incluidas las borradas (se necesitan para mostrar
  /// el nombre en gastos viejos). Usar `.where((c) => !c.deleted)` en listas.
  Stream<List<Category>> watchAll() => _db.watch({'categories'}, () async {
    final rows = await _db.raw.query(
      'categories',
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(Category.fromRow).toList();
  });

  Future<void> save(Category c) => _db.writeLocal('categories', c.toRow());
  Future<void> delete(String id) => _db.softDelete('categories', id);
}

class GroupRepository {
  GroupRepository(this._db, this.userId);
  final LocalDb _db;
  final String userId;

  Stream<List<ExpenseGroup>> watchAll() =>
      _db.watch({'expense_groups'}, () async {
        final rows = await _db.raw.query(
          'expense_groups',
          orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
        );
        return rows.map(ExpenseGroup.fromRow).toList();
      });

  Future<void> save(ExpenseGroup g) =>
      _db.writeLocal('expense_groups', g.toRow());
  Future<void> delete(String id) => _db.softDelete('expense_groups', id);
}

class SettingsRepository {
  SettingsRepository(this._db, this.userId);
  final LocalDb _db;
  final String userId;

  /// Ajustes del usuario. Si todavía no bajaron de la nube (primer arranque
  /// sin conexión) se usan los valores por defecto: IVA 22 %, UYU.
  Stream<UserSettings> watch() => _db.watch({'user_settings'}, () async {
    final rows = await _db.raw.query(
      'user_settings',
      where: 'id = ?',
      whereArgs: [userId],
    );
    return rows.isEmpty
        ? UserSettings.defaults(userId)
        : UserSettings.fromRow(rows.first);
  });

  Future<void> save(UserSettings s) =>
      _db.writeLocal('user_settings', s.toRow());
}
