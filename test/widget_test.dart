// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soilsense/data/models.dart';
import 'package:soilsense/engine/recommendation_engine.dart';

void main() {
  test('Recommendation engine produces fertilizer recommendations for maize', () {
    final values = const SensorValues(
      nitrogen: 12.0,    // deficient
      phosphorus: 5.0,   // deficient
      potassium: 50.0,   // deficient
      ph: 5.0,           // acidic
      salinity: 1.0,     // normal
      moisture: 25.0,    // adequate
    );
    final engine = RecommendationEngine(crop: Crop.maize, values: values);
    final result = engine.run();

    // Should recommend at least one fertilizer (low N, P, K).
    expect(result.fertilizers, isNotEmpty);
    expect(result.suggestions, isNotEmpty); // pH suggestion expected.
  });

  test('Recommendation engine gives no fertilizer when levels are adequate', () {
    final values = const SensorValues(
      nitrogen: 50.0,    // adequate
      phosphorus: 20.0,  // adequate
      potassium: 150.0,  // adequate
      ph: 6.5,           // optimal
      salinity: 1.0,     // normal
      moisture: 30.0,    // adequate
    );
    final engine = RecommendationEngine(crop: Crop.rice, values: values);
    final result = engine.run();

    expect(result.fertilizers, isEmpty);
    expect(result.suggestions, isEmpty);
  });

  test('Crop and SensorType enums have stable display names', () {
    expect(Crop.maize.displayName, 'Maize');
    expect(Crop.rice.displayName, 'Rice');
    expect(SensorType.nitrogen.unit, 'ppm');
    expect(SensorType.ph.unit, '');
  });
}
