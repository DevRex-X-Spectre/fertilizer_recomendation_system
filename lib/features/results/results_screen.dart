// lib/features/results/results_screen.dart
// Shows sensor values, fertilizer recommendations, and suggestions.
// This screen is pushed after a reading is saved and recommendation is computed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../engine/recommendation_engine.dart';

class ResultsScreen extends ConsumerWidget {
  final int readingId;
  final int fieldId;
  final Crop crop;
  final SensorValues values;

  const ResultsScreen({
    super.key,
    required this.readingId,
    required this.fieldId,
    required this.crop,
    required this.values,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = RecommendationEngine(crop: crop, values: values);
    final result = engine.run();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Results'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sensor Values Card ──────────────────────────────────────────
            _SectionTitle('Sensor Readings'),
            const SizedBox(height: 8),
            _SensorValuesCard(values: values),
            const SizedBox(height: 24),

            // ── Fertilizer Recommendations ─────────────────────────────────
            _SectionTitle('Fertilizer Recommendations'),
            const SizedBox(height: 8),
            if (result.fertilizers.isEmpty)
              _NoRecommendationCard(
                icon: Icons.check_circle_outline,
                message: 'All nutrient levels are adequate. '
                    'No fertilizer application is recommended at this time.',
              )
            else
              ...result.fertilizers.map(
                (f) => _FertilizerCard(fertilizer: f),
              ),

            const SizedBox(height: 24),

            // ── Agronomic Suggestions ──────────────────────────────────────
            _SectionTitle('Agronomic Suggestions'),
            const SizedBox(height: 8),
            if (result.suggestions.isEmpty)
              _NoRecommendationCard(
                icon: Icons.thumb_up_outlined,
                message: 'Soil conditions look good. '
                    'No additional management actions are required.',
              )
            else
              ...result.suggestions.map(
                (s) => _SuggestionCard(suggestion: s),
              ),

            const SizedBox(height: 24),

            // ── Save button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _saveAndExit(context, ref),
                icon: const Icon(Icons.save),
                label: const Text('Save to Field History'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Discard'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndExit(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);

    // Measurement entries from SensorValues
    final entries = [
      MeasurementEntry(sensorType: SensorType.nitrogen,   value: values.nitrogen,   unit: 'ppm'),
      MeasurementEntry(sensorType: SensorType.phosphorus, value: values.phosphorus, unit: 'ppm'),
      MeasurementEntry(sensorType: SensorType.potassium,  value: values.potassium,  unit: 'ppm'),
      MeasurementEntry(sensorType: SensorType.ph,         value: values.ph,         unit: ''),
      MeasurementEntry(sensorType: SensorType.salinity,   value: values.salinity,   unit: 'dS/m'),
      MeasurementEntry(sensorType: SensorType.moisture,   value: values.moisture,   unit: '%'),
    ];

    await db.insertMeasurements(readingId, entries);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reading saved to field history'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context); // back to device screen
    }
  }
}

// ── Sensor Values Card ────────────────────────────────────────────────────────

class _SensorValuesCard extends StatelessWidget {
  final SensorValues values;

  const _SensorValuesCard({required this.values});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SensorRow(
              label: 'Nitrogen (N)',
              value: values.nitrogen,
              unit: 'ppm',
              status: values.nitrogen.nutrientColor(20, 40, 60),
              deficientThreshold: 20,
              adequateMin: 40,
            ),
            const Divider(height: 20),
            _SensorRow(
              label: 'Phosphorus (P)',
              value: values.phosphorus,
              unit: 'ppm',
              status: values.phosphorus.nutrientColor(8, 15, 25),
              deficientThreshold: 8,
              adequateMin: 15,
            ),
            const Divider(height: 20),
            _SensorRow(
              label: 'Potassium (K)',
              value: values.potassium,
              unit: 'ppm',
              status: values.potassium.nutrientColor(60, 120, 200),
              deficientThreshold: 60,
              adequateMin: 120,
            ),
            const Divider(height: 20),
            _SensorRow(
              label: 'pH',
              value: values.ph,
              unit: '',
              status: _phColor(values.ph),
              deficientThreshold: 5.5,
              adequateMin: 6.0,
            ),
            const Divider(height: 20),
            _SensorRow(
              label: 'Salinity (EC)',
              value: values.salinity,
              unit: 'dS/m',
              status: _salinityColor(values.salinity),
              deficientThreshold: 0,
              adequateMin: 0,
            ),
            const Divider(height: 20),
            _SensorRow(
              label: 'Moisture',
              value: values.moisture,
              unit: '%',
              status: _moistureColor(values.moisture),
              deficientThreshold: 0,
              adequateMin: 0,
            ),
          ],
        ),
      ),
    );
  }

  Color _phColor(double ph) {
    if (ph < 5.5) return Colors.red;
    if (ph < 6.0) return Colors.amber;
    if (ph <= 7.0) return Colors.green;
    if (ph <= 7.5) return Colors.amber;
    return Colors.blue;
  }

  Color _salinityColor(double ec) {
    if (ec < 2) return Colors.green;
    if (ec < 4) return Colors.amber;
    return Colors.red;
  }

  Color _moistureColor(double m) {
    if (m < 20) return Colors.red;
    if (m < 40) return Colors.amber;
    if (m <= 70) return Colors.green;
    return Colors.blue;
  }
}

class _SensorRow extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color status;
  final double deficientThreshold;
  final double adequateMin;

  const _SensorRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.deficientThreshold,
    required this.adequateMin,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: status,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                '${value.toStringAsFixed(1)} $unit',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: status.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _statusLabel,
            style: TextStyle(
              color: status,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String get _statusLabel {
    if (label.contains('pH')) {
      if (value < 5.5) return 'Acidic';
      if (value <= 7.0) return 'Optimal';
      return 'Alkaline';
    }
    if (label.contains('Salinity')) {
      if (value < 2) return 'Normal';
      if (value < 4) return 'Slight';
      return 'High';
    }
    if (label.contains('Moisture')) {
      if (value < 20) return 'Dry';
      if (value <= 70) return 'Adequate';
      return 'Saturated';
    }
    if (value < deficientThreshold) return 'Deficient';
    if (value < adequateMin) return 'Low';
    return 'Adequate';
  }
}

// ── Fertilizer Card ──────────────────────────────────────────────────────────

class _FertilizerCard extends StatelessWidget {
  final FertilizerRecommendation fertilizer;

  const _FertilizerCard({required this.fertilizer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    fertilizer.npk,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fertilizer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                'Apply ${fertilizer.quantityLabel}',
                style: TextStyle(
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              fertilizer.applicationNote,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Suggestion Card ──────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final AgronomicSuggestion suggestion;

  const _SuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.body,
              style: TextStyle(
                color: Colors.blue.shade800,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _NoRecommendationCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _NoRecommendationCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: Colors.green, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.green.shade900, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
