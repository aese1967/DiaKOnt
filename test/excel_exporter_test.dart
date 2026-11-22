import 'package:diakont/data/export/excel_exporter.dart';
import 'package:diakont/data/models/models.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('genera un xlsx con encabezado, filas y totales', () {
    final cat = Category.create(userId: 'u', name: 'UTE', color: 0xFFF59E0B);
    final grp = ExpenseGroup.create(
      userId: 'u',
      name: 'Servicios Fijos',
      color: 0xFF1456C8,
    );
    final e = Expense(
      id: newId(),
      userId: 'u',
      date: DateTime(2026, 11, 5),
      concept: 'Factura UTE',
      categoryId: cat.id,
      groupId: grp.id,
      subtotalCents: 100000,
      vatCents: 22000,
      totalCents: 122000,
      vatRateBp: 2200,
      vatIncluded: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final bytes = ExcelExporter.build(
      expenses: [e, e],
      categories: {cat.id: cat},
      groups: {grp.id: grp},
      title: 'Test',
      subtitle: 'Sub',
    );
    final book = Excel.decodeBytes(bytes);
    final sheet = book['Gastos'];
    expect(sheet.rows[3][1]?.value.toString(), 'Concepto');
    expect(sheet.rows[4][1]?.value.toString(), 'Factura UTE');
    expect(sheet.rows[4][2]?.value.toString(), 'UTE');
    expect(sheet.rows[4][3]?.value.toString(), 'Servicios Fijos');
    // Fila de totales
    expect(double.parse(sheet.rows[6][7]!.value.toString()), 2440);
  });
}
