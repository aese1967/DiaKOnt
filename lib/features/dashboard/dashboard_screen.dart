import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../data/analytics.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../expenses/expense_form_screen.dart';
import 'widgets/charts.dart';
import 'widgets/summary_cards.dart';

/// Dashboard: tarjetas del mes + gráficos filtrables + últimos movimientos.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider).value ?? const <Expense>[];
    final settings = ref.watch(settingsProvider);
    final filter = ref.watch(dashboardFilterProvider);
    final cats = ref.watch(categoryMapProvider);
    final groups = ref.watch(groupMapProvider);
    final now = DateTime.now();

    // Las tarjetas resumen siempre muestran el mes actual completo.
    final summary = Analytics.monthSummary(
      expenses,
      now,
      settings.monthlyBudgetCents,
    );

    // Los gráficos respetan la vista (día/semana/mes/año) y el filtro.
    final filtered = expenses.where(filter.matches).toList();
    final buckets = Analytics.buckets(filtered, filter.granularity, now);
    final (from, to) = Analytics.range(filter.granularity, now);
    final inRange = Analytics.inRange(filtered, from, to);
    final slices = _slices(inRange, filter.donutByGroup, cats, groups);

    final barCard = Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle('Evolución ${filter.granularity.label.toLowerCase()}'),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: SpendingBarChart(
                buckets: buckets,
                granularity: filter.granularity,
                currency: settings.currency,
              ),
            ),
          ],
        ),
      ),
    );

    final donutCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Distribución',
              trailing: SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: false, label: Text('Categoría')),
                  ButtonSegment(value: true, label: Text('Grupo')),
                ],
                selected: {filter.donutByGroup},
                onSelectionChanged: (s) => ref
                    .read(dashboardFilterProvider.notifier)
                    .setDonutByGroup(s.first),
              ),
            ),
            const SizedBox(height: 12),
            DistributionDonut(slices: slices, currency: settings.currency),
          ],
        ),
      ),
    );

    final recent = expenses.take(5).toList();
    final recentCard = Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionTitle('Últimos movimientos'),
            ),
            if (recent.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Todavía no cargaste gastos',
                message: 'Tocá "Nuevo gasto" para empezar.',
              )
            else
              for (final e in recent)
                ExpenseTile(
                  expense: e,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExpenseFormScreen(initial: e),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hola 👋'),
        actions: const [SyncBadge(), SizedBox(width: 8)],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1000;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              SummaryCards(summary: summary, currency: settings.currency),
              const SizedBox(height: 16),
              const _FilterBar(),
              const SizedBox(height: 12),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: barCard),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: donutCard),
                  ],
                )
              else ...[
                barCard,
                const SizedBox(height: 12),
                donutCard,
              ],
              const SizedBox(height: 12),
              recentCard,
            ],
          );
        },
      ),
    );
  }

  /// Arma los segmentos de la dona (máx. 6 + "Otros").
  List<DonutSlice> _slices(
    List<Expense> list,
    bool byGroup,
    Map<String, Category> cats,
    Map<String, ExpenseGroup> groups,
  ) {
    final totals = Analytics.totalsBy(
      list,
      (e) => byGroup ? e.groupId : e.categoryId,
    );
    final slices = <DonutSlice>[];
    var others = 0;
    for (var i = 0; i < totals.length; i++) {
      final key = totals[i].key;
      if (i >= 6) {
        others += totals[i].value;
        continue;
      }
      final name = byGroup ? groups[key]?.name : cats[key]?.name;
      final color = byGroup ? groups[key]?.color : cats[key]?.color;
      slices.add(
        DonutSlice(
          label: name ?? (byGroup ? 'Sin grupo' : 'Sin categoría'),
          cents: totals[i].value,
          color: Color(
            color ??
                BrandColors.palette[i % BrandColors.palette.length].toARGB32(),
          ),
        ),
      );
    }
    if (others > 0) {
      slices.add(
        DonutSlice(
          label: 'Otros',
          cents: others,
          color: const Color(0xFF94A3B8),
        ),
      );
    }
    return slices;
  }
}

/// Selector de vista (Diaria/Semanal/Mensual/Anual) + filtro por categoría
/// o grupo.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);
    final notifier = ref.read(dashboardFilterProvider.notifier);
    final cats = ref.watch(categoriesProvider);
    final groups = ref.watch(groupsProvider);

    // Valor único del menú: "c:<id>", "g:<id>" o "" (todo).
    final current = filter.categoryId != null
        ? 'c:${filter.categoryId}'
        : filter.groupId != null
        ? 'g:${filter.groupId}'
        : '';
    final validValues = {
      '',
      for (final c in cats) 'c:${c.id}',
      for (final g in groups) 'g:${g.id}',
    };

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<Granularity>(
          showSelectedIcon: false,
          segments: [
            for (final g in Granularity.values)
              ButtonSegment(value: g, label: Text(g.label)),
          ],
          selected: {filter.granularity},
          onSelectionChanged: (s) => notifier.setGranularity(s.first),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
          child: DropdownButtonFormField<String>(
            key: ValueKey(current),
            initialValue: validValues.contains(current) ? current : '',
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.filter_alt_outlined),
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Todos los gastos'),
              ),
              if (groups.isNotEmpty)
                const DropdownMenuItem(
                  enabled: false,
                  value: '__groups',
                  child: Text(
                    'GRUPOS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              for (final g in groups)
                DropdownMenuItem(value: 'g:${g.id}', child: Text(g.name)),
              if (cats.isNotEmpty)
                const DropdownMenuItem(
                  enabled: false,
                  value: '__cats',
                  child: Text(
                    'CATEGORÍAS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              for (final c in cats)
                DropdownMenuItem(value: 'c:${c.id}', child: Text(c.name)),
            ],
            onChanged: (v) {
              if (v == null || v.isEmpty) {
                notifier.setScope();
              } else if (v.startsWith('c:')) {
                notifier.setScope(categoryId: v.substring(2));
              } else if (v.startsWith('g:')) {
                notifier.setScope(groupId: v.substring(2));
              }
            },
          ),
        ),
      ],
    );
  }
}
