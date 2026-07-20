// lib/features/history/history_screen.dart
// Field history list + per-field trend charts using fl_chart.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../results/past_test_details_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: StreamBuilder<List<Field>>(
        stream: db.watchAllFields(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final fields = snapshot.data ?? [];

          if (fields.isEmpty) {
            return const _EmptyHistoryView();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: fields.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _FieldHistoryCard(field: fields[i]),
          );
        },
      ),
    );
  }
}

class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.timeline,
                size: 56,
                color: AppTheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No history yet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your SoilSense device and run a test '
              'to start building your field history.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7168), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Per-field history card ─────────────────────────────────────────────────

class _FieldHistoryCard extends ConsumerWidget {
  final Field field;

  const _FieldHistoryCard({required this.field});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final isMaize = field.crop == Crop.maize;
    final cropColor = isMaize ? AppTheme.primary : AppTheme.accent;
    final cropIcon = isMaize ? Icons.agriculture : Icons.rice_bowl;
    final cropLabel = isMaize ? 'Maize' : 'Rice';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Theme(
        // Remove the default ExpansionTile divider lines.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: Colors.transparent),
          ),
          collapsedShape: const RoundedRectangleBorder(
            side: BorderSide(color: Colors.transparent),
          ),
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cropColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(cropIcon, color: cropColor, size: 22),
          ),
          title: Text(
            field.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              cropLabel,
              style: const TextStyle(
                color: Color(0xFF6B7168),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          children: [
            _TrendChart(fieldId: field.id),
            const Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.outlineVariant,
            ),
            _ReadingList(field: field, db: db),
          ],
        ),
      ),
    );
  }
}

class _ReadingList extends StatelessWidget {
  final Field field;
  final AppDatabase db;

  const _ReadingList({required this.field, required this.db});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d • h:mm a');

    return StreamBuilder<List<TestReading>>(
      stream: db.watchReadingsForField(field.id),
      builder: (context, snap) {
        final readings = snap.data ?? [];

        if (readings.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No readings yet. Run a test from the Device tab.',
                style: TextStyle(color: Color(0xFF6B7168), fontSize: 13),
              ),
            ),
          );
        }

        return Column(
          children: readings.asMap().entries.map((entry) {
            final i = entry.key;
            final r = entry.value;
            return FutureBuilder<List<MeasurementRow>>(
              future: db.getMeasurementsForReading(r.id),
              builder: (context, msnap) {
                final ms = msnap.data ?? [];
                return Column(
                  children: [
                    ListTile(
                      onTap: ms.isEmpty
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PastTestDetailsScreen(
                                  field: field,
                                  reading: r,
                                ),
                              ),
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      dense: true,
                      leading: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.science_outlined,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                      ),
                      title: Text(
                        dateFormat.format(r.takenAt),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: ms.isEmpty
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 2,
                                children: [
                                  _StatChip(
                                    label: 'N',
                                    value: _get(ms, SensorType.nitrogen),
                                    color: AppTheme.statusAdequate,
                                  ),
                                  _StatChip(
                                    label: 'P',
                                    value: _get(ms, SensorType.phosphorus),
                                    color: AppTheme.accent,
                                  ),
                                  _StatChip(
                                    label: 'K',
                                    value: _get(ms, SensorType.potassium),
                                    color: AppTheme.primary,
                                  ),
                                  _StatChip(
                                    label: 'pH',
                                    value: _get(ms, SensorType.ph),
                                    color: const Color(0xFF7C3AED),
                                  ),
                                ],
                              ),
                            ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Color(0xFF6B7168),
                        ),
                        onPressed: () => db.deleteReading(r.id),
                      ),
                    ),
                    if (i < readings.length - 1)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppTheme.outlineVariant,
                        indent: 56,
                      ),
                  ],
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  String _get(List<MeasurementRow> ms, SensorType type) {
    final found = ms.where((m) => m.sensorType == type).firstOrNull;
    if (found == null) return '-';
    if (type == SensorType.ph) return found.value.toStringAsFixed(1);
    return found.value.toStringAsFixed(0);
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1F18),
          ),
        ),
      ],
    );
  }
}

// ── Trend chart ──────────────────────────────────────────────────────────────

class _TrendChart extends ConsumerWidget {
  final int fieldId;

  const _TrendChart({required this.fieldId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return FutureBuilder<List<FieldHistoryEntry>>(
      future: db.getFieldHistory(fieldId, limit: 10),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const SizedBox(height: 8);
        }

        final entries = snap.data!.reversed.toList(); // oldest first

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6, top: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 14,
                      color: Color(0xFF6B7168),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'NPK trend (last ${entries.length} readings)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Color(0xFF6B7168),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppTheme.outlineVariant,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (v, _) => Text(
                            v.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9CA39B),
                            ),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= entries.length) {
                              return const SizedBox();
                            }
                            final d = entries[i].reading.takenAt;
                            return Text(
                              '${d.day}/${d.month}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF9CA39B),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      _makeLine(
                        entries,
                        (e) => _n(e),
                        AppTheme.statusDeficient,
                      ),
                      _makeLine(entries, (e) => _p(e), AppTheme.accent),
                      _makeLine(entries, (e) => _k(e), AppTheme.primary),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) =>
                            const Color(0xFF1A1F18).withValues(alpha: 0.92),
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        getTooltipItems: (spots) {
                          const labels = {0: 'N', 1: 'P', 2: 'K'};
                          return spots.map((s) {
                            return LineTooltipItem(
                              '${labels[s.barIndex]}: ${s.y.toStringAsFixed(1)}',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: const [
                    _LegendDot(color: AppTheme.statusDeficient, label: 'N'),
                    SizedBox(width: 14),
                    _LegendDot(color: AppTheme.accent, label: 'P'),
                    SizedBox(width: 14),
                    _LegendDot(color: AppTheme.primary, label: 'K'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  LineChartBarData _makeLine(
    List<FieldHistoryEntry> entries,
    double Function(FieldHistoryEntry) getValue,
    Color color,
  ) {
    return LineChartBarData(
      spots: [
        for (int i = 0; i < entries.length; i++)
          FlSpot(i.toDouble(), getValue(entries[i])),
      ],
      isCurved: true,
      curveSmoothness: 0.25,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeColor: Colors.white,
          strokeWidth: 1.5,
        ),
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  double _n(FieldHistoryEntry e) =>
      e.measurements
          .where((m) => m.sensorType == SensorType.nitrogen)
          .firstOrNull
          ?.value ??
      0;
  double _p(FieldHistoryEntry e) =>
      e.measurements
          .where((m) => m.sensorType == SensorType.phosphorus)
          .firstOrNull
          ?.value ??
      0;
  double _k(FieldHistoryEntry e) =>
      e.measurements
          .where((m) => m.sensorType == SensorType.potassium)
          .firstOrNull
          ?.value ??
      0;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7168)),
        ),
      ],
    );
  }
}
