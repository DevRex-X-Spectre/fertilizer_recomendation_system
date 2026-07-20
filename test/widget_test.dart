// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:soilsense/data/models.dart';
import 'package:soilsense/engine/recommendation_engine.dart';

void main() {
  test(
    'Recommendation engine produces fertilizer recommendations for maize',
    () {
      final values = const SensorValues(
        nitrogen: 12.0, // deficient
        phosphorus: 5.0, // deficient
        potassium: 50.0, // deficient
        ph: 5.0, // acidic
        salinity: 1.0, // normal
        moisture: 25.0, // adequate
      );
      final engine = RecommendationEngine(crop: Crop.maize, values: values);
      final result = engine.run();

      // Should recommend at least one fertilizer (low N, P, K).
      expect(result.fertilizers, isNotEmpty);
      expect(
        result.fertilizers.every((item) => item.reason.isNotEmpty),
        isTrue,
      );
      expect(result.suggestions, isNotEmpty); // pH suggestion expected.
    },
  );

  test('adequate nutrients only produce the organic soil amendment', () {
    final values = const SensorValues(
      nitrogen: 50.0, // adequate
      phosphorus: 20.0, // adequate
      potassium: 150.0, // adequate
      ph: 6.5, // optimal
      salinity: 1.0, // normal
      moisture: 30.0, // adequate
    );
    final engine = RecommendationEngine(crop: Crop.rice, values: values);
    final result = engine.run();

    expect(result.fertilizers, hasLength(1));
    expect(result.fertilizers.single.npk, 'Organic soil amendment');
    expect(result.suggestions, isEmpty);
  });

  test('Crop and SensorType enums have stable display names', () {
    expect(Crop.maize.displayName, 'Maize');
    expect(Crop.rice.displayName, 'Rice');
    expect(SensorType.nitrogen.unit, 'ppm');
    expect(SensorType.ph.unit, '');
  });

  test('invalid sensor values block fertilizer advice', () {
    const values = SensorValues(
      nitrogen: 20,
      phosphorus: 10,
      potassium: 80,
      ph: 14,
      salinity: 1,
      moisture: 30,
    );
    final result = RecommendationEngine(crop: Crop.maize, values: values).run();
    expect(result.recommendationAllowed, isFalse);
    expect(result.fertilizers, isEmpty);
    expect(result.warnings, isNotEmpty);
  });

  test(
    'compound fertilizer nutrients are accounted for before straight fertilizers',
    () {
      const values = SensorValues(
        nitrogen: 10,
        phosphorus: 5,
        potassium: 40,
        ph: 6.2,
        salinity: 1,
        moisture: 30,
      );
      final result = RecommendationEngine(
        crop: Crop.maize,
        values: values,
        context: const RecommendationContext(
          readingReliability: ReadingReliability.compositeFieldSample,
        ),
      ).run();
      expect(result.recommendationAllowed, isTrue);
      expect(result.confidence, greaterThanOrEqualTo(0.8));
      expect(result.fertilizers.map((e) => e.name), contains('NPK 15-15-15'));
      expect(
        result.fertilizers.map((e) => e.name),
        contains('Well-decomposed farmyard manure or compost'),
      );
    },
  );
}
