/// Lógica de IVA de DiaKont.
///
/// Todos los importes se manejan como **enteros en centésimos** (cents) para
/// evitar los errores de redondeo de los `double` en cálculos monetarios.
/// Las tasas se expresan en **puntos básicos** (bp): 22 % = 2200 bp,
/// 10 % (tasa mínima en Uruguay) = 1000 bp, exento = 0 bp.
library;

/// Desglose de un importe: subtotal (sin IVA) + IVA = total.
class VatBreakdown {
  const VatBreakdown({
    required this.subtotalCents,
    required this.vatCents,
    required this.totalCents,
    required this.rateBp,
  });

  final int subtotalCents;
  final int vatCents;
  final int totalCents;
  final int rateBp;

  @override
  String toString() =>
      'VatBreakdown(subtotal: $subtotalCents, iva: $vatCents, '
      'total: $totalCents, tasa: $rateBp bp)';
}

class VatCalculator {
  VatCalculator._();

  /// Tasa básica de IVA en Uruguay.
  static const uruguayBasicRateBp = 2200;

  /// Tasa mínima de IVA en Uruguay.
  static const uruguayMinimumRateBp = 1000;

  /// Calcula el desglose de IVA.
  ///
  /// * [amountIncludesVat] = `true`: el monto ingresado ES el total de la
  ///   boleta; se "extrae" el IVA: subtotal = total / (1 + tasa).
  /// * [amountIncludesVat] = `false`: el monto ingresado es el neto; se SUMA
  ///   el IVA: total = subtotal × (1 + tasa).
  ///
  /// El redondeo es "mitad hacia arriba" al centésimo, y siempre se cumple
  /// `subtotal + iva == total` (el IVA se obtiene por diferencia).
  static VatBreakdown compute({
    required int amountCents,
    required int rateBp,
    required bool amountIncludesVat,
  }) {
    if (amountCents < 0) {
      throw ArgumentError.value(
        amountCents,
        'amountCents',
        'no puede ser negativo',
      );
    }
    if (rateBp < 0) {
      throw ArgumentError.value(rateBp, 'rateBp', 'no puede ser negativa');
    }
    if (rateBp == 0) {
      return VatBreakdown(
        subtotalCents: amountCents,
        vatCents: 0,
        totalCents: amountCents,
        rateBp: 0,
      );
    }

    if (amountIncludesVat) {
      final divisor = 10000 + rateBp;
      // División entera con redondeo mitad-arriba: (a*10000 + d/2) ~/ d
      final subtotal = (amountCents * 10000 + divisor ~/ 2) ~/ divisor;
      return VatBreakdown(
        subtotalCents: subtotal,
        vatCents: amountCents - subtotal,
        totalCents: amountCents,
        rateBp: rateBp,
      );
    }

    final vat = (amountCents * rateBp + 5000) ~/ 10000;
    return VatBreakdown(
      subtotalCents: amountCents,
      vatCents: vat,
      totalCents: amountCents + vat,
      rateBp: rateBp,
    );
  }
}
