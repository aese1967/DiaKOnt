import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/analytics.dart';

/// Tres tarjetas de resumen: gasto del mes, IVA del mes y presupuesto restante.
/// En celular se apilan (la principal arriba, ancho completo); en PC van en fila.
class SummaryCards extends StatelessWidget {
  const SummaryCards({
    super.key,
    required this.summary,
    required this.currency,
  });
  final MonthSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final total = _HeroCard(summary: summary, currency: currency);
    final vat = _StatCard(
      icon: Icons.percent_rounded,
      color: BrandColors.amber,
      label: 'IVA acumulado del mes',
      value: Fmt.money(summary.vatCents, currency: currency),
      footnote: summary.totalCents > 0
          ? '${(summary.vatCents * 100 / summary.totalCents).toStringAsFixed(1).replaceAll('.', ',')} % de lo gastado'
          : 'Sin gastos este mes',
    );
    final budget = _BudgetCard(summary: summary, currency: currency);

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 760) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 4, child: total),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: vat),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: budget),
              ],
            ),
          );
        }
        return Column(
          children: [
            total,
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: vat),
                  const SizedBox(width: 12),
                  Expanded(child: budget),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.summary, required this.currency});
  final MonthSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: BrandColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Gasto total · ${Fmt.monthYear(DateTime.now())}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.money(summary.totalCents, currency: currency),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${summary.count} ${summary.count == 1 ? 'movimiento' : 'movimientos'}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.footnote,
    this.child,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String footnote;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: muted, fontSize: 13)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ?child,
            const Spacer(),
            const SizedBox(height: 6),
            Text(footnote, style: TextStyle(color: muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.summary, required this.currency});
  final MonthSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasBudget) {
      return const _StatCard(
        icon: Icons.savings_rounded,
        color: BrandColors.emerald,
        label: 'Presupuesto restante',
        value: '—',
        footnote: 'Definí tu presupuesto mensual en Ajustes',
      );
    }
    final over = summary.remainingCents < 0;
    final color = over
        ? BrandColors.danger
        : summary.usedFraction > 0.8
        ? BrandColors.amber
        : BrandColors.emerald;
    return _StatCard(
      icon: over ? Icons.warning_amber_rounded : Icons.savings_rounded,
      color: color,
      label: over ? 'Presupuesto excedido' : 'Presupuesto restante',
      value: Fmt.money(summary.remainingCents.abs(), currency: currency),
      footnote:
          '${(summary.usedFraction * 100).round()} % usado de '
          '${Fmt.money(summary.budgetCents, currency: currency)}',
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: summary.usedFraction.clamp(0, 1).toDouble(),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }
}
