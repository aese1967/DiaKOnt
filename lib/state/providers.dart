/// Inyección de dependencias y estado global con Riverpod.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/analytics.dart';
import '../data/auth/auth_service.dart';
import '../data/cloud/cloud_store.dart';
import '../data/local/local_db.dart';
import '../data/models/models.dart';
import '../data/repositories/repositories.dart';
import '../data/sync/sync_service.dart';

// ------------------------------------------------------------ Infraestructura
/// Se sobrescribe en `main.dart` con la instancia ya cargada.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('sharedPrefsProvider debe sobrescribirse'),
);

/// Se sobrescribe en `main.dart` con la instancia ya restaurada.
final authServiceProvider = Provider<AuthService>(
  (_) => throw UnimplementedError('authServiceProvider debe sobrescribirse'),
);

/// Cuenta actual (null = sin sesión). Funciona offline: la cuenta se guarda
/// en el almacenamiento seguro del dispositivo.
final accountProvider = StreamProvider<CloudAccount?>(
  (ref) => ref.watch(authServiceProvider).watch(),
);

/// Solo la clave: así los cambios menores no reconstruyen toda la sesión.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(accountProvider).value?.key,
);

// ------------------------------------------------------------ Sesión de datos
/// Todo lo que depende del usuario logueado: base local, repositorios y
/// sincronización. Se crea al iniciar sesión y se destruye al cerrarla.
class AppSession {
  AppSession({required this.userId, required this.db, required this.sync})
    : expenses = ExpenseRepository(db, userId),
      categories = CategoryRepository(db, userId),
      groups = GroupRepository(db, userId),
      settings = SettingsRepository(db, userId);

  final String userId;
  final LocalDb db;
  final SyncService sync;
  final ExpenseRepository expenses;
  final CategoryRepository categories;
  final GroupRepository groups;
  final SettingsRepository settings;
}

final sessionFutureProvider = FutureProvider<AppSession>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Sin sesión');
  final auth = ref.watch(authServiceProvider);
  final db = await LocalDb.open(userId);
  // La nube es la de la cuenta con la que se inició sesión.
  final CloudStore store = switch (auth.account!.provider) {
    CloudProvider.google => GoogleDriveStore(auth.accessToken),
    CloudProvider.microsoft => OneDriveStore(auth.accessToken),
  };
  final sync = SyncService(db: db, store: store)..start();
  ref.onDispose(() async {
    await sync.dispose();
    await db.close();
  });
  return AppSession(userId: userId, db: db, sync: sync);
});

/// Atajo síncrono: solo usar debajo de `SessionGate` (ya cargada).
final sessionProvider = Provider<AppSession>(
  (ref) => ref.watch(sessionFutureProvider).requireValue,
);

// ------------------------------------------------------------ Datos reactivos
final expensesProvider = StreamProvider<List<Expense>>(
  (ref) => ref.watch(sessionProvider).expenses.watchAll(),
);

/// Todas las categorías (incluye borradas, para resolver nombres).
final allCategoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(sessionProvider).categories.watchAll(),
);

/// Categorías vigentes, para listas y selectores.
final categoriesProvider = Provider<List<Category>>(
  (ref) => (ref.watch(allCategoriesProvider).value ?? const [])
      .where((c) => !c.deleted)
      .toList(),
);

final categoryMapProvider = Provider<Map<String, Category>>(
  (ref) => {
    for (final c
        in ref.watch(allCategoriesProvider).value ?? const <Category>[])
      c.id: c,
  },
);

final allGroupsProvider = StreamProvider<List<ExpenseGroup>>(
  (ref) => ref.watch(sessionProvider).groups.watchAll(),
);

final groupsProvider = Provider<List<ExpenseGroup>>(
  (ref) => (ref.watch(allGroupsProvider).value ?? const [])
      .where((g) => !g.deleted)
      .toList(),
);

final groupMapProvider = Provider<Map<String, ExpenseGroup>>(
  (ref) => {
    for (final g
        in ref.watch(allGroupsProvider).value ?? const <ExpenseGroup>[])
      g.id: g,
  },
);

final settingsStreamProvider = StreamProvider<UserSettings>(
  (ref) => ref.watch(sessionProvider).settings.watch(),
);

final settingsProvider = Provider<UserSettings>(
  (ref) =>
      ref.watch(settingsStreamProvider).value ??
      UserSettings.defaults(ref.watch(sessionProvider).userId),
);

final syncStatusProvider = StreamProvider<SyncStatus>(
  (ref) => ref.watch(sessionProvider).sync.watchStatus(),
);

// ------------------------------------------------------------ Dashboard
/// Filtro del dashboard: vista de tiempo + categoría o grupo opcional.
class DashboardFilter {
  const DashboardFilter({
    this.granularity = Granularity.month,
    this.categoryId,
    this.groupId,
    this.donutByGroup = false,
  });

  final Granularity granularity;
  final String? categoryId;
  final String? groupId;

  /// La torta agrupa por grupo (true) o por categoría (false).
  final bool donutByGroup;

  bool matches(Expense e) =>
      (categoryId == null || e.categoryId == categoryId) &&
      (groupId == null || e.groupId == groupId);

  DashboardFilter copyWith({
    Granularity? granularity,
    String? Function()? categoryId,
    String? Function()? groupId,
    bool? donutByGroup,
  }) => DashboardFilter(
    granularity: granularity ?? this.granularity,
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    groupId: groupId != null ? groupId() : this.groupId,
    donutByGroup: donutByGroup ?? this.donutByGroup,
  );
}

class DashboardFilterNotifier extends Notifier<DashboardFilter> {
  @override
  DashboardFilter build() => const DashboardFilter();

  void setGranularity(Granularity g) => state = state.copyWith(granularity: g);
  void setDonutByGroup(bool v) => state = state.copyWith(donutByGroup: v);

  /// Filtra por una categoría O un grupo (son excluyentes); null = todo.
  void setScope({String? categoryId, String? groupId}) => state = state
      .copyWith(categoryId: () => categoryId, groupId: () => groupId);
}

final dashboardFilterProvider =
    NotifierProvider<DashboardFilterNotifier, DashboardFilter>(
      DashboardFilterNotifier.new,
    );

// ------------------------------------------------------------ Tema
/// Modo claro/oscuro/sistema. Es una preferencia del dispositivo (no se
/// sincroniza): podés querer oscuro en la PC y claro en el celular.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final saved = ref.watch(sharedPrefsProvider).getString(_key);
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(sharedPrefsProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
