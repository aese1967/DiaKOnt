import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/vat_calculator.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Formulario rápido de gasto / boleta con cálculo de IVA inteligente.
///
/// Flujo pensado para cargar una boleta en segundos:
/// 1. Monto (con foco automático y teclado numérico).
/// 2. "¿El monto incluye IVA?" Sí/No + tasa (22 % por defecto, editable).
/// 3. Desglose en vivo: Subtotal · IVA · Total.
/// 4. Concepto, categoría (con chips), grupo (se preselecciona según la
///    categoría), fecha y notas.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.initial});

  /// Si viene, se edita ese gasto; si no, se crea uno nuevo.
  final Expense? initial;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _concept;
  late final TextEditingController _notes;
  late final TextEditingController _customRate;

  late bool _includesVat;
  late int _rateBp;
  late DateTime _date;
  String? _categoryId;
  String? _groupId;

  /// true si el usuario tocó el grupo a mano (no se pisa al cambiar categoría).
  bool _groupTouched = false;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    final settings = ref.read(settingsProvider);
    _includesVat = e?.vatIncluded ?? settings.defaultVatIncluded;
    _rateBp = e?.vatRateBp ?? settings.defaultVatRateBp;
    _date = e?.date ?? DateTime.now();
    _categoryId = e?.categoryId;
    _groupId = e?.groupId;
    _groupTouched = e != null;
    // Al editar, se precarga el monto tal como se ingresó originalmente.
    final original = e == null
        ? null
        : (e.vatIncluded ? e.totalCents : e.subtotalCents);
    _amount = TextEditingController(
      text: original == null ? '' : Fmt.centsToInput(original),
    );
    _concept = TextEditingController(text: e?.concept ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _customRate = TextEditingController(text: Fmt.bpToInput(_rateBp));
  }

  @override
  void dispose() {
    _amount.dispose();
    _concept.dispose();
    _notes.dispose();
    _customRate.dispose();
    super.dispose();
  }

  VatBreakdown get _breakdown => VatCalculator.compute(
    amountCents: Fmt.parseAmountToCents(_amount.text) ?? 0,
    rateBp: _rateBp,
    amountIncludesVat: _includesVat,
  );

  void _selectCategory(Category c) {
    setState(() {
      _categoryId = c.id;
      // Si la categoría tiene grupo por defecto, se sugiere automáticamente.
      if (!_groupTouched && c.defaultGroupId != null) {
        _groupId = c.defaultGroupId;
      }
      // El concepto se autocompleta con la categoría si está vacío.
      if (_concept.text.trim().isEmpty) _concept.text = c.name;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final b = _breakdown;
    final now = DateTime.now().toUtc();
    final prev = widget.initial;
    final expense = Expense(
      id: prev?.id ?? newId(),
      userId: session.userId,
      date: DateTime(_date.year, _date.month, _date.day),
      concept: _concept.text.trim(),
      categoryId: _categoryId,
      groupId: _groupId,
      subtotalCents: b.subtotalCents,
      vatCents: b.vatCents,
      totalCents: b.totalCents,
      vatRateBp: b.rateBp,
      vatIncluded: _includesVat,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: prev?.createdAt ?? now,
      updatedAt: now,
    );
    await session.expenses.save(expense);
    if (!mounted) return;
    Navigator.of(context).pop();
    showSnack(context, _isEdit ? 'Gasto actualizado' : 'Gasto guardado');
  }

  Future<void> _delete() async {
    final e = widget.initial!;
    final repo = ref.read(sessionProvider).expenses;
    await repo.delete(e.id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Gasto eliminado'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => repo.restore(e),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final categories = ref.watch(categoriesProvider);
    final groups = ref.watch(groupsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar gasto' : 'Nuevo gasto'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                // ------------------------------------------------ Monto
                TextFormField(
                  controller: _amount,
                  autofocus: !_isEdit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Monto',
                    prefixText: '${Fmt.symbol(settings.currency)} ',
                    hintText: '0,00',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final c = Fmt.parseAmountToCents(v ?? '');
                    if (c == null || c <= 0) {
                      return 'Ingresá un monto mayor a 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ------------------------------------------------ IVA
                _VatCard(
                  includesVat: _includesVat,
                  rateBp: _rateBp,
                  rateController: _customRate,
                  breakdown: _breakdown,
                  currency: settings.currency,
                  onIncludesChanged: (v) => setState(() => _includesVat = v),
                  onRateChanged: (bp) => setState(() => _rateBp = bp),
                ),
                const SizedBox(height: 16),

                // ------------------------------------------------ Concepto
                TextFormField(
                  controller: _concept,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Concepto',
                    hintText: 'Ej.: Factura UTE octubre',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribí un concepto'
                      : null,
                ),
                const SizedBox(height: 20),

                // ------------------------------------------------ Categoría
                Text('Categoría', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in categories)
                      ChoiceChip(
                        avatar: EntityAvatar(
                          icon: c.icon,
                          color: c.color,
                          size: 22,
                        ),
                        label: Text(c.name),
                        selected: _categoryId == c.id,
                        onSelected: (_) => _selectCategory(c),
                      ),
                    if (categories.isEmpty)
                      const Text('Creá categorías en la pestaña Categorías.'),
                  ],
                ),
                const SizedBox(height: 20),

                // ------------------------------------------------ Grupo
                DropdownButtonFormField<String?>(
                  initialValue: groups.any((g) => g.id == _groupId)
                      ? _groupId
                      : null,
                  key: ValueKey('group-$_groupId'),
                  decoration: const InputDecoration(
                    labelText: 'Grupo (opcional)',
                    prefixIcon: Icon(Icons.folder_open_rounded),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin grupo'),
                    ),
                    for (final g in groups)
                      DropdownMenuItem<String?>(
                        value: g.id,
                        child: Text(g.name),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _groupId = v;
                    _groupTouched = true;
                  }),
                ),
                const SizedBox(height: 16),

                // ------------------------------------------------ Fecha
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    child: Text(Fmt.date(_date)),
                  ),
                ),
                const SizedBox(height: 16),

                // ------------------------------------------------ Notas
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  'Guardar · ${Fmt.money(_breakdown.totalCents, currency: settings.currency)}',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta "¿El monto incluye IVA?" con selector de tasa y desglose en vivo.
class _VatCard extends StatelessWidget {
  const _VatCard({
    required this.includesVat,
    required this.rateBp,
    required this.rateController,
    required this.breakdown,
    required this.currency,
    required this.onIncludesChanged,
    required this.onRateChanged,
  });

  final bool includesVat;
  final int rateBp;
  final TextEditingController rateController;
  final VatBreakdown breakdown;
  final String currency;
  final ValueChanged<bool> onIncludesChanged;
  final ValueChanged<int> onRateChanged;

  static const _presets = [2200, 1000, 0]; // básica, mínima, exento

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿El monto incluye IVA?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.check_circle_outline_rounded),
                    label: Text('Sí, ya incluido'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.add_circle_outline_rounded),
                    label: Text('No, sumarlo'),
                  ),
                ],
                selected: {includesVat},
                onSelectionChanged: (s) => onIncludesChanged(s.first),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              includesVat
                  ? 'Se descuenta el IVA del total para calcular el neto.'
                  : 'Se suma el IVA al monto ingresado.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Tasa', style: theme.textTheme.titleSmall),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in _presets)
                        ChoiceChip(
                          label: Text(p == 0 ? 'Exento' : Fmt.rate(p)),
                          selected: rateBp == p,
                          onSelected: (_) {
                            rateController.text = Fmt.bpToInput(p);
                            onRateChanged(p);
                          },
                        ),
                      SizedBox(
                        width: 92,
                        child: TextField(
                          controller: rateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            suffixText: '%',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (v) {
                            final bp = Fmt.parseRateToBp(v);
                            if (bp != null) onRateChanged(bp);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            _row(context, 'Subtotal (sin IVA)', breakdown.subtotalCents),
            const SizedBox(height: 6),
            _row(
              context,
              'IVA ${Fmt.rate(breakdown.rateBp)}',
              breakdown.vatCents,
              color: BrandColors.amber,
            ),
            const SizedBox(height: 6),
            _row(
              context,
              'Total',
              breakdown.totalCents,
              bold: true,
              color: BrandColors.emerald,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    int cents, {
    bool bold = false,
    Color? color,
  }) {
    final style = TextStyle(
      fontSize: bold ? 18 : 15,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(
          Fmt.money(cents, currency: currency),
          style: style.copyWith(color: color),
        ),
      ],
    );
  }
}
