// lib/data/models.dart
// Domain models shared across the app.
// These are plain Dart classes — no DB annotations here.

enum Crop {
  maize,
  rice;

  String get displayName {
    switch (this) {
      case Crop.maize:
        return 'Maize';
      case Crop.rice:
        return 'Rice';
    }
  }
}

enum SensorType {
  nitrogen,
  phosphorus,
  potassium,
  ph,
  salinity,
  moisture;

  String get displayName {
    switch (this) {
      case SensorType.nitrogen:
        return 'Nitrogen (N)';
      case SensorType.phosphorus:
        return 'Phosphorus (P)';
      case SensorType.potassium:
        return 'Potassium (K)';
      case SensorType.ph:
        return 'pH';
      case SensorType.salinity:
        return 'Salinity (EC)';
      case SensorType.moisture:
        return 'Moisture';
    }
  }

  String get unit {
    switch (this) {
      case SensorType.nitrogen:
      case SensorType.phosphorus:
      case SensorType.potassium:
        return 'ppm';
      case SensorType.ph:
        return '';
      case SensorType.salinity:
        return 'dS/m';
      case SensorType.moisture:
        return '%';
    }
  }
}

/// One sensor measurement from the hardware.
class SensorMeasurement {
  final SensorType type;
  final double value;

  const SensorMeasurement({required this.type, required this.value});

  String get displayValue {
    if (type == SensorType.ph) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(1);
  }
}

/// All sensor values from one soil test reading.
class SensorValues {
  final double nitrogen; // ppm
  final double phosphorus; // ppm
  final double potassium; // ppm
  final double ph;
  final double salinity; // dS/m
  final double moisture; // %
  final bool moistureAvailable;

  const SensorValues({
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.ph,
    required this.salinity,
    required this.moisture,
    this.moistureAvailable = true,
  });

  SensorMeasurement operator [](SensorType type) {
    switch (type) {
      case SensorType.nitrogen:
        return SensorMeasurement(type: type, value: nitrogen);
      case SensorType.phosphorus:
        return SensorMeasurement(type: type, value: phosphorus);
      case SensorType.potassium:
        return SensorMeasurement(type: type, value: potassium);
      case SensorType.ph:
        return SensorMeasurement(type: type, value: ph);
      case SensorType.salinity:
        return SensorMeasurement(type: type, value: salinity);
      case SensorType.moisture:
        return SensorMeasurement(type: type, value: moisture);
    }
  }

  static const empty = SensorValues(
    nitrogen: 0,
    phosphorus: 0,
    potassium: 0,
    ph: 0,
    salinity: 0,
    moisture: 0,
    moistureAvailable: false,
  );
}

/// One fertilizer recommendation with application advice.
class FertilizerRecommendation {
  final String name;
  final String npk;
  final String reason;
  final String applicationNote;

  const FertilizerRecommendation({
    required this.name,
    required this.npk,
    required this.reason,
    required this.applicationNote,
  });
}

/// One general agronomic suggestion (not fertilizer-specific).
class AgronomicSuggestion {
  final String title;
  final String body;

  const AgronomicSuggestion({required this.title, required this.body});
}

/// Full recommendation result returned by the engine.
class RecommendationResult {
  final List<FertilizerRecommendation> fertilizers;
  final List<AgronomicSuggestion> suggestions;
  final List<String> warnings;
  final double confidence;
  final bool recommendationAllowed;

  const RecommendationResult({
    required this.fertilizers,
    required this.suggestions,
    this.warnings = const [],
    this.confidence = 0.5,
    this.recommendationAllowed = true,
  });

  bool get hasRecommendations =>
      fertilizers.isNotEmpty || suggestions.isNotEmpty;
}

enum AgroEcologicalZone {
  sudanSavanna,
  northernGuineaSavanna,
  southernGuineaSavanna,
  derivedSavanna,
  humidForest,
}

enum RiceEcology { upland, rainfedLowland, irrigatedLowland }

enum ReadingReliability { unverified, stableSinglePoint, compositeFieldSample }

class RecommendationContext {
  final AgroEcologicalZone zone;
  final RiceEcology riceEcology;
  final ReadingReliability readingReliability;

  const RecommendationContext({
    this.zone = AgroEcologicalZone.northernGuineaSavanna,
    this.riceEcology = RiceEcology.rainfedLowland,
    this.readingReliability = ReadingReliability.unverified,
  });
}
