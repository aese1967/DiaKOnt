import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth/oauth_pkce.dart';
import '../../state/providers.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/common.dart';

/// Pantalla de ingreso con Google o Microsoft.
///
/// No hay usuario ni contraseña propios de DiaKont: la cuenta elegida es
/// también la nube donde se guardan los datos (Google Drive u OneDrive), en
/// una carpeta privada de la app. En pantallas anchas (Windows) muestra un
/// panel de marca a la izquierda.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on AuthFailure catch (e) {
      AuthLog.error(e);
      if (mounted && e.message != 'Inicio de sesión cancelado.') {
        await _showError(e.message);
      }
    } catch (e) {
      AuthLog.error(e);
      if (mounted) {
        await _showError('$e\n\nPaso: ${AuthLog.step}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showError(String message) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('No se pudo iniciar sesión'),
      content: SelectableText(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = _buildForm(context);
    return Scaffold(
      body: wide
          ? Row(
              children: [
                const Expanded(child: _BrandPanel()),
                Expanded(child: Center(child: form)),
              ],
            )
          : SafeArea(child: Center(child: form)),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.read(authServiceProvider);
    final muted = theme.colorScheme.onSurfaceVariant;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: BrandLockup(size: 52)),
            const SizedBox(height: 32),
            Text(
              'Bienvenido',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ingresá con tu cuenta. Tus datos se guardan en TU nube y se '
              'sincronizan entre tu celular y tu PC.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 28),
            if (Env.hasGoogle)
              _ProviderButton(
                busy: _busy,
                letter: 'G',
                color: BrandColors.blue,
                label: 'Continuar con Google',
                detail: 'Se guarda en Google Drive',
                onPressed: () => _run(auth.signInWithGoogle),
              ),
            if (Env.hasGoogle && Env.hasMicrosoft) const SizedBox(height: 12),
            if (Env.hasMicrosoft)
              _ProviderButton(
                busy: _busy,
                letter: 'M',
                color: const Color(0xFF0078D4),
                label: 'Continuar con Microsoft',
                detail: 'Se guarda en OneDrive',
                onPressed: () => _run(auth.signInWithMicrosoft),
              ),
            const SizedBox(height: 24),
            if (_busy) ...[
              const Center(child: CircularProgressIndicator()),
              if (!Platform.isAndroid) ...[
                const SizedBox(height: 12),
                Text(
                  'Terminá el ingreso en el navegador y volvé a esta ventana.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
                Center(
                  child: TextButton(
                    onPressed: () {
                      PkceOAuth.cancel();
                      setState(() => _busy = false);
                    },
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, size: 18, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DiaKont solo accede a su propia carpeta privada: no puede ver '
                    'ni modificar tus otros archivos. SouthDevs no tiene servidores '
                    'ni copia de tus datos.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.busy,
    required this.letter,
    required this.color,
    required this.label,
    required this.detail,
    required this.onPressed,
  });

  final bool busy;
  final String letter;
  final Color color;
  final String label;
  final String detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              letter,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    const bullets = [
      (Icons.receipt_long_rounded, 'Cargá boletas en segundos'),
      (Icons.percent_rounded, 'IVA calculado automáticamente'),
      (Icons.sync_rounded, 'Celular y PC siempre al día'),
      (Icons.cloud_done_rounded, 'Tus datos en tu Drive u OneDrive'),
    ];
    return Container(
      decoration: const BoxDecoration(gradient: BrandColors.heroGradient),
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BrandLockup(size: 56, light: true),
          const SizedBox(height: 48),
          const Text(
            'La contabilidad de tu casa,\nsimple y en orden.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          for (final (icon, text) in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(icon, color: BrandColors.emerald),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
