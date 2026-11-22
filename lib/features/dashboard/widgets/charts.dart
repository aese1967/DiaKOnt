import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/analytics.dart';

/// Gráfico de barras interactivo del consumo por período.
/// Tocar (o pasar el mouse por) una barra muestra el total y el IVA.
class SpendingBarChart extends StatefulWidget {
  const SpendingBarChart({
    super.key,
    required this.buckets,
    required this.granularity,
    required this.currency,
  });

  final List<Bucket> buckets;
  final Granularity granularity;
  final String currency;

  @override
  State<SpendingBarChart> createState() => _SpendingBarChartState();
}

class _SpendingBarChartState extends State<SpendingBarChart> {
  int? _touched;

  String _label(DateTime d) => switch (widget.granularity) {
    Granularity.day => '${d.day}',
    Granularity.week => '${d.day}/${d.month}',
    Granularity.month => Fmt.shortMonth(d).replaceAll('.', ''),
    Granularity.year => '${d.year}',
  };

  String _longLabel(Bucket b) => switch (widget.granularity) {
    Granularity.day => Fmt.date(b.start),
    Granularity.week =>
      'Semana del ${Fmt.dayMonth(b.start)} al ${Fmt.dayMonth(b.end.subtract(const Duration(days: 1)))}',
    Granularity.month => Fmt.monthYear(b.start),
    Granularity.year => 'Año ${b.start.year}',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxCents = widget.buckets.fold<int>(
      0,
      (m, b) => b.totalCents > m ? b.totalCents : m,
    );
    final maxY = maxCents == 0 ? 100.0 : maxCents * 1.15;
    final muted = scheme.onSurfaceVariant;
    // Mostrar como máximo ~7 etiquetas para que no se encimen.
    final step = (widget.buckets.length / 7).ceil();

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) => value == meta.max
                  ? const SizedBox.shrink()
                  : Text(
                      Fmt.compact(value.round()),
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= widget.buckets.length) {
                  return const SizedBox.shrink();
                }
                final isLast = i == widget.buckets.length - 1;
                if (!isLast && (widget.buckets.length - 1 - i) % step != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _label(widget.buckets[i].start),
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchCallback: (event, response) {
            setState(() {
              _touched = event.isInterestedForInteractions
                  ? response?.spot?.touchedBarGroupIndex
                  : null;
            });
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => BrandColors.navy,
            tooltipBorderRadius: BorderRadius.circular(10),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, _, _, _) {
              final b = widget.buckets[group.x];
              return BarTooltipItem(
                '${_longLabel(b)}\n',
                const TextStyle(color: Colors.white70, fontSize: 12),
                children: [
                  TextSpan(
                    text: Fmt.money(b.totalCents, currency: widget.currency),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text:
                        '\nIVA ${Fmt.money(b.vatCents, currency: widget.currency)}',
                    style: const TextStyle(
                      color: BrandColors.amber,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < widget.buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: widget.buckets[i].totalCents.toDouble(),
                  width: widget.buckets.length > 12 ? 12 : 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: _touched == i
                        ? const [BrandColors.emerald, Color(0xFF34D399)]
                        : [
                            scheme.primary,
                            scheme.primary.withValues(alpha: 0.7),
                          ],
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: scheme.primary.withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Un segmento de la dona.
class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.cents,
    required this.color,
  });
  final String label;
  final int cents;
  final Color color;
}

/// Gráfico de dona con leyenda. Tocar un segmento (o su fila de la leyenda)
/// lo resalta y muestra su monto en el centro.
class DistributionDonut extends StatefulWidget {
  const DistributionDonut({
    super.key,
    required this.slices,
    required this.currency,
  });
  final List<DonutSlice> slices;
  final String currency;

  @override
  State<DistributionDonut> createState() => _DistributionDonutState();
}

class _DistributionDonutState extends State<DistributionDonut> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final total = widget.slices.fold<int>(0, (s, e) => s + e.cents);
    if (total == 0) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Sin gastos en este período')),
      );
    }
    final focus = _touched != null && _touched! < widget.slices.length
        ? widget.slices[_touched!]
        : null;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 62,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions) return;
                      final i = response?.touchedSection?.touchedSectionIndex;
                      setState(
                        () => _touched = (i == null || i < 0) ? null : i,
                      );
                    },
                  ),
                  sections: [
                    for (var i = 0; i < widget.slices.length; i++)
                      PieChartSectionData(
                        value: widget.slices[i].cents.toDouble(),
                        color: widget.slices[i].color,
                        radius: _touched == i ? 30 : 22,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    focus?.label ?? 'Total',
                    style: TextStyle(color: muted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    Fmt.money(focus?.cents ?? total, currency: widget.currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (focus != null)
                    Text(
                      '${(focus.cents * 100 / total).toStringAsFixed(1).replaceAll('.', ',')} %',
                      style: TextStyle(
                        color: focus.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < widget.slices.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _touched = _touched == i ? null : i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: widget.slices[i].color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.slices[i].label,
                      style: TextStyle(
                        fontWeight: _touched == i
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${(widget.slices[i].cents * 100 / total).round()} %',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    Fmt.money(
                      widget.slices[i].cents,
                      currency: widget.currency,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
