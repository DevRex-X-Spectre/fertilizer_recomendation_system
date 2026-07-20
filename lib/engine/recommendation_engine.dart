import '../data/models.dart';

/// Selects suitable fertilizer and organic-manure types for Nigerian maize
/// and rice. It intentionally does not prescribe quantities: the probe has
/// not yet been correlated with a laboratory soil-test method, so converting
/// its readings into kg/ha would imply a precision the system does not have.
class RecommendationEngine {
  final Crop crop;
  final SensorValues values;
  final RecommendationContext context;

  const RecommendationEngine({
    required this.crop,
    required this.values,
    this.context = const RecommendationContext(),
  });

  RecommendationResult run() {
    final errors = _validate();
    if (errors.isNotEmpty) {
      return RecommendationResult(
        fertilizers: const [],
        suggestions: const [],
        warnings: errors,
        confidence: 0,
        recommendationAllowed: false,
      );
    }

    final nLow = values.nitrogen < 40;
    final pLow = values.phosphorus < 15;
    final kLow = values.potassium < 120;
    final fertilizers = <FertilizerRecommendation>[];

    // A balanced compound is useful when two or more primary nutrients are
    // limiting. Straight fertilizers are selected only for remaining needs.
    final limitingCount = [nLow, pLow, kLow].where((value) => value).length;
    if (limitingCount >= 2) {
      fertilizers.add(_balancedNpk());
    } else {
      if (nLow) fertilizers.add(_urea());
      if (pLow) fertilizers.add(_ssp());
      if (kLow) fertilizers.add(_potash());
    }

    // Organic matter is valuable in the generally low-carbon Nigerian soils
    // described by the reviewed maize studies. It complements rather than
    // silently replaces a nutrient-specific mineral fertilizer.
    fertilizers.add(_manure());

    final confidence = switch (context.readingReliability) {
      ReadingReliability.compositeFieldSample => 0.9,
      ReadingReliability.stableSinglePoint => 0.7,
      ReadingReliability.unverified => 0.45,
    };
    final warnings = <String>[];
    if (context.readingReliability == ReadingReliability.unverified) {
      warnings.add(
        'Preliminary selection: confirm the probe with several stable field '
        'readings before choosing a fertilizer.',
      );
    } else if (context.readingReliability ==
        ReadingReliability.stableSinglePoint) {
      warnings.add(
        'This represents one point. Test several representative positions '
        'across the field for a more reliable selection.',
      );
    }

    return RecommendationResult(
      fertilizers: fertilizers,
      suggestions: _managementAdvice(),
      warnings: warnings,
      confidence: confidence,
      recommendationAllowed: true,
    );
  }

  List<String> _validate() {
    final errors = <String>[];
    if (values.nitrogen < 0 || values.nitrogen > 500) {
      errors.add('Nitrogen reading is outside the supported sensor range.');
    }
    if (values.phosphorus < 0 || values.phosphorus > 250) {
      errors.add('Phosphorus reading is outside the supported sensor range.');
    }
    if (values.potassium < 0 || values.potassium > 1000) {
      errors.add('Potassium reading is outside the supported sensor range.');
    }
    if (values.ph < 3 || values.ph > 10) {
      errors.add('pH is implausible. Reinsert the probe and test again.');
    }
    if (values.salinity < 0 || values.salinity > 20) {
      errors.add('EC is outside the supported sensor range.');
    }
    if (values.moistureAvailable &&
        (values.moisture < 0 || values.moisture > 100)) {
      errors.add('Moisture must be between 0% and 100%.');
    }
    return errors;
  }

  FertilizerRecommendation _balancedNpk() => FertilizerRecommendation(
    name: crop == Crop.maize ? 'NPK 15-15-15' : 'NPK 15-15-15',
    npk: 'Balanced NPK',
    reason:
        'The reading indicates that more than one of the primary nutrients—nitrogen, phosphorus and potassium—is below the crop threshold.',
    applicationNote: crop == Crop.maize
        ? 'Use as the basal fertilizer at planting. Place it away from direct seed contact and cover it with soil.'
        : 'Use as the basal fertilizer at sowing or transplanting and incorporate it into the root zone.',
  );

  FertilizerRecommendation _urea() => FertilizerRecommendation(
    name: 'Urea',
    npk: 'Nitrogen fertilizer',
    reason:
        'Nitrogen is below the crop threshold while phosphorus and potassium are adequate.',
    applicationNote: crop == Crop.maize
        ? 'Use as a nitrogen top-dressing after establishment. Apply to moist soil and cover it to reduce nitrogen loss.'
        : 'Use as a split nitrogen top-dressing around tillering and panicle initiation. Manage standing water before application.',
  );

  FertilizerRecommendation _ssp() => const FertilizerRecommendation(
    name: 'Single Superphosphate (SSP)',
    npk: 'Phosphorus fertilizer',
    reason:
        'Phosphorus is below the crop threshold while the other primary nutrients are adequate.',
    applicationNote:
        'Use as a basal phosphorus source and incorporate it into the soil at planting.',
  );

  FertilizerRecommendation _potash() => FertilizerRecommendation(
    name: values.salinity >= 4
        ? 'Sulfate of Potash (SOP)'
        : 'Muriate of Potash (MOP)',
    npk: 'Potassium fertilizer',
    reason: values.salinity >= 4
        ? 'Potassium is low, but the EC reading is elevated, so a lower-chloride potassium source is preferred.'
        : 'Potassium is below the crop threshold while nitrogen and phosphorus are adequate.',
    applicationNote: values.salinity >= 4
        ? 'SOP is preferred because the soil EC is elevated. Confirm salinity before application.'
        : 'Use as the potassium source and incorporate it at planting.',
  );

  FertilizerRecommendation _manure() => const FertilizerRecommendation(
    name: 'Well-decomposed farmyard manure or compost',
    npk: 'Organic soil amendment',
    reason:
        'Organic matter supports soil structure, water retention and gradual nutrient cycling for both maize and rice.',
    applicationNote:
        'Use only mature, well-decomposed manure. Mix it into the soil before planting; avoid fresh manure because it may burn seedlings or introduce weeds and pathogens.',
  );

  List<AgronomicSuggestion> _managementAdvice() {
    final advice = <AgronomicSuggestion>[];
    final lowPh = crop == Crop.maize ? 5.5 : 5.0;
    final highPh = crop == Crop.maize ? 7.5 : 6.5;
    if (values.ph < lowPh) {
      advice.add(
        const AgronomicSuggestion(
          title: 'Acid soil needs confirmation',
          body:
              'Low pH can reduce nutrient availability. Confirm with a standard soil test before using lime.',
        ),
      );
    } else if (values.ph > highPh) {
      advice.add(
        const AgronomicSuggestion(
          title: 'High pH: monitor micronutrients',
          body:
              'Avoid liming. High pH can reduce zinc, iron and phosphorus availability.',
        ),
      );
    }
    if (values.salinity >= 4) {
      advice.add(
        const AgronomicSuggestion(
          title: 'Salinity detected',
          body:
              'Improve drainage and confirm EC. Prefer a low-chloride potassium source where potassium is needed.',
        ),
      );
    }
    return advice;
  }
}
