// lib/engine/recommendation_engine.dart
// Hardcoded agronomic rules for Nigerian maize & rice cultivation.
// Rules are based on FMARD / IAR Zaria recommended rates.
// Thresholds are in ppm (N/P/K), pH unit, dS/m (salinity), % (moisture).
// Hardware calibration note: verify sensor output ranges match these units.

import '../data/models.dart';

class RecommendationEngine {
  final Crop crop;
  final SensorValues values;

  const RecommendationEngine({
    required this.crop,
    required this.values,
  });

  RecommendationResult run() {
    final fertilizers = <FertilizerRecommendation>[];
    final suggestions = <AgronomicSuggestion>[];

    // ── Nitrogen ──────────────────────────────────────────────────────────
    final nRec = _nitrogenRec();
    if (nRec != null) fertilizers.add(nRec);

    // ── Phosphorus ───────────────────────────────────────────────────────
    final pRec = _phosphorusRec();
    if (pRec != null) fertilizers.add(pRec);

    // ── Potassium ────────────────────────────────────────────────────────
    final kRec = _potassiumRec();
    if (kRec != null) fertilizers.add(kRec);

    // ── pH ──────────────────────────────────────────────────────────────
    final phSug = _phSuggestion();
    if (phSug != null) suggestions.add(phSug);

    // ── Salinity ─────────────────────────────────────────────────────────
    final saltSug = _salinitySuggestion();
    if (saltSug != null) suggestions.add(saltSug);

    // ── Moisture ─────────────────────────────────────────────────────────
    final moistureSug = _moistureSuggestion();
    if (moistureSug != null) suggestions.add(moistureSug);

    return RecommendationResult(
      fertilizers: fertilizers,
      suggestions: suggestions,
    );
  }

  // ── Nitrogen thresholds (ppm) ─────────────────────────────────────────
  // Deficient: < 20 ppm | Medium: 20–40 | Adequate: 40–60 | High: > 60
  FertilizerRecommendation? _nitrogenRec() {
    final n = values.nitrogen;
    switch (crop) {
      case Crop.maize:
        if (n < 20) {
          // Target: 120 kg N/ha. Urea 46% N → ~261 kg/ha of Urea
          return const FertilizerRecommendation(
            name: 'Urea (46-0-0)',
            npk: '46-0-0',
            quantityKgHa: 130,
            applicationNote:
                'Apply at planting (50%) and at V8 stage (50%). '
                'Broadcast and incorporate into soil. '
                'Do not apply when rain is expected within 6 hours.',
          );
        } else if (n < 40) {
          return const FertilizerRecommendation(
            name: 'Urea (46-0-0)',
            npk: '46-0-0',
            quantityKgHa: 65,
            applicationNote:
                'Light top-dress at V6–V8 stage. '
                'Split application recommended if possible.',
          );
        }
        return null;

      case Crop.rice:
        if (n < 20) {
          // Target: 100 kg N/ha for lowland rice
          return const FertilizerRecommendation(
            name: 'Urea (46-0-0)',
            npk: '46-0-0',
            quantityKgHa: 110,
            applicationNote:
                'Apply in 3 splits: 1/3 at transplanting, '
                '1/3 at tillering (21 DAT), 1/3 at panicle initiation.',
          );
        } else if (n < 40) {
          return const FertilizerRecommendation(
            name: 'Urea (46-0-0)',
            npk: '46-0-0',
            quantityKgHa: 55,
            applicationNote:
                'Top-dress at mid-tillering. '
                'Consider split application if water management allows.',
          );
        }
        return null;
    }
  }

  // ── Phosphorus thresholds (ppm) ─────────────────────────────────────────
  // Deficient: < 8 ppm | Medium: 8–15 | Adequate: 15–25 | High: > 25
  FertilizerRecommendation? _phosphorusRec() {
    final p = values.phosphorus;
    if (p < 8) {
      // SSP ~9% P2O5; target ~30 kg P2O5/ha
      return FertilizerRecommendation(
        name: crop == Crop.maize ? 'NPK 20-10-10' : 'Single Superphosphate (SSP)',
        npk: crop == Crop.maize ? '20-10-10' : '0-9-0',
        quantityKgHa: crop == Crop.maize ? 100 : 160,
        applicationNote: crop == Crop.maize
            ? 'Apply at planting. NPK 20-10-10 supplies N and K alongside P. '
                'Incorporate into soil before planting.'
            : 'Apply at transplanting. SSP also provides calcium. '
                'Broadcast and incorporate before puddling.',
      );
    } else if (p < 15) {
      return FertilizerRecommendation(
        name: crop == Crop.maize ? 'NPK 15-15-15' : 'NPK 15-15-15',
        npk: '15-15-15',
        quantityKgHa: 50,
        applicationNote: 'Apply at planting as a maintenance dose.',
      );
    }
    return null;
  }

  // ── Potassium thresholds (ppm) ───────────────────────────────────────────
  // Deficient: < 60 ppm | Medium: 60–120 | Adequate: 120–200 | High: > 200
  FertilizerRecommendation? _potassiumRec() {
    final k = values.potassium;
    if (k < 60) {
      return FertilizerRecommendation(
        name: 'Muriate of Potash (MOP)',
        npk: '0-0-60',
        quantityKgHa: 80,
        applicationNote:
            'Apply at planting. MOP contains 60% K2O. '
            'Broadcast and incorporate. '
            'Avoid on saline soils — use SOP instead.',
      );
    } else if (k < 120) {
      return FertilizerRecommendation(
        name: 'Muriate of Potash (MOP)',
        npk: '0-0-60',
        quantityKgHa: 40,
        applicationNote: 'Light maintenance application at planting.',
      );
    }
    return null;
  }

  // ── pH suggestions ─────────────────────────────────────────────────────
  // Optimal range: maize 5.8–7.0 | rice 5.5–6.5
  AgronomicSuggestion? _phSuggestion() {
    final ph = values.ph;
    switch (crop) {
      case Crop.maize:
        if (ph < 5.5) {
          return const AgronomicSuggestion(
            title: 'Soil too acidic for maize',
            body:
                'pH is below 5.5. Apply agricultural lime at 2–4 t/ha '
                '(adjust based on initial pH and soil type). '
                'Lime should be incorporated 4–6 weeks before planting. '
                'A clay loam soil needs more lime than a sandy soil for '
                'the same pH adjustment.',
          );
        } else if (ph > 7.5) {
          return const AgronomicSuggestion(
            title: 'Soil alkaline — monitor micronutrients',
            body:
                'pH is above 7.5. Iron and zinc availability may be reduced. '
                'Consider foliar application of iron sulfate if chlorosis appears. '
                'Avoid further liming. Organic matter addition can help '
                'buffer alkaline conditions over time.',
          );
        }
        return null;

      case Crop.rice:
        if (ph < 5.0) {
          return const AgronomicSuggestion(
            title: 'Highly acidic soil — apply lime for rice',
            body:
                'pH below 5.0 reduces tillering and phosphorus availability. '
                'Apply lime at 1–2 t/ha if growing lowland rice on acid sulfate '
                'or peat soils. Test again 4 weeks after application before '
                'planting.',
          );
        } else if (ph > 6.5) {
          return const AgronomicSuggestion(
            title: 'Soil approaching alkaline range for rice',
            body:
                'pH above 6.5 reduces availability of iron, zinc, and phosphorus '
                'for rice. Monitor crops for deficiency symptoms. '
                'Avoid further lime application.',
          );
        }
        return null;
    }
  }

  // ── Salinity (EC) suggestions ───────────────────────────────────────────
  // Non-saline: < 2 dS/m | Slightly saline: 2–4 | Saline: 4–8 | Strongly saline: > 8
  AgronomicSuggestion? _salinitySuggestion() {
    final ec = values.salinity;
    if (ec >= 4 && ec < 8) {
      return const AgronomicSuggestion(
        title: 'Saline soil detected',
        body:
            'EC is in the saline range (4–8 dS/m). Salt-tolerant varieties '
            'are recommended. Improve drainage and apply gypsum (1–2 t/ha) '
            'if sodium is also high. Avoid MOP on saline soils — '
            'use SOP (Sulfate of Potash) instead. '
            'Consider leaching with good quality water if possible.',
      );
    } else if (ec >= 8) {
      return const AgronomicSuggestion(
        title: 'High salinity — remediation needed',
        body:
            'EC is above 8 dS/m. This level is stressful for most crops. '
            'Prioritize leaching with good quality (low-salinity) water. '
            'Apply gypsum before leaching. '
            'Consider fallowing or growing salt-tolerant cover crops first. '
            'Consult a soil extension officer for site-specific remediation.',
      );
    }
    return null;
  }

  // ── Moisture suggestions ───────────────────────────────────────────────
  // Low: < 20% | Adequate: 20–60% | Saturated: > 60%
  AgronomicSuggestion? _moistureSuggestion() {
    final m = values.moisture;
    switch (crop) {
      case Crop.maize:
        if (m < 20) {
          return const AgronomicSuggestion(
            title: 'Low soil moisture — irrigate before planting',
            body:
                'Moisture is critically low. Irrigate thoroughly 1–2 days '
                'before planting. Maize is moisture-sensitive at germination '
                'and flowering (V12–R1). Consider drip or furrow irrigation '
                'if rainfall is unreliable in your area.',
          );
        } else if (m > 70) {
          return const AgronomicSuggestion(
            title: 'Soil waterlogged — improve drainage',
            body:
                'Moisture above 70% indicates waterlogging or poor drainage. '
                'This causes root hypoxia and nitrogen loss through denitrification. '
                'Create raised beds or improve field drainage before planting. '
                'Avoid fertilizing until soil moisture returns to field capacity.',
          );
        }
        return null;

      case Crop.rice:
        if (m < 25) {
          return const AgronomicSuggestion(
            title: 'Lowland rice needs standing water',
            body:
                'Moisture is low. Rice requires puddle and standing water '
                'at 5–10 cm depth. Prepare land with bunds and ensure '
                'reliable water supply before transplanting. '
                'Critical water demand at tillering and panicle initiation stages.',
          );
        } else if (m > 80) {
          return const AgronomicSuggestion(
            title: 'Check drainage for rice crop',
            body:
                'Extremely high moisture may indicate poor field drainage. '
                'While rice needs water, stagnant water deeper than 15 cm '
                'reduces tillering. Maintain shallow flooding (5–10 cm) '
                'with periodic draining for certain varieties.',
          );
        }
        return null;
    }
  }
}
