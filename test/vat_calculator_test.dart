import 'package:diakont/core/utils/formatters.dart';
import 'package:diakont/core/utils/vat_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VatCalculator', () {
    test('monto CON IVA 22 %: extrae el IVA del total', () {
      final b = VatCalculator.compute(
        amountCents: 122000,
        rateBp: 2200,
        amountIncludesVat: true,
      );
      expect(b.subtotalCents, 100000);
      expect(b.vatCents, 22000);
      expect(b.totalCents, 122000);
    });

    test('monto SIN IVA 22 %: suma el IVA', () {
      final b = VatCalculator.compute(
        amountCents: 100000,
        rateBp: 2200,
        amountIncludesVat: false,
      );
      expect(b.subtotalCents, 100000);
      expect(b.vatCents, 22000);
      expect(b.totalCents, 122000);
    });

    test('tasa mínima 10 % y redondeo al centésimo', () {
      final b = VatCalculator.compute(
        amountCents: 999,
        rateBp: 1000,
        amountIncludesVat: true,
      );
      expect(b.subtotalCents, 908); // 9,99 / 1,10 = 9,0818…
      expect(b.vatCents, 91);
      expect(b.subtotalCents + b.vatCents, b.totalCents);
    });

    test('exento (0 %)', () {
      final b = VatCalculator.compute(
        amountCents: 5000,
        rateBp: 0,
        amountIncludesVat: false,
      );
      expect(b.vatCents, 0);
      expect(b.totalCents, 5000);
    });

    test('subtotal + IVA == total para muchos montos', () {
      for (var a = 1; a < 20000; a += 7) {
        for (final inc in [true, false]) {
          final b = VatCalculator.compute(
            amountCents: a,
            rateBp: 2200,
            amountIncludesVat: inc,
          );
          expect(b.subtotalCents + b.vatCents, b.totalCents);
        }
      }
    });

    test('rechaza montos negativos', () {
      expect(
        () => VatCalculator.compute(
          amountCents: -1,
          rateBp: 2200,
          amountIncludesVat: true,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Fmt.parseAmountToCents', () {
    test('formatos uruguayos y anglosajones', () {
      expect(Fmt.parseAmountToCents('1234'), 123400);
      expect(Fmt.parseAmountToCents('1234,5'), 123450);
      expect(Fmt.parseAmountToCents('1.234,56'), 123456);
      expect(Fmt.parseAmountToCents('1234.56'), 123456);
      expect(Fmt.parseAmountToCents('1.234'), 123400);
      expect(Fmt.parseAmountToCents('\$ 2.500'), 250000);
      expect(Fmt.parseAmountToCents(''), isNull);
      expect(Fmt.parseAmountToCents('abc'), isNull);
    });

    test('tasas', () {
      expect(Fmt.parseRateToBp('22'), 2200);
      expect(Fmt.parseRateToBp('10,5'), 1050);
      expect(Fmt.parseRateToBp('150'), isNull);
      expect(Fmt.rate(2200), '22 %');
      expect(Fmt.rate(1050), '10,5 %');
      expect(Fmt.rate(1025), '10,25 %');
    });
  });
}
