// lib/features/history/history_screen.dart
// Field history list + per-field trend charts using fl_chart.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Field History')),
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: fields.length,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No test history yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to your SoilSense device and run a test '
              'to start building your field history.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
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
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.terrain,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          field.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          field.crop == Crop.maize ? 'Maize 🌽' : 'Rice 🌾',
        ),
        children: [
          _TrendChart(fieldId: field.id),
          const Divider(height: 1),
          StreamBuilder<List<TestReading>>(
            stream: db.watchReadingsForField(field.id),
            builder: (context, snap) {
              final readings = snap.data ?? [];

              if (readings.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No readings yet. Connect your device and run a test.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                );
              }

              return Column(
                children: readings.map((r) {
                  return FutureBuilder<List<MeasurementRow>>(
                    future: db.getMeasurementsForReading(r.id),
                    builder: (context, msnap) {
                      final ms = msnap.data ?? [];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.science, size: 20),
                        title: Text(dateFormat.format(r.takenAt)),
                        subtitle: ms.isEmpty
                            ? null
                            : Text(
                                'N:${_get(ms, SensorType.nitrogen)}  '
                                'P:${_get(ms, SensorType.phosphorus)}  '
                                'K:${_get(ms, SensorType.potassium)}  '
                                'pH:${_get(ms, SensorType.ph)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => db.deleteReading(r.id),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _get(List<MeasurementRow> ms, SensorType type) {
    final found = ms.where((m) => m.sensorType == type).firstOrNull;
    if (found == null) return '-';
    if (type == SensorType.ph) return found.value.toStringAsFixed(1);
    return found.value.toStringAsFixed(0);
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
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  'NPK Trend',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.grey.shade200,
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
                            style: const TextStyle(fontSize: 10),
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
                              style: const TextStyle(fontSize: 9),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      _makeLine(entries, (e) => _n(e), Colors.red),
                      _makeLine(entries, (e) => _p(e), Colors.orange),
                      _makeLine(entries, (e) => _k(e), Colors.blue),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) {
                          return spots.map((s) {
                            const labels = {0: 'N', 1: 'P', 2: 'K'};
                            return LineTooltipItem(
                              '${labels[s.barIndex]}: ${s.y.toStringAsFixed(1)}',
                              TextStyle(
                                color: s.bar.color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Row(
                  children: const [
                    _LegendDot(color: Colors.red, label: 'N'),
                    SizedBox(width: 12),
                    _LegendDot(color: Colors.orange, label: 'P'),
                    SizedBox(width: 12),
                    _LegendDot(color: Colors.blue, label: 'K'),
                  ],
                ),
              ),
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
      color: color,
      barWidth: 2,
      dotData: FlDotData(
        show: true,
        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeColor: Colors.white,
          strokeWidth: 1,
        ),
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  double _n(FieldHistoryEntry e) =>
      e.measurements.where((m) => m.sensorType == SensorType.nitrogen).firstOrNull?.value ?? 0;
  double _p(FieldHistoryEntry e) =>
      e.measurements.where((m) => m.sensorType == SensorType.phosphorus).firstOrNull?.value ?? 0;
  double _k(FieldHistoryEntry e) =>
      e.measurements.where((m) => m.sensorType == SensorType.potassium).firstOrNull?.value ?? 0;
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
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
