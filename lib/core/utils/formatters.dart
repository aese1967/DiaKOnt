import 'package:intl/intl.dart';

/// Utilidades de formato y parseo para montos, tasas y fechas (es-UY).
class Fmt {
  Fmt._();

  static final _decimal = NumberFormat.decimalPatternDigits(
    locale: 'es',
    decimalDigits: 2,
  );
  static final _compact = NumberFormat.compact(locale: 'es');

  /// Símbolo de cada moneda admitida.
  static String symbol(String currency) => switch (currency) {
    'USD' => 'US\$',
    'EUR' => '€',
    _ => '\$', // UYU
  };

  /// 123456 cents -> "$ 1.234,56"
  static String money(int cents, {String currency = 'UYU'}) =>
      '${symbol(currency)} ${_decimal.format(cents / 100)}';

  /// Formato corto para ejes de gráficos: 1530000 cents -> "15,3 mil"
  static String compact(int cents) => _compact.format(cents / 100);

  /// 2200 bp -> "22 %" ; 1050 bp -> "10,5 %"
  static String rate(int bp) {
    final whole = bp ~/ 100;
    final frac = bp % 100;
    if (frac == 0) return '$whole %';
    final decimals = frac % 10 == 0
        ? '${frac ~/ 10}'
        : frac.toString().padLeft(2, '0');
    return '$whole,$decimals %';
  }

  static String date(DateTime d) => DateFormat('dd/MM/yyyy', 'es').format(d);
  static String dayMonth(DateTime d) => DateFormat('d MMM', 'es').format(d);
  static String monthYear(DateTime d) =>
      _capitalize(DateFormat('MMMM yyyy', 'es').format(d));
  static String shortMonth(DateTime d) => DateFormat('MMM', 'es').format(d);
  static String dateTime(DateTime d) =>
      DateFormat('dd/MM/yyyy HH:mm', 'es').format(d.toLocal());

  /// Convierte texto ingresado por el usuario en centésimos.
  ///
  /// Acepta "1234", "1234,5", "1.234,56", "1234.56" y "$ 1.234". Si aparecen
  /// punto y coma, el punto se toma como separador de miles (uso uruguayo).
  /// Devuelve `null` si el texto no es un monto válido.
  static int? parseAmountToCents(String input) {
    var s = input.trim().replaceAll(RegExp(r'[^0-9.,]'), '');
    if (s.isEmpty) return null;
    if (s.contains(',') && s.contains('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (s.contains(',')) {
      s = s.replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
      // "1.234" o "1.234.567" sin decimales: puntos de miles.
      s = s.replaceAll('.', '');
    }
    if ('.'.allMatches(s).length > 1) return null;
    final value = double.tryParse(s);
    if (value == null) return null;
    return (value * 100).round();
  }

  /// "22" o "10,5" -> puntos básicos (2200 / 1050).
  static int? parseRateToBp(String input) {
    final s = input.trim().replaceAll('%', '').replaceAll(',', '.').trim();
    final v = double.tryParse(s);
    if (v == null || v < 0 || v > 100) return null;
    return (v * 100).round();
  }

  /// Centésimos -> texto editable "1234,56" (para precargar formularios).
  static String centsToInput(int cents) =>
      (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

  /// Puntos básicos -> texto editable "22" o "10,5".
  static String bpToInput(int bp) => rate(bp).replaceAll(' %', '');

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
