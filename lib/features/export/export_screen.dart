import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/export/excel_exporter.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

enum _Preset { thisMonth, lastMonth, thisYear, custom }

/// Exportación a Excel de los registros filtrados por fecha, grupo y/o
/// categoría. Usa el diálogo nativo "Guardar como" en Windows y el selector
/// de archivos del sistema (Storage Access Framework) en Android.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  _Preset _preset = _Preset.thisMonth;
  late DateTimeRange _range = _rangeFor(_Preset.thisMonth);
  String? _groupId;
  String? _categoryId;
  bool _busy = false;

  DateTimeRange _rangeFor(_Preset p) {
    final now = DateTime.now();
    return switch (p) {
      _Preset.thisMonth => DateTimeRange(
        start: DateTime(now.year, now.month),
        end: DateTime(now.year, now.month + 1, 0),
      ),
      _Preset.lastMonth => DateTimeRange(
        start: DateTime(now.year, now.month - 1),
        end: DateTime(now.year, now.month, 0),
      ),
      _Preset.thisYear => DateTimeRange(
        start: DateTime(now.year),
        end: DateTime(now.year, 12, 31),
      ),
      _Preset.custom => _range,
    };
  }

  Future<void> _pickPreset(_Preset p) async {
    if (p == _Preset.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(DateTime.now().year + 1, 12, 31),
        initialDateRange: _range,
      );
      if (picked == null) return;
      setState(() {
        _preset = p;
        _range = picked;
      });
      return;
    }
    setState(() {
      _preset = p;
      _range = _rangeFor(p);
    });
  }

  List<Expense> _filtered(List<Expense> all) {
    final from = _range.start;
    final to = DateTime(_range.end.year, _range.end.month, _range.end.day + 1);
    return all
        .where(
          (e) =>
              !e.date.isBefore(from) &&
              e.date.isBefore(to) &&
              (_groupId == null || e.groupId == _groupId) &&
              (_categoryId == null || e.categoryId == _categoryId),
        )
        .toList();
  }

  Future<void> _export(List<Expense> rows) async {
    setState(() => _busy = true);
    try {
      final cats = ref.read(categoryMapProvider);
      final groups = ref.read(groupMapProvider);
      final settings = ref.read(settingsProvider);
      final filters = [
        'Del ${Fmt.date(_range.start)} al ${Fmt.date(_range.end)}',
        if (_groupId != null) 'Grupo: ${groups[_groupId]?.name}',
        if (_categoryId != null) 'Categoría: ${cats[_categoryId]?.name}',
      ].join(' · ');

      final bytes = ExcelExporter.build(
        expenses: rows,
        categories: cats,
        groups: groups,
        title: 'DiaKont · Reporte de gastos',
        subtitle: '$filters · Generado el ${Fmt.dateTime(DateTime.now())}',
        currency: settings.currency,
      );

      final name =
          'DiaKont_${dateOnly(_range.start)}_a_${dateOnly(_range.end)}.xlsx';
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Guardar reporte de Excel',
        fileName: name,
        bytes: Uint8List.fromList(bytes),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      if (uri == null) {
        showSnack(context, 'Exportación cancelada');
      } else {
        showSnack(
          context,
          'Excel guardado: ${Uri.decodeComponent(uri.pathSegments.last)}',
        );
      }
    } catch (e) {
      if (mounted) showSnack(context, 'No se pudo exportar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(expensesProvider).value ?? const <Expense>[];
    final groups = ref.watch(groupsProvider);
    final cats = ref.watch(categoriesProvider);
    final currency = ref.watch(settingsProvider).currency;
    final rows = _filtered(all);
    final sub = rows.fold<int>(0, (s, e) => s + e.subtotalCents);
    final vat = rows.fold<int>(0, (s, e) => s + e.vatCents);
    final total = rows.fold<int>(0, (s, e) => s + e.totalCents);

    return Scaffold(
      appBar: AppBar(title: const Text('Exportar a Excel')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Período'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (p, label) in const [
                            (_Preset.thisMonth, 'Este mes'),
                            (_Preset.lastMonth, 'Mes anterior'),
                            (_Preset.thisYear, 'Este año'),
                            (_Preset.custom, 'Personalizado…'),
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: _preset == p,
                              onSelected: (_) => _pickPreset(p),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.date_range_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${Fmt.date(_range.start)}  →  ${Fmt.date(_range.end)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const SectionTitle('Filtros'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: _groupId,
                        decoration: const InputDecoration(
                          labelText: 'Grupo',
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todos'),
                          ),
                          for (final g in groups)
                            DropdownMenuItem<String?>(
                              value: g.id,
                              child: Text(g.name),
                            ),
                        ],
                        onChanged: (v) => setState(() => _groupId = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todas'),
                          ),
                          for (final c in cats)
                            DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SectionTitle(
                        'Vista previa',
                        trailing: Text(
                          '${rows.length} registros',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _line(
                        'Monto sin IVA',
                        Fmt.money(sub, currency: currency),
                      ),
                      _line(
                        'IVA',
                        Fmt.money(vat, currency: currency),
                        color: BrandColors.amber,
                      ),
                      const Divider(),
                      _line(
                        'Total',
                        Fmt.money(total, currency: currency),
                        bold: true,
                        color: BrandColors.emerald,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: rows.isEmpty || _busy ? null : () => _export(rows),
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.table_view_rounded),
                label: const Text('Exportar a Excel (.xlsx)'),
              ),
              const SizedBox(height: 8),
              Text(
                'Columnas: Fecha · Concepto · Categoría · Grupo · Monto sin IVA · Tasa · IVA · Total',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 15,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style.copyWith(color: color)),
        ],
      ),
    );
  }
}
