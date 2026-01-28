class MacroNutrient {
  final double carbPercent;
  final double proteinPercent;
  final double fatPercent;

  MacroNutrient({
    required this.carbPercent,
    required this.proteinPercent,
    required this.fatPercent,
  });

  // AMDR (Acceptable Macronutrient Distribution Range) - WHO/USDA guidelines
  static const double carbMinPercent = 45.0;
  static const double carbMaxPercent = 65.0;

  static const double proteinMinPercent = 10.0;
  static const double proteinMaxPercent = 35.0;

  static const double fatMinPercent = 20.0;
  static const double fatMaxPercent = 35.0;

  // Validate total = 100%
  bool isValidTotal() {
    double total = carbPercent + proteinPercent + fatPercent;
    return (total - 100.0).abs() < 0.1; // allow 0.1% tolerance
  }

  // Check if within AMDR
  bool isWithinAMDR() {
    bool carbOk =
        carbPercent >= carbMinPercent && carbPercent <= carbMaxPercent;
    bool proteinOk = proteinPercent >= proteinMinPercent &&
        proteinPercent <= proteinMaxPercent;
    bool fatOk = fatPercent >= fatMinPercent && fatPercent <= fatMaxPercent;
    return carbOk && proteinOk && fatOk;
  }

  // Get warning message if outside AMDR
  String? getAMDRWarning() {
    if (isWithinAMDR()) return null;

    List<String> warnings = [];
    if (carbPercent < carbMinPercent || carbPercent > carbMaxPercent) {
      warnings.add(
          'Karbohidrat ${carbPercent.toStringAsFixed(1)}% (ideal: $carbMinPercent%-$carbMaxPercent%)');
    }
    if (proteinPercent < proteinMinPercent ||
        proteinPercent > proteinMaxPercent) {
      warnings.add(
          'Protein ${proteinPercent.toStringAsFixed(1)}% (ideal: $proteinMinPercent%-$proteinMaxPercent%)');
    }
    if (fatPercent < fatMinPercent || fatPercent > fatMaxPercent) {
      warnings.add(
          'Lemak ${fatPercent.toStringAsFixed(1)}% (ideal: $fatMinPercent%-$fatMaxPercent%)');
    }

    return 'Rasio di luar rekomendasi AMDR:\n' + warnings.join('\n');
  }

  // Calculate actual grams from calories
  Map<String, double> calculateGrams(int totalCalories) {
    double carbGrams =
        (totalCalories * carbPercent / 100) / 4; // 4 cal per gram carb
    double proteinGrams =
        (totalCalories * proteinPercent / 100) / 4; // 4 cal per gram protein
    double fatGrams =
        (totalCalories * fatPercent / 100) / 9; // 9 cal per gram fat

    return {
      'carbs': double.parse(carbGrams.toStringAsFixed(1)),
      'protein': double.parse(proteinGrams.toStringAsFixed(1)),
      'fat': double.parse(fatGrams.toStringAsFixed(1)),
    };
  }
}
