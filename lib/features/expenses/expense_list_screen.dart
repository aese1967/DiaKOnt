import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'expense_form_screen.dart';

/// Lista de movimientos agrupada por mes, con búsqueda y borrado deslizando.
class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(expensesProvider).value ?? const <Expense>[];
    final cats = ref.watch(categoryMapProvider);
    final groups = ref.watch(groupMapProvider);
    final currency = ref.watch(settingsProvider).currency;

    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? all
        : all.where((e) {
            final hay =
                '${e.concept} ${cats[e.categoryId]?.name ?? ''} '
                        '${groups[e.groupId]?.name ?? ''} ${e.notes ?? ''}'
                    .toLowerCase();
            return hay.contains(q);
          }).toList();

    // Agrupar por mes (la lista ya viene ordenada por fecha descendente).
    final sections = <DateTime, List<Expense>>{};
    for (final e in list) {
      sections
          .putIfAbsent(DateTime(e.date.year, e.date.month), () => [])
          .add(e);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        actions: const [SyncBadge()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por concepto, categoría o grupo',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'Sin movimientos',
                      message:
                          'Tocá "Nuevo gasto" para cargar tu primera boleta.',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      for (final entry in sections.entries) ...[
                        _MonthHeader(
                          month: entry.key,
                          totalCents: entry.value.fold(
                            0,
                            (s, e) => s + e.totalCents,
                          ),
                          currency: currency,
                        ),
                        for (final e in entry.value) _dismissible(e),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dismissible(Expense e) {
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline_rounded),
      ),
      onDismissed: (_) {
        final repo = ref.read(sessionProvider).expenses;
        repo.delete(e.id);
        showSnack(
          context,
          'Eliminado "${e.concept}"',
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => repo.restore(e),
          ),
        );
      },
      child: ExpenseTile(
        expense: e,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ExpenseFormScreen(initial: e),
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.totalCents,
    required this.currency,
  });
  final DateTime month;
  final int totalCents;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(Fmt.monthYear(month).toUpperCase(), style: style),
          ),
          Text(Fmt.money(totalCents, currency: currency), style: style),
        ],
      ),
    );
  }
}
