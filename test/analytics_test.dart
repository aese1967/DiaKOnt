import 'package:diakont/data/analytics.dart';
import 'package:diakont/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _e(DateTime d, int total, {String? cat, String? group}) => Expense(
  id: newId(),
  userId: 'u',
  date: d,
  concept: 'x',
  categoryId: cat,
  groupId: group,
  subtotalCents: total,
  vatCents: 0,
  totalCents: total,
  vatRateBp: 0,
  vatIncluded: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  final now = DateTime(2026, 11, 22); // domingo

  test('barras mensuales: 12 meses terminando en el actual', () {
    final b = Analytics.buckets(
      [
        _e(DateTime(2026, 11, 1), 100),
        _e(DateTime(2026, 11, 20), 50),
        _e(DateTime(2026, 10, 31), 70),
        _e(DateTime(2025, 11, 30), 10), // fuera de rango (hace 12 meses)
      ],
      Granularity.month,
      now,
    );
    expect(b.length, 12);
    expect(b.last.start, DateTime(2026, 11));
    expect(b.last.totalCents, 150);
    expect(b[10].totalCents, 70);
    expect(b.first.start, DateTime(2025, 12));
  });

  test('semanas empiezan el lunes', () {
    expect(
      Analytics.periodStart(Granularity.week, now),
      DateTime(2026, 11, 16),
    );
    final b = Analytics.buckets(
      [_e(DateTime(2026, 11, 16), 5)],
      Granularity.week,
      now,
    );
    expect(b.last.totalCents, 5);
  });

  test('vista diaria y anual', () {
    final d = Analytics.buckets([_e(now, 9)], Granularity.day, now);
    expect(d.length, 14);
    expect(d.last.totalCents, 9);
    final y = Analytics.buckets(
      [_e(DateTime(2023, 5, 1), 3)],
      Granularity.year,
      now,
    );
    expect(y.first.start, DateTime(2022));
    expect(y[1].totalCents, 3);
  });

  test('totales por categoría ordenados', () {
    final t = Analytics.totalsBy([
      _e(now, 10, cat: 'a'),
      _e(now, 30, cat: 'b'),
      _e(now, 5, cat: 'a'),
      _e(now, 1),
    ], (e) => e.categoryId);
    expect(t.first.key, 'b');
    expect(t[1].value, 15);
    expect(t.last.key, isNull);
  });

  test('resumen del mes y presupuesto', () {
    final s = Analytics.monthSummary(
      [_e(DateTime(2026, 11, 2), 8000), _e(DateTime(2026, 10, 2), 9999)],
      now,
      10000,
    );
    expect(s.totalCents, 8000);
    expect(s.remainingCents, 2000);
    expect(s.usedFraction, 0.8);
  });
}
