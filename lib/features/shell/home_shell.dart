import 'package:material_ui/material_ui.dart';

import '../../widgets/brand_logo.dart';
import '../categories/categories_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../expenses/expense_form_screen.dart';
import '../expenses/expense_list_screen.dart';
import '../export/export_screen.dart';
import '../settings/settings_screen.dart';

/// Contenedor principal con navegación adaptable:
/// * Celular (< 840 px): barra inferior.
/// * PC / tablet: riel lateral, más cómodo con mouse y pantallas anchas.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Inicio'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Movimientos'),
    (Icons.folder_outlined, Icons.folder_rounded, 'Categorías'),
    (Icons.file_download_outlined, Icons.file_download_rounded, 'Exportar'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Ajustes'),
  ];

  static const _pages = <Widget>[
    DashboardScreen(),
    ExpenseListScreen(),
    CategoriesScreen(),
    ExportScreen(),
    SettingsScreen(),
  ];

  void _newExpense() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const ExpenseFormScreen(),
      fullscreenDialog: true,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final showFab = _index <= 1;
    final fab = showFab
        ? FloatingActionButton.extended(
            onPressed: _newExpense,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo gasto'),
          )
        : null;

    final body = IndexedStack(index: _index, children: _pages);

    if (wide) {
      return Scaffold(
        floatingActionButton: fab,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: BrandLogo(size: 44),
              ),
              destinations: [
                for (final (icon, selected, label) in _destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: fab,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (icon, selected, label) in _destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
      ),
    );
  }
}
