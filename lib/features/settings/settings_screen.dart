import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/sync/sync_service.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Ajustes: IVA por defecto, presupuesto, moneda, tema, sincronización y cuenta.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final session = ref.watch(sessionProvider);
    final user = ref.watch(accountProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final sync = ref.watch(syncStatusProvider).value ?? const SyncStatus();

    Future<void> editNumber({
      required String title,
      required String initial,
      required String suffix,
      required int? Function(String) parse,
      required void Function(int) onSave,
    }) async {
      final ctrl = TextEditingController(text: initial);
      final value = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(suffixText: suffix),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final v = parse(ctrl.text);
                if (v != null) Navigator.pop(ctx, v);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      ctrl.dispose();
      if (value != null) onSave(value);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Section('Impuestos y presupuesto', [
                ListTile(
                  leading: const Icon(Icons.percent_rounded),
                  title: const Text('Tasa de IVA por defecto'),
                  subtitle: const Text('Uruguay: 22 % básica, 10 % mínima'),
                  trailing: Text(
                    Fmt.rate(settings.defaultVatRateBp),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => editNumber(
                    title: 'Tasa de IVA por defecto',
                    initial: Fmt.bpToInput(settings.defaultVatRateBp),
                    suffix: '%',
                    parse: Fmt.parseRateToBp,
                    onSave: (bp) => session.settings.save(
                      settings.copyWith(defaultVatRateBp: bp),
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.receipt_rounded),
                  title: const Text('Los montos ya incluyen IVA'),
                  subtitle: const Text(
                    'Respuesta por defecto al cargar un gasto',
                  ),
                  value: settings.defaultVatIncluded,
                  onChanged: (v) => session.settings.save(
                    settings.copyWith(defaultVatIncluded: v),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.savings_rounded),
                  title: const Text('Presupuesto mensual'),
                  trailing: Text(
                    settings.monthlyBudgetCents == 0
                        ? 'Sin definir'
                        : Fmt.money(
                            settings.monthlyBudgetCents,
                            currency: settings.currency,
                          ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => editNumber(
                    title: 'Presupuesto mensual',
                    initial: settings.monthlyBudgetCents == 0
                        ? ''
                        : Fmt.centsToInput(settings.monthlyBudgetCents),
                    suffix: Fmt.symbol(settings.currency),
                    parse: (s) =>
                        s.trim().isEmpty ? 0 : Fmt.parseAmountToCents(s),
                    onSave: (c) => session.settings.save(
                      settings.copyWith(monthlyBudgetCents: c),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.payments_rounded),
                  title: const Text('Moneda'),
                  trailing: DropdownButton<String>(
                    value: settings.currency,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: 'UYU',
                        child: Text('Peso uruguayo (\$)'),
                      ),
                      DropdownMenuItem(
                        value: 'USD',
                        child: Text('Dólar (US\$)'),
                      ),
                      DropdownMenuItem(value: 'EUR', child: Text('Euro (€)')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        session.settings.save(settings.copyWith(currency: v));
                      }
                    },
                  ),
                ),
              ]),
              _Section('Apariencia', [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('Claro'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('Oscuro'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded),
                        label: Text('Sistema'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (s) =>
                        ref.read(themeModeProvider.notifier).set(s.first),
                  ),
                ),
              ]),
              _Section('Sincronización', [
                ListTile(
                  leading: const SyncBadge(),
                  title: Text(switch (sync.phase) {
                    SyncPhase.syncing => 'Sincronizando…',
                    SyncPhase.offline => 'Sin conexión (modo offline)',
                    SyncPhase.error => 'Error de sincronización',
                    SyncPhase.idle => 'Sincronizado',
                  }),
                  subtitle: Text(
                    [
                      if (sync.pending > 0)
                        '${sync.pending} cambios pendientes',
                      if (sync.lastSyncAt != null)
                        'Última: ${Fmt.dateTime(sync.lastSyncAt!)}',
                      if (sync.error != null) sync.error!,
                    ].join(' · '),
                  ),
                  trailing: TextButton(
                    onPressed: session.sync.syncNow,
                    child: const Text('Sincronizar'),
                  ),
                ),
              ]),
              _Section('Cuenta', [
                ListTile(
                  leading: const Icon(Icons.person_rounded),
                  title: Text(user?.email ?? '—'),
                  subtitle: Text(
                    user == null
                        ? ''
                        : 'Datos en ${user.provider.storageName}. Usá la misma cuenta en tu celular y tu PC.',
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: BrandColors.danger,
                  ),
                  title: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: BrandColors.danger),
                  ),
                  onTap: () async {
                    if (sync.pending > 0) {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Hay cambios sin sincronizar'),
                          content: const Text(
                            'Quedan guardados en este dispositivo y se subirán la próxima '
                            'vez que ingreses con esta cuenta. ¿Cerrar sesión igual?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Cerrar sesión'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;
                    }
                    await ref.read(authServiceProvider).signOut();
                  },
                ),
              ]),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'DiaKont by SouthDevs · v1.0.0',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
          ),
          Card(child: Column(children: children)),
        ],
      ),
    );
  }
}
