import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';

/// Isotipo provisorio de DiaKont dibujado con widgets (el logo SVG definitivo
/// llega en la Fase 4). Cuadrado redondeado azul con una "D" y un acento
/// esmeralda en forma de barra de crecimiento.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: BrandColors.heroGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: BrandColors.blue.withValues(alpha: 0.35),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'D',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.56,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          Positioned(
            right: size * 0.2,
            bottom: size * 0.2,
            child: Container(
              width: size * 0.14,
              height: size * 0.14,
              decoration: const BoxDecoration(
                color: BrandColors.emerald,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo + nombre "DiaKont by Southdevs".
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.size = 44, this.light = false});
  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogo(size: size),
        SizedBox(width: size * 0.3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DiaKont',
              style: TextStyle(
                fontSize: size * 0.55,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.1,
              ),
            ),
            Text(
              'by Southdevs',
              style: TextStyle(
                fontSize: size * 0.27,
                color: color.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
