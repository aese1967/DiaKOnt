import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/utils/icon_catalog.dart';
import '../data/models/models.dart';
import '../data/sync/sync_service.dart';
import '../state/providers.dart';

/// Avatar circular con el ícono y color de una categoría o grupo.
class EntityAvatar extends StatelessWidget {
  const EntityAvatar({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });
  final String? icon;
  final int? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Color(color ?? 0xFF64748B);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(IconCatalog.of(icon), color: c, size: size * 0.55),
    );
  }
}

/// Indicador del estado de sincronización (nube) para la barra superior.
class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).value ?? const SyncStatus();
    final (IconData icon, Color color, String tip) = switch (status.phase) {
      SyncPhase.syncing => (
        Icons.sync_rounded,
        BrandColors.blue,
        'Sincronizando…',
      ),
      SyncPhase.offline => (
        Icons.cloud_off_rounded,
        BrandColors.amber,
        'Sin conexión: tus cambios se guardan y se subirán solos',
      ),
      SyncPhase.error => (
        Icons.error_outline_rounded,
        BrandColors.danger,
        'Error al sincronizar: ${status.error ?? ''}',
      ),
      SyncPhase.idle => (
        Icons.cloud_done_rounded,
        BrandColors.emerald,
        status.pending > 0
            ? '${status.pending} cambios pendientes'
            : 'Todo sincronizado',
      ),
    };
    return Tooltip(
      message: tip,
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: () => ref.read(sessionProvider).sync.syncNow(),
      ),
    );
  }
}

/// Fila de un gasto, usada en el dashboard y en la lista de movimientos.
class ExpenseTile extends ConsumerWidget {
  const ExpenseTile({super.key, required this.expense, this.onTap});
  final Expense expense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = ref.watch(categoryMapProvider)[expense.categoryId];
    final group = ref.watch(groupMapProvider)[expense.groupId];
    final currency = ref.watch(settingsProvider).currency;
    final theme = Theme.of(context);
    final subtitle = [
      cat?.name ?? 'Sin categoría',
      if (group != null) group.name,
      Fmt.dayMonth(expense.date),
    ].join(' · ');

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: EntityAvatar(icon: cat?.icon, color: cat?.color),
      title: Text(
        expense.concept,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Fmt.money(expense.totalCents, currency: currency),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (expense.vatCents > 0)
            Text(
              'IVA ${Fmt.money(expense.vatCents, currency: currency)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Encabezado de sección dentro de tarjetas.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Estado vacío amigable.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });
  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        action: action,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
