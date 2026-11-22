import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Datos iniciales de cada cuenta: ajustes (IVA 22 %, UYU), grupos de ejemplo
/// y las categorías por defecto pedidas (UTE, Alquiler, OSE, ANTEL, Gas,
/// Supergás, Celulares). Todo es editable y eliminable.
///
/// **Ids deterministas (UUID v5)**: si el usuario instala la app en el celular
/// y en la PC al mismo tiempo, ambos dispositivos generan los MISMOS ids para
/// las categorías por defecto, así que al sincronizar se fusionan en vez de
/// duplicarse. La fecha de edición es antigua (2000-01-01) para que cualquier
/// cambio real del usuario (renombrar, borrar) siempre gane.
Future<void> seedDefaults(Database db, String accountKey) async {
  const uuid = Uuid();
  String id(String what) =>
      uuid.v5(Namespace.url.value, 'diakont:$accountKey:$what');
  const stamp = '2000-01-01T00:00:00.000Z';
  Map<String, Object?> base(String id) => {
    'id': id,
    'user_id': accountKey,
    'created_at': stamp,
    'updated_at': stamp,
    'deleted': 0,
    'dirty': 1,
  };

  final servicios = id('group:servicios');
  final hogar = id('group:hogar');
  final batch = db.batch();

  batch.insert('user_settings', {
    ...base(accountKey),
    'default_vat_rate_bp': 2200,
    'monthly_budget_cents': 0,
    'currency': 'UYU',
    'default_vat_included': 1,
  });

  for (final (gid, name, color, icon, order) in [
    (servicios, 'Servicios Fijos', 0xFF1456C8, 'bolt', 1),
    (hogar, 'Hogar', 0xFF10B981, 'home', 2),
  ]) {
    batch.insert('expense_groups', {
      ...base(gid),
      'name': name,
      'color': color,
      'icon': icon,
      'sort_order': order,
    });
  }

  const categories = [
    ('UTE', 0xFFF59E0B, 'bolt', 'servicios'),
    ('Alquiler', 0xFF6366F1, 'home', 'hogar'),
    ('OSE', 0xFF0EA5E9, 'water', 'servicios'),
    ('ANTEL', 0xFF8B5CF6, 'wifi', 'servicios'),
    ('Gas', 0xFFEF4444, 'fire', 'servicios'),
    ('Supergás', 0xFFF97316, 'propane', 'hogar'),
    ('Celulares', 0xFF10B981, 'phone', 'servicios'),
  ];
  for (var i = 0; i < categories.length; i++) {
    final (name, color, icon, group) = categories[i];
    batch.insert('categories', {
      ...base(id('category:$name')),
      'name': name,
      'color': color,
      'icon': icon,
      'default_group_id': group == 'servicios' ? servicios : hogar,
      'sort_order': i + 1,
    });
  }
  await batch.commit(noResult: true);
}
