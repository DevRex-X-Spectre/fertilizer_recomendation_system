// lib/features/results/results_screen.dart
// Shows sensor values, fertilizer recommendations, and suggestions.
// Pushed after a BLE reading arrives and the user picks a field.

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
  final bool readOnly;

  const ResultsScreen({
    super.key,
    required this.readingId,
    required this.fieldId,
    required this.crop,
    required this.values,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = RecommendationEngine(
      crop: crop,
      values: values,
      context: const RecommendationContext(
        readingReliability: ReadingReliability.stableSinglePoint,
      ),
    );
    final result = engine.run();

    return Scaffold(
      appBar: AppBar(
        title: Text(readOnly ? 'Soil test details' : 'Recommendations'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ── Header card: crop + reading ────────────────────────────
            _HeaderCard(crop: crop, values: values),
            const SizedBox(height: 12),
            _RecommendationStatus(result: result),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...result.warnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SoftCard(
                    icon: Icons.info_outline,
                    iconColor: result.recommendationAllowed
                        ? AppTheme.statusLow
                        : AppTheme.error,
                    title: result.recommendationAllowed
                        ? 'Important limitation'
                        : 'Test again before applying fertilizer',
                    body: warning,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ── Sensor Readings ────────────────────────────────────────
            const _SectionHeader('Sensor Readings'),
            const SizedBox(height: 8),
            _SensorValuesCard(values: values),
            const SizedBox(height: 24),

            // ── Fertilizer Recommendations ─────────────────────────────
            const _SectionHeader('Fertilizer'),
            const SizedBox(height: 8),
            if (!result.recommendationAllowed)
              const _SoftCard(
                icon: Icons.restart_alt,
                iconColor: AppTheme.error,
                title: 'Recommendation withheld',
                body:
                    'SoilSense did not produce a fertilizer rate because the sensor data failed its safety checks.',
              )
            else if (result.fertilizers.isEmpty)
              const _SoftCard(
                icon: Icons.check_circle_outline,
                iconColor: AppTheme.statusAdequate,
                title: 'No fertilizer needed',
                body:
                    'All nutrient levels look adequate. No fertilizer '
                    'application is recommended at this time.',
              )
            else
              ...result.fertilizers.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FertilizerCard(fertilizer: f),
                ),
              ),

            const SizedBox(height: 24),

            // ── Agronomic Suggestions ──────────────────────────────────
            const _SectionHeader('Agronomic Advice'),
            const SizedBox(height: 8),
            if (result.suggestions.isEmpty)
              const _SoftCard(
                icon: Icons.thumb_up_outlined,
                iconColor: AppTheme.statusAdequate,
                title: 'All good',
                body:
                    'Soil conditions look healthy. No additional management '
                    'actions are required.',
              )
            else
              ...result.suggestions.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SuggestionCard(suggestion: s),
                ),
              ),

            const SizedBox(height: 28),

            // ── Save button ────────────────────────────────────────────
            if (!readOnly)
              FilledButton.icon(
                onPressed: () => _saveAndExit(context, ref),
                icon: const Icon(Icons.bookmark_added_outlined, size: 20),
                label: const Text('Save to Field History'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            if (!readOnly) const SizedBox(height: 8),
            if (!readOnly)
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: () async {
                    await ref.read(databaseProvider).deleteReading(readingId);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Discard'),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to field'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndExit(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);

    final entries = [
      MeasurementEntry(
        sensorType: SensorType.nitrogen,
        value: values.nitrogen,
        unit: 'ppm',
      ),
      MeasurementEntry(
        sensorType: SensorType.phosphorus,
        value: values.phosphorus,
        unit: 'ppm',
      ),
      MeasurementEntry(
        sensorType: SensorType.potassium,
        value: values.potassium,
        unit: 'ppm',
      ),
      MeasurementEntry(sensorType: SensorType.ph, value: values.ph, unit: 'pH'),
      MeasurementEntry(
        sensorType: SensorType.salinity,
        value: values.salinity,
        unit: 'dS/m',
      ),
      if (values.moistureAvailable)
        MeasurementEntry(
          sensorType: SensorType.moisture,
          value: values.moisture,
          unit: '%',
        ),
    ];

    await db.insertMeasurements(readingId, entries);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reading saved to field history'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }
}

class _RecommendationStatus extends StatelessWidget {
  final RecommendationResult result;

  const _RecommendationStatus({required this.result});

  @override
  Widget build(BuildContext context) {
    final allowed = result.recommendationAllowed;
    final color = !allowed
        ? AppTheme.error
        : result.confidence >= 0.8
        ? AppTheme.statusAdequate
        : AppTheme.statusLow;
    final label = !allowed
        ? 'Reading rejected'
        : result.confidence >= 0.8
        ? 'High-confidence assessment'
        : 'Preliminary assessment';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            allowed ? Icons.verified_outlined : Icons.warning_amber,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label · ${(result.confidence * 100).round()}%',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header card ───────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final Crop crop;
  final SensorValues values;

  const _HeaderCard({required this.crop, required this.values});

  @override
  Widget build(BuildContext context) {
    final isMaize = crop == Crop.maize;
    final cropColor = isMaize ? AppTheme.primary : AppTheme.accent;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cropColor, Color.lerp(cropColor, Colors.black, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isMaize ? Icons.agriculture : Icons.rice_bowl,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMaize ? 'Maize field' : 'Rice field',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Soil test complete',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sensor Values Card ────────────────────────────────────────────────────────

class _SensorValuesCard extends StatelessWidget {
  final SensorValues values;

  const _SensorValuesCard({required this.values});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _SensorRow(
        icon: Icons.science_outlined,
        label: 'Nitrogen (N)',
        value: values.nitrogen.toStringAsFixed(1),
        unit: 'ppm',
        color: AppTheme.statusAdequate,
        status: values.nitrogen.nutrientColor(20, 40, 60),
        statusLabel: _nutrientStatus(
          value: values.nitrogen,
          low: 20,
          med: 40,
          high: 60,
          labels: const ['Deficient', 'Low', 'Adequate', 'Excess'],
        ),
      ),
      const _RowDivider(),
      _SensorRow(
        icon: Icons.grain,
        label: 'Phosphorus (P)',
        value: values.phosphorus.toStringAsFixed(1),
        unit: 'ppm',
        color: AppTheme.accent,
        status: values.phosphorus.nutrientColor(8, 15, 25),
        statusLabel: _nutrientStatus(
          value: values.phosphorus,
          low: 8,
          med: 15,
          high: 25,
          labels: const ['Deficient', 'Low', 'Adequate', 'Excess'],
        ),
      ),
      const _RowDivider(),
      _SensorRow(
        icon: Icons.eco,
        label: 'Potassium (K)',
        value: values.potassium.toStringAsFixed(1),
        unit: 'ppm',
        color: AppTheme.primary,
        status: values.potassium.nutrientColor(60, 120, 200),
        statusLabel: _nutrientStatus(
          value: values.potassium,
          low: 60,
          med: 120,
          high: 200,
          labels: const ['Deficient', 'Low', 'Adequate', 'Excess'],
        ),
      ),
      const _RowDivider(),
      _SensorRow(
        icon: Icons.balance,
        label: 'pH',
        value: values.ph.toStringAsFixed(1),
        unit: '',
        color: const Color(0xFF7C3AED),
        status: _phColor(values.ph),
        statusLabel: _phLabel(values.ph),
      ),
      const _RowDivider(),
      _SensorRow(
        icon: Icons.waves,
        label: 'Salinity (EC)',
        value: values.salinity.toStringAsFixed(2),
        unit: 'dS/m',
        color: const Color(0xFF0891B2),
        status: _salinityColor(values.salinity),
        statusLabel: _salinityLabel(values.salinity),
      ),
      if (values.moistureAvailable) ...[
        const _RowDivider(),
        _SensorRow(
          icon: Icons.water_drop_outlined,
          label: 'Moisture',
          value: values.moisture.toStringAsFixed(0),
          unit: '%',
          color: const Color(0xFF2563EB),
          status: _moistureColor(values.moisture),
          statusLabel: _moistureLabel(values.moisture),
        ),
      ],
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(children: rows),
    );
  }

  String _nutrientStatus({
    required double value,
    required double low,
    required double med,
    required double high,
    required List<String> labels,
  }) {
    if (value < low) return labels[0];
    if (value < med) return labels[1];
    if (value <= high) return labels[2];
    return labels[3];
  }

  Color _phColor(double ph) {
    if (ph < 5.5) return AppTheme.statusDeficient;
    if (ph < 6.0) return AppTheme.statusLow;
    if (ph <= 7.0) return AppTheme.statusAdequate;
    return AppTheme.statusExcess;
  }

  String _phLabel(double ph) {
    if (ph < 5.5) return 'Acidic';
    if (ph <= 7.0) return 'Optimal';
    return 'Alkaline';
  }

  Color _salinityColor(double ec) {
    if (ec < 2) return AppTheme.statusAdequate;
    if (ec < 4) return AppTheme.statusLow;
    return AppTheme.statusDeficient;
  }

  String _salinityLabel(double ec) {
    if (ec < 2) return 'Normal';
    if (ec < 4) return 'Slight';
    return 'High';
  }

  Color _moistureColor(double m) {
    if (m < 20) return AppTheme.statusDeficient;
    if (m <= 70) return AppTheme.statusAdequate;
    return AppTheme.statusExcess;
  }

  String _moistureLabel(double m) {
    if (m < 20) return 'Dry';
    if (m <= 70) return 'Adequate';
    return 'Saturated';
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, thickness: 1, color: AppTheme.outlineVariant),
    );
  }
}

class _SensorRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color status;
  final String statusLabel;

  const _SensorRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.status,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7168),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7168),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: status,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fertilizer Card ──────────────────────────────────────────────────────────

class _FertilizerCard extends StatelessWidget {
  final FertilizerRecommendation fertilizer;

  const _FertilizerCard({required this.fertilizer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.science, color: AppTheme.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fertilizer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    fertilizer.npk,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Text(
              'Why: ${fertilizer.reason}\n\nHow to use: ${fertilizer.applicationNote}',
              style: const TextStyle(
                color: Color(0xFF4B554D),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              size: 18,
              color: Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion.body,
                  style: const TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Soft card (used for "no recommendations" empty states) ─────────────────

class _SoftCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const _SoftCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: const Color(0xFF4B554D),
        letterSpacing: 0.2,
      ),
    );
  }
}
