import 'package:material_ui/material_ui.dart';


/// Isotipo de DiaKont (la "D" con barras de crecimiento sobre azul profundo).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/logo_512.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'DiaKont',
    );
  }
}

/// Logo + nombre "DiaKont by SouthDevs".
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
              'by SouthDevs',
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
