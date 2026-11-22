import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'data/auth/auth_service.dart';
import 'state/providers.dart';

/// Punto de entrada de DiaKont by Southdevs (Android y Windows).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fechas y números en español rioplatense.
  Intl.defaultLocale = 'es';
  await initializeDateFormatting('es');

  if (!Env.isConfigured) {
    runApp(const ConfigMissingApp());
    return;
  }

  // Recupera la cuenta guardada (sin red): la app abre aunque no haya internet.
  final auth = AuthService();
  await auth.restore();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(auth),
      ],
      child: const DiaKontApp(),
    ),
  );
}
