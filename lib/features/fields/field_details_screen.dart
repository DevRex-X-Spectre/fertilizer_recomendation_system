import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../device/device_screen.dart';
import '../results/past_test_details_screen.dart';

class FieldDetailsScreen extends ConsumerWidget {
  final Field field;

  const FieldDetailsScreen({super.key, required this.field});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final cropColor = field.crop == Crop.maize
        ? AppTheme.primary
        : AppTheme.accent;
    final cropIcon = field.crop == Crop.maize
        ? Icons.agriculture
        : Icons.rice_bowl;

    return Scaffold(
      appBar: AppBar(title: const Text('Field details')),
      body: SafeArea(
        child: StreamBuilder<List<TestReading>>(
          stream: db.watchReadingsForField(field.id),
          builder: (context, snapshot) {
            final readings = snapshot.data ?? const <TestReading>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cropColor, cropColor.withValues(alpha: 0.78)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(cropIcon, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              field.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${field.crop.displayName} field',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DetailsCard(
                  children: [
                    _DetailRow(
                      icon: Icons.eco_outlined,
                      label: 'Crop',
                      value: field.crop.displayName,
                    ),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Created',
                      value: DateFormat('MMMM d, yyyy').format(field.createdAt),
                    ),
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Farm location',
                      value: field.latitude != null && field.longitude != null
                          ? '${field.latitude!.toStringAsFixed(6)}, ${field.longitude!.toStringAsFixed(6)}'
                          : 'Location unavailable',
                    ),
                    _DetailRow(
                      icon: Icons.science_outlined,
                      label: 'Completed tests',
                      value: readings.length.toString(),
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Latest soil test',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                if (readings.isEmpty)
                  const _EmptyReadingCard()
                else
                  _LatestReadingCard(
                    db: db,
                    field: field,
                    reading: readings.first,
                  ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: () {
            ref.read(selectedTestFieldProvider.notifier).state = field;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DeviceScreen(lockedField: field),
              ),
            );
          },
          icon: const Icon(Icons.sensors),
          label: Text('Start soil test for ${field.name}'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailsCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: AppTheme.surfaceTint,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.outlineVariant),
    ),
    child: Column(children: children),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFF6B7168)),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
      if (showDivider) const Divider(),
    ],
  );
}

class _EmptyReadingCard extends StatelessWidget {
  const _EmptyReadingCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.16)),
    ),
    child: const Row(
      children: [
        Icon(Icons.science_outlined, color: AppTheme.primary),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'No readings yet. Start the first soil test for this field.',
            style: TextStyle(color: Color(0xFF4B554D), height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _LatestReadingCard extends StatelessWidget {
  final AppDatabase db;
  final Field field;
  final TestReading reading;

  const _LatestReadingCard({
    required this.db,
    required this.field,
    required this.reading,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<MeasurementRow>>(
    future: db.getMeasurementsForReading(reading.id),
    builder: (context, snapshot) {
      final measurements = snapshot.data ?? const <MeasurementRow>[];
      String value(SensorType type) {
        final matches = measurements.where((m) => m.sensorType == type);
        if (matches.isEmpty) return '—';
        return matches.first.value.toStringAsFixed(1);
      }

      return Material(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: measurements.isEmpty
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PastTestDetailsScreen(field: field, reading: reading),
                  ),
                ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d, yyyy · h:mm a').format(reading.takenAt),
                  style: const TextStyle(
                    color: Color(0xFF6B7168),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ReadingChip(label: 'N', value: value(SensorType.nitrogen)),
                    _ReadingChip(
                      label: 'P',
                      value: value(SensorType.phosphorus),
                    ),
                    _ReadingChip(
                      label: 'K',
                      value: value(SensorType.potassium),
                    ),
                    _ReadingChip(label: 'pH', value: value(SensorType.ph)),
                    _ReadingChip(
                      label: 'EC',
                      value: value(SensorType.salinity),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ReadingChip extends StatelessWidget {
  final String label;
  final String value;

  const _ReadingChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$label  $value',
      style: const TextStyle(
        color: AppTheme.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
