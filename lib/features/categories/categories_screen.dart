import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/icon_catalog.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Gestión de categorías (UTE, OSE, ANTEL…) y grupos/carpetas
/// ("Servicios Fijos", "Vehículo", "Casa de Verano"…). Todo editable y
/// eliminable; los cambios se sincronizan con los otros dispositivos.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Categorías y grupos'),
              actions: const [SyncBadge()],
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.sell_outlined), text: 'Categorías'),
                  Tab(icon: Icon(Icons.folder_outlined), text: 'Grupos'),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar'),
              onPressed: () {
                final tab = DefaultTabController.of(context).index;
                if (tab == 0) {
                  _editCategory(context, ref, null);
                } else {
                  _editGroup(context, ref, null);
                }
              },
            ),
            body: const TabBarView(children: [_CategoryList(), _GroupList()]),
          );
        },
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    final groups = ref.watch(groupMapProvider);
    if (cats.isEmpty) {
      return const EmptyState(
        icon: Icons.sell_outlined,
        title: 'Sin categorías',
        message: 'Agregá una con el botón "Agregar".',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: cats.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = cats[i];
        final g = groups[c.defaultGroupId];
        return Card(
          child: ListTile(
            leading: EntityAvatar(icon: c.icon, color: c.color),
            title: Text(
              c.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              g != null && !g.deleted
                  ? 'Grupo sugerido: ${g.name}'
                  : 'Sin grupo sugerido',
            ),
            onTap: () => _editCategory(context, ref, c),
            trailing: IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmDelete(
                context,
                ref,
                name: c.name,
                count: () => ref
                    .read(sessionProvider)
                    .expenses
                    .countUsing(categoryId: c.id),
                onConfirm: () =>
                    ref.read(sessionProvider).categories.delete(c.id),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GroupList extends ConsumerWidget {
  const _GroupList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final cats = ref.watch(categoriesProvider);
    if (groups.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_outlined,
        title: 'Sin grupos',
        message: 'Creá carpetas como "Vehículo" o "Casa de Verano" para agrupar gastos.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final g = groups[i];
        final linked = cats
            .where((c) => c.defaultGroupId == g.id)
            .map((c) => c.name)
            .toList();
        return Card(
          child: ListTile(
            leading: EntityAvatar(icon: g.icon, color: g.color),
            title: Text(
              g.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              linked.isEmpty ? 'Sin categorías asociadas' : linked.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _editGroup(context, ref, g),
            trailing: IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmDelete(
                context,
                ref,
                name: g.name,
                count: () => ref
                    .read(sessionProvider)
                    .expenses
                    .countUsing(groupId: g.id),
                onConfirm: () => ref.read(sessionProvider).groups.delete(g.id),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref, {
  required String name,
  required Future<int> Function() count,
  required Future<void> Function() onConfirm,
}) async {
  final n = await count();
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('¿Eliminar "$name"?'),
      content: Text(
        n == 0
            ? 'No hay gastos que la usen.'
            : '$n ${n == 1 ? 'gasto la usa' : 'gastos la usan'}. Los gastos NO se borran: '
                  'conservan sus montos y quedarán en los reportes.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: BrandColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await onConfirm();
    if (context.mounted) showSnack(context, '"$name" eliminado');
  }
}

Future<void> _editCategory(
  BuildContext context,
  WidgetRef ref,
  Category? c,
) async {
  final session = ref.read(sessionProvider);
  final groups = ref.read(groupsProvider);
  final result = await showDialog<_EditorResult>(
    context: context,
    builder: (_) => _EntityEditor(
      title: c == null ? 'Nueva categoría' : 'Editar categoría',
      name: c?.name ?? '',
      color:
          c?.color ??
          BrandColors.palette[DateTime.now().millisecond % 12].toARGB32(),
      icon: c?.icon ?? 'tag',
      groups: groups,
      groupId: c?.defaultGroupId,
      showGroup: true,
    ),
  );
  if (result == null) return;
  final updated = c == null
      ? Category.create(
          userId: session.userId,
          name: result.name,
          color: result.color,
          icon: result.icon,
          defaultGroupId: result.groupId,
        )
      : c.copyWith(
          name: result.name,
          color: result.color,
          icon: result.icon,
          defaultGroupId: () => result.groupId,
        );
  await session.categories.save(updated);
}

Future<void> _editGroup(
  BuildContext context,
  WidgetRef ref,
  ExpenseGroup? g,
) async {
  final session = ref.read(sessionProvider);
  final result = await showDialog<_EditorResult>(
    context: context,
    builder: (_) => _EntityEditor(
      title: g == null ? 'Nuevo grupo' : 'Editar grupo',
      name: g?.name ?? '',
      color:
          g?.color ??
          BrandColors.palette[DateTime.now().millisecond % 12].toARGB32(),
      icon: g?.icon ?? 'folder',
      groups: const [],
      showGroup: false,
    ),
  );
  if (result == null) return;
  final updated = g == null
      ? ExpenseGroup.create(
          userId: session.userId,
          name: result.name,
          color: result.color,
          icon: result.icon,
        )
      : g.copyWith(name: result.name, color: result.color, icon: result.icon);
  await session.groups.save(updated);
}

class _EditorResult {
  const _EditorResult(this.name, this.color, this.icon, this.groupId);
  final String name;
  final int color;
  final String icon;
  final String? groupId;
}

/// Diálogo compartido para crear/editar categorías y grupos:
/// nombre, color, ícono y (solo categorías) grupo sugerido.
class _EntityEditor extends StatefulWidget {
  const _EntityEditor({
    required this.title,
    required this.name,
    required this.color,
    required this.icon,
    required this.groups,
    required this.showGroup,
    this.groupId,
  });

  final String title;
  final String name;
  final int color;
  final String icon;
  final List<ExpenseGroup> groups;
  final String? groupId;
  final bool showGroup;

  @override
  State<_EntityEditor> createState() => _EntityEditorState();
}

class _EntityEditorState extends State<_EntityEditor> {
  late final _name = TextEditingController(text: widget.name);
  late int _color = widget.color;
  late String _icon = widget.icon;
  late String? _groupId = widget.groups.any((g) => g.id == widget.groupId)
      ? widget.groupId
      : null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, _EditorResult(name, _color, _icon, _groupId));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  EntityAvatar(icon: _icon, color: _color, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Color'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in BrandColors.palette)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _color = c.toARGB32()),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: _color == c.toARGB32()
                              ? Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                  width: 3,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Ícono'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in IconCatalog.icons.entries)
                    IconButton.filledTonal(
                      isSelected: _icon == entry.key,
                      onPressed: () => setState(() => _icon = entry.key),
                      icon: Icon(
                        entry.value,
                        color: _icon == entry.key ? Color(_color) : null,
                      ),
                    ),
                ],
              ),
              if (widget.showGroup) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _groupId,
                  decoration: const InputDecoration(
                    labelText: 'Grupo sugerido',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Ninguno'),
                    ),
                    for (final g in widget.groups)
                      DropdownMenuItem<String?>(
                        value: g.id,
                        child: Text(g.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _groupId = v),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
