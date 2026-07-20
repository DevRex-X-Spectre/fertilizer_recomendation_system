import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'results_screen.dart';

class PastTestDetailsScreen extends ConsumerWidget {
  final Field field;
  final TestReading reading;

  const PastTestDetailsScreen({
    super.key,
    required this.field,
    required this.reading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return FutureBuilder<List<MeasurementRow>>(
      future: db.getMeasurementsForReading(reading.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final measurements = snapshot.data;
        if (snapshot.hasError || measurements == null) {
          return _message('This test could not be loaded.');
        }
        double? find(SensorType type) {
          final matches = measurements.where((m) => m.sensorType == type);
          return matches.isEmpty ? null : matches.first.value;
        }

        final n = find(SensorType.nitrogen);
        final p = find(SensorType.phosphorus);
        final k = find(SensorType.potassium);
        final ph = find(SensorType.ph);
        final ec = find(SensorType.salinity);
        if (n == null || p == null || k == null || ph == null || ec == null) {
          return _message('This test is incomplete and cannot be analyzed.');
        }
        final moisture = find(SensorType.moisture);
        return ResultsScreen(
          readingId: reading.id,
          fieldId: field.id,
          crop: field.crop,
          values: SensorValues(
            nitrogen: n,
            phosphorus: p,
            potassium: k,
            ph: ph,
            salinity: ec,
            moisture: moisture ?? 0,
            moistureAvailable: moisture != null,
          ),
          readOnly: true,
        );
      },
    );
  }

  Widget _message(String message) => Scaffold(
    appBar: AppBar(title: const Text('Soil test details')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}
