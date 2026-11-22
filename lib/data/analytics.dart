/// Cálculos del dashboard (puros, sin Flutter, fáciles de testear).
library;

import 'models/models.dart';

/// Vistas de tiempo del gráfico de barras.
enum Granularity {
  day('Diaria', 14),
  week('Semanal', 12),
  month('Mensual', 12),
  year('Anual', 5);

  const Granularity(this.label, this.buckets);

  final String label;

  /// Cuántas barras se muestran (los últimos N días/semanas/meses/años).
  final int buckets;
}

/// Una barra del gráfico: período que empieza en [start] (inclusive) y
/// termina en [end] (exclusive).
class Bucket {
  Bucket(this.start, this.end);
  final DateTime start;
  final DateTime end;
  int totalCents = 0;
  int vatCents = 0;
}

class Analytics {
  Analytics._();

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Inicio del período que contiene [d] (semanas empiezan el lunes).
  static DateTime periodStart(Granularity g, DateTime d) => switch (g) {
    Granularity.day => _day(d),
    Granularity.week => _day(d).subtract(Duration(days: d.weekday - 1)),
    Granularity.month => DateTime(d.year, d.month),
    Granularity.year => DateTime(d.year),
  };

  static DateTime _next(Granularity g, DateTime start) => switch (g) {
    // Se usa el constructor de DateTime (no Duration) para que los
    // cambios de horario de verano no corran los límites.
    Granularity.day => DateTime(start.year, start.month, start.day + 1),
    Granularity.week => DateTime(start.year, start.month, start.day + 7),
    Granularity.month => DateTime(start.year, start.month + 1),
    Granularity.year => DateTime(start.year + 1),
  };

  static DateTime _prev(Granularity g, DateTime start) => switch (g) {
    Granularity.day => DateTime(start.year, start.month, start.day - 1),
    Granularity.week => DateTime(start.year, start.month, start.day - 7),
    Granularity.month => DateTime(start.year, start.month - 1),
    Granularity.year => DateTime(start.year - 1),
  };

  /// Arma las barras de los últimos `g.buckets` períodos hasta [now].
  static List<Bucket> buckets(
    List<Expense> expenses,
    Granularity g,
    DateTime now,
  ) {
    final starts = <DateTime>[periodStart(g, now)];
    while (starts.length < g.buckets) {
      starts.insert(0, _prev(g, starts.first));
    }
    final result = [for (final s in starts) Bucket(s, _next(g, s))];
    final first = result.first.start;
    final end = result.last.end;

    for (final e in expenses) {
      if (e.date.isBefore(first) || !e.date.isBefore(end)) continue;
      // Búsqueda lineal inversa: la mayoría de los gastos son recientes.
      for (var i = result.length - 1; i >= 0; i--) {
        if (!e.date.isBefore(result[i].start)) {
          result[i].totalCents += e.totalCents;
          result[i].vatCents += e.vatCents;
          break;
        }
      }
    }
    return result;
  }

  /// Rango completo que cubren las barras (para la torta del mismo período).
  static (DateTime, DateTime) range(Granularity g, DateTime now) {
    var start = periodStart(g, now);
    for (var i = 1; i < g.buckets; i++) {
      start = _prev(g, start);
    }
    return (start, _next(g, periodStart(g, now)));
  }

  static List<Expense> inRange(
    List<Expense> list,
    DateTime from,
    DateTime to,
  ) =>
      list.where((e) => !e.date.isBefore(from) && e.date.isBefore(to)).toList();

  /// Totales agrupados por una clave (categoría o grupo). La clave `null`
  /// representa "Sin categoría" / "Sin grupo". Ordenado de mayor a menor.
  static List<MapEntry<String?, int>> totalsBy(
    Iterable<Expense> list,
    String? Function(Expense) key,
  ) {
    final map = <String?, int>{};
    for (final e in list) {
      map.update(key(e), (v) => v + e.totalCents, ifAbsent: () => e.totalCents);
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Resumen del mes calendario de [now] para las tarjetas.
  static MonthSummary monthSummary(
    List<Expense> list,
    DateTime now,
    int budgetCents,
  ) {
    final from = DateTime(now.year, now.month);
    final to = DateTime(now.year, now.month + 1);
    var total = 0, vat = 0, count = 0;
    for (final e in inRange(list, from, to)) {
      total += e.totalCents;
      vat += e.vatCents;
      count++;
    }
    return MonthSummary(
      totalCents: total,
      vatCents: vat,
      count: count,
      budgetCents: budgetCents,
    );
  }
}

class MonthSummary {
  const MonthSummary({
    required this.totalCents,
    required this.vatCents,
    required this.count,
    required this.budgetCents,
  });

  final int totalCents;
  final int vatCents;
  final int count;
  final int budgetCents;

  bool get hasBudget => budgetCents > 0;
  int get remainingCents => budgetCents - totalCents;

  /// Fracción usada del presupuesto (0..1+, puede pasarse de 1).
  double get usedFraction => hasBudget ? totalCents / budgetCents : 0;
}
