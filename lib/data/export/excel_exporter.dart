import 'package:excel/excel.dart';

import '../models/models.dart';

/// Genera un .xlsx bien formateado con los gastos filtrados.
///
/// Columnas: Fecha | Concepto | Categoría | Grupo | Monto sin IVA | Tasa IVA |
/// IVA | Total. Incluye título, encabezado con color de marca, formato de
/// números con 2 decimales, fila de totales y anchos de columna ajustados.
///
/// Es código Dart puro (sin Flutter): se puede testear y reutilizar.
class ExcelExporter {
  ExcelExporter._();

  static const _sheet = 'Gastos';
  static const headers = [
    'Fecha',
    'Concepto',
    'Categoría',
    'Grupo',
    'Monto sin IVA',
    'Tasa IVA',
    'IVA',
    'Total',
  ];

  static List<int> build({
    required List<Expense> expenses,
    required Map<String, Category> categories,
    required Map<String, ExpenseGroup> groups,
    required String title,
    required String subtitle,
    String currency = 'UYU',
  }) {
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', _sheet);
    final sheet = excel[_sheet];

    final navy = ExcelColor.fromHexString('#0B2A55');
    final light = ExcelColor.fromHexString('#EEF3FB');
    final thin = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString('#D5DCE8'),
    );
    const money = CustomNumericNumFormat(formatCode: '#,##0.00');
    const percent = CustomNumericNumFormat(formatCode: '0.0%');
    const dateFmt = CustomDateTimeNumFormat(formatCode: 'dd/mm/yyyy');

    CellIndex at(int col, int row) =>
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);

    // --- Título y subtítulo -------------------------------------------------
    sheet.merge(
      at(0, 0),
      at(headers.length - 1, 0),
      customValue: TextCellValue(title),
    );
    sheet.cell(at(0, 0)).cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: navy,
    );
    sheet.merge(
      at(0, 1),
      at(headers.length - 1, 1),
      customValue: TextCellValue(subtitle),
    );
    sheet.cell(at(0, 1)).cellStyle = CellStyle(
      italic: true,
      fontColorHex: ExcelColor.fromHexString('#5B6B82'),
    );

    // --- Encabezado ---------------------------------------------------------
    const headerRow = 3;
    for (var c = 0; c < headers.length; c++) {
      final label = c >= 4 && c != 5
          ? '${headers[c]} (${_symbol(currency)})'
          : headers[c];
      final cell = sheet.cell(at(c, headerRow));
      cell.value = TextCellValue(label);
      cell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: navy,
        horizontalAlign: c >= 4 ? HorizontalAlign.Right : HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: thin,
      );
    }

    // --- Filas de datos (orden cronológico) ---------------------------------
    final sorted = [...expenses]..sort((a, b) => a.date.compareTo(b.date));
    var row = headerRow + 1;
    var sumSub = 0, sumVat = 0, sumTotal = 0;
    for (final e in sorted) {
      final zebra = (row - headerRow).isEven ? light : ExcelColor.none;
      CellStyle style({
        NumFormat fmt = NumFormat.standard_0,
        bool right = false,
      }) => CellStyle(
        backgroundColorHex: zebra,
        numberFormat: fmt,
        horizontalAlign: right ? HorizontalAlign.Right : HorizontalAlign.Left,
        bottomBorder: thin,
      );

      final values = <(CellValue, CellStyle)>[
        (
          DateCellValue(
            year: e.date.year,
            month: e.date.month,
            day: e.date.day,
          ),
          style(fmt: dateFmt),
        ),
        (TextCellValue(e.concept), style()),
        (
          TextCellValue(categories[e.categoryId]?.name ?? 'Sin categoría'),
          style(),
        ),
        (TextCellValue(groups[e.groupId]?.name ?? '—'), style()),
        (
          DoubleCellValue(e.subtotalCents / 100),
          style(fmt: money, right: true),
        ),
        (
          DoubleCellValue(e.vatRateBp / 10000),
          style(fmt: percent, right: true),
        ),
        (DoubleCellValue(e.vatCents / 100), style(fmt: money, right: true)),
        (DoubleCellValue(e.totalCents / 100), style(fmt: money, right: true)),
      ];
      for (var c = 0; c < values.length; c++) {
        final cell = sheet.cell(at(c, row));
        cell.value = values[c].$1;
        cell.cellStyle = values[c].$2;
      }
      sumSub += e.subtotalCents;
      sumVat += e.vatCents;
      sumTotal += e.totalCents;
      row++;
    }

    // --- Totales ------------------------------------------------------------
    final totalStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#D1FAE5'),
      topBorder: Border(borderStyle: BorderStyle.Medium, borderColorHex: navy),
      numberFormat: money,
      horizontalAlign: HorizontalAlign.Right,
    );
    final totals = <int, CellValue>{
      0: TextCellValue('TOTAL (${sorted.length} registros)'),
      4: DoubleCellValue(sumSub / 100),
      6: DoubleCellValue(sumVat / 100),
      7: DoubleCellValue(sumTotal / 100),
    };
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(at(c, row));
      if (totals[c] != null) cell.value = totals[c];
      cell.cellStyle = c == 0
          ? CellStyle(
              bold: true,
              backgroundColorHex: ExcelColor.fromHexString('#D1FAE5'),
              topBorder: Border(
                borderStyle: BorderStyle.Medium,
                borderColorHex: navy,
              ),
            )
          : totalStyle;
    }

    // --- Anchos de columna --------------------------------------------------
    const widths = [12.0, 36.0, 18.0, 18.0, 16.0, 10.0, 14.0, 16.0];
    for (var c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }

    final bytes = excel.save();
    if (bytes == null) throw StateError('No se pudo generar el archivo Excel.');
    return bytes;
  }

  static String _symbol(String currency) => switch (currency) {
    'USD' => 'US\$',
    'EUR' => '€',
    _ => '\$',
  };
}
