import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/home_shell.dart';
import 'state/providers.dart';
import 'widgets/brand_logo.dart';

class DiaKontApp extends ConsumerWidget {
  const DiaKontApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'DiaKont',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('es', 'UY'),
      supportedLocales: const [Locale('es', 'UY'), Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

/// Muestra el login o la app según haya sesión.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(accountProvider);
    return auth.when(
      loading: () => const SplashScreen(),
      error: (e, _) => const LoginScreen(),
      data: (user) => user == null
          ? const LoginScreen()
          // La key fuerza una sesión nueva si cambia la cuenta.
          : SessionGate(key: ValueKey(user.key)),
    );
  }
}

/// Abre la base local del usuario y arranca la sincronización.
class SessionGate extends ConsumerWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(sessionFutureProvider)
        .when(
          loading: () => const SplashScreen(message: 'Preparando tus datos…'),
          error: (e, _) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo abrir la base local:\n$e',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          data: (_) => const HomeShell(),
        );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 72),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Se muestra si se compiló sin `--dart-define-from-file=env.json`.
class ConfigMissingApp extends StatelessWidget {
  const ConfigMissingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandLogo(size: 72),
                SizedBox(height: 24),
                Text(
                  'Falta la configuración de inicio de sesión',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                Text(
                  'Copiá env.example.json a env.json, completá los client id de '
                  'Google y/o Microsoft (ver docs/CONFIGURAR_OAUTH.md) y ejecutá:\n\n'
                  'flutter run --dart-define-from-file=env.json',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
