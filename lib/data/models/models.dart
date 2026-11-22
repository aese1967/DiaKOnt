/// Modelos de dominio de DiaKont.
///
/// Cada modelo sabe convertirse a/desde una fila de la base local (SQLite).
/// La conversión hacia/desde el archivo en la nube la hace el motor de sincronización de
/// forma genérica (ver `sync_service.dart`), porque las columnas son las
/// mismas en ambos lados.
///
/// Columnas comunes de sincronización:
/// * `id`         UUID generado en el dispositivo (permite crear offline).
/// * `user_id`    cuenta dueña del registro.
/// * `updated_at` marca de la última edición, usada para "gana el último".
/// * `deleted`    borrado lógico, para que el borrado también se sincronice.
library;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

String _iso(DateTime d) => d.toUtc().toIso8601String();
DateTime _parse(Object? v) => DateTime.parse(v as String);

/// Fecha "calendario" (sin hora) en formato yyyy-MM-dd.
String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Grupo de gastos (carpeta): "Servicios Fijos", "Vehículo", "Casa de Verano"…
// ---------------------------------------------------------------------------
class ExpenseGroup {
  const ExpenseGroup({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.icon,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  factory ExpenseGroup.create({
    required String userId,
    required String name,
    required int color,
    String icon = 'folder',
  }) {
    final now = DateTime.now().toUtc();
    return ExpenseGroup(
      id: newId(),
      userId: userId,
      name: name,
      color: color,
      icon: icon,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String userId;
  final String name;
  final int color; // ARGB
  final String icon; // clave de IconCatalog
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  ExpenseGroup copyWith({String? name, int? color, String? icon}) =>
      ExpenseGroup(
        id: id,
        userId: userId,
        name: name ?? this.name,
        color: color ?? this.color,
        icon: icon ?? this.icon,
        sortOrder: sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deleted: deleted,
      );

  Map<String, Object?> toRow() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'color': color,
    'icon': icon,
    'sort_order': sortOrder,
    'created_at': _iso(createdAt),
    'updated_at': _iso(updatedAt),
    'deleted': deleted ? 1 : 0,
  };

  factory ExpenseGroup.fromRow(Map<String, Object?> r) => ExpenseGroup(
    id: r['id'] as String,
    userId: r['user_id'] as String,
    name: r['name'] as String,
    color: r['color'] as int,
    icon: r['icon'] as String,
    sortOrder: (r['sort_order'] as int?) ?? 0,
    createdAt: _parse(r['created_at']),
    updatedAt: _parse(r['updated_at']),
    deleted: r['deleted'] == 1,
  );
}

// ---------------------------------------------------------------------------
// Categoría: UTE, Alquiler, OSE, ANTEL, Gas, Supergás, Celulares… (editables)
// ---------------------------------------------------------------------------
class Category {
  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.icon,
    this.defaultGroupId,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  factory Category.create({
    required String userId,
    required String name,
    required int color,
    String icon = 'tag',
    String? defaultGroupId,
  }) {
    final now = DateTime.now().toUtc();
    return Category(
      id: newId(),
      userId: userId,
      name: name,
      color: color,
      icon: icon,
      defaultGroupId: defaultGroupId,
      sortOrder: 100,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String userId;
  final String name;
  final int color;
  final String icon;

  /// Grupo que se preselecciona al elegir esta categoría en un gasto nuevo.
  final String? defaultGroupId;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  Category copyWith({
    String? name,
    int? color,
    String? icon,
    String? Function()? defaultGroupId,
  }) => Category(
    id: id,
    userId: userId,
    name: name ?? this.name,
    color: color ?? this.color,
    icon: icon ?? this.icon,
    defaultGroupId: defaultGroupId != null
        ? defaultGroupId()
        : this.defaultGroupId,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'color': color,
    'icon': icon,
    'default_group_id': defaultGroupId,
    'sort_order': sortOrder,
    'created_at': _iso(createdAt),
    'updated_at': _iso(updatedAt),
    'deleted': deleted ? 1 : 0,
  };

  factory Category.fromRow(Map<String, Object?> r) => Category(
    id: r['id'] as String,
    userId: r['user_id'] as String,
    name: r['name'] as String,
    color: r['color'] as int,
    icon: r['icon'] as String,
    defaultGroupId: r['default_group_id'] as String?,
    sortOrder: (r['sort_order'] as int?) ?? 0,
    createdAt: _parse(r['created_at']),
    updatedAt: _parse(r['updated_at']),
    deleted: r['deleted'] == 1,
  );
}

// ---------------------------------------------------------------------------
// Gasto / boleta, con el desglose de IVA ya calculado y guardado.
// ---------------------------------------------------------------------------
class Expense {
  const Expense({
    required this.id,
    required this.userId,
    required this.date,
    required this.concept,
    this.categoryId,
    this.groupId,
    required this.subtotalCents,
    required this.vatCents,
    required this.totalCents,
    required this.vatRateBp,
    required this.vatIncluded,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;
  final String userId;

  /// Fecha de la boleta (sin hora, en hora local del usuario).
  final DateTime date;
  final String concept;
  final String? categoryId;
  final String? groupId;
  final int subtotalCents;
  final int vatCents;
  final int totalCents;
  final int vatRateBp;

  /// Lo que respondió el usuario a "¿El monto incluye IVA?" (para poder
  /// reabrir el gasto y mostrar el formulario igual que cuando se cargó).
  final bool vatIncluded;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  Map<String, Object?> toRow() => {
    'id': id,
    'user_id': userId,
    'date': dateOnly(date),
    'concept': concept,
    'category_id': categoryId,
    'group_id': groupId,
    'subtotal_cents': subtotalCents,
    'vat_cents': vatCents,
    'total_cents': totalCents,
    'vat_rate_bp': vatRateBp,
    'vat_included': vatIncluded ? 1 : 0,
    'notes': notes,
    'created_at': _iso(createdAt),
    'updated_at': _iso(updatedAt),
    'deleted': deleted ? 1 : 0,
  };

  factory Expense.fromRow(Map<String, Object?> r) {
    final d = DateTime.parse(r['date'] as String);
    return Expense(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      date: DateTime(d.year, d.month, d.day),
      concept: r['concept'] as String,
      categoryId: r['category_id'] as String?,
      groupId: r['group_id'] as String?,
      subtotalCents: r['subtotal_cents'] as int,
      vatCents: r['vat_cents'] as int,
      totalCents: r['total_cents'] as int,
      vatRateBp: r['vat_rate_bp'] as int,
      vatIncluded: r['vat_included'] == 1,
      notes: r['notes'] as String?,
      createdAt: _parse(r['created_at']),
      updatedAt: _parse(r['updated_at']),
      deleted: r['deleted'] == 1,
    );
  }
}

// ---------------------------------------------------------------------------
// Ajustes del usuario (sincronizados entre dispositivos). id == user_id.
// ---------------------------------------------------------------------------
class UserSettings {
  const UserSettings({
    required this.userId,
    this.defaultVatRateBp = 2200,
    this.monthlyBudgetCents = 0,
    this.currency = 'UYU',
    this.defaultVatIncluded = true,
    required this.updatedAt,
  });

  factory UserSettings.defaults(String userId) =>
      UserSettings(userId: userId, updatedAt: DateTime.utc(1970));

  final String userId;

  /// Tasa de IVA por defecto (22 % en Uruguay), editable en Ajustes.
  final int defaultVatRateBp;

  /// Presupuesto mensual. 0 = sin presupuesto definido.
  final int monthlyBudgetCents;
  final String currency;

  /// Respuesta por defecto a "¿El monto incluye IVA?" en gastos nuevos.
  final bool defaultVatIncluded;
  final DateTime updatedAt;

  UserSettings copyWith({
    int? defaultVatRateBp,
    int? monthlyBudgetCents,
    String? currency,
    bool? defaultVatIncluded,
  }) => UserSettings(
    userId: userId,
    defaultVatRateBp: defaultVatRateBp ?? this.defaultVatRateBp,
    monthlyBudgetCents: monthlyBudgetCents ?? this.monthlyBudgetCents,
    currency: currency ?? this.currency,
    defaultVatIncluded: defaultVatIncluded ?? this.defaultVatIncluded,
    updatedAt: updatedAt,
  );

  Map<String, Object?> toRow() => {
    'id': userId,
    'user_id': userId,
    'default_vat_rate_bp': defaultVatRateBp,
    'monthly_budget_cents': monthlyBudgetCents,
    'currency': currency,
    'default_vat_included': defaultVatIncluded ? 1 : 0,
    'created_at': _iso(updatedAt),
    'updated_at': _iso(updatedAt),
    'deleted': 0,
  };

  factory UserSettings.fromRow(Map<String, Object?> r) => UserSettings(
    userId: r['user_id'] as String,
    defaultVatRateBp: r['default_vat_rate_bp'] as int,
    monthlyBudgetCents: r['monthly_budget_cents'] as int,
    currency: r['currency'] as String,
    defaultVatIncluded: r['default_vat_included'] == 1,
    updatedAt: _parse(r['updated_at']),
  );
}
