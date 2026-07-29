class MacroNutrient {
  final double carbPercent;
  final double proteinPercent;
  final double fatPercent;

  const MacroNutrient({
    required this.carbPercent,
    required this.proteinPercent,
    required this.fatPercent,
  });

  // 1. Balanced Diet (Gizi Seimbang - Mode Default)

  static const MacroNutrient balanced = MacroNutrient(
    carbPercent: 60.0,
    fatPercent: 25.0,
    proteinPercent: 15.0,
  );

  // 2. Performance (Untuk Atlet/Active Users)
  static const MacroNutrient performance = MacroNutrient(
    carbPercent: 50.0,
    fatPercent: 20.0,
    proteinPercent: 30.0,
  );

  // 3. Low Fat (Opsional - Pencegahan Obesitas)
  static const MacroNutrient lowFat = MacroNutrient(
    carbPercent: 70.0,
    fatPercent: 15.0,
    proteinPercent: 15.0,
  );

  // 2. CONSTANTS FOR VALIDATION (Sintesis AMDR & WHO)
  // Digunakan untuk validasi jika user memilih "Custom Ratio"
  // Range disesuaikan agar mencakup WHO & AMDR (Wide Safe Range)

  static const double carbMinPercent = 45.0;
  static const double carbMaxPercent = 75.0; // WHO max up to 75%

  static const double proteinMinPercent = 10.0;
  static const double proteinMaxPercent = 35.0; // AMDR max

  static const double fatMinPercent = 15.0; // WHO min (sebelumnya 20 di AMDR)
  static const double fatMaxPercent = 35.0; // AMDR max

  // 3. METHODS

  // Validate total = 100%
  bool isValidTotal() {
    double total = carbPercent + proteinPercent + fatPercent;
    return (total - 100.0).abs() < 0.1; // allow 0.1% tolerance
  }

  // Check if within Safe Limits (WHO/AMDR)
  bool isWithinAMDR() {
    bool carbOk =
        carbPercent >= carbMinPercent && carbPercent <= carbMaxPercent;
    bool proteinOk = proteinPercent >= proteinMinPercent &&
        proteinPercent <= proteinMaxPercent;
    bool fatOk = fatPercent >= fatMinPercent && fatPercent <= fatMaxPercent;
    return carbOk && proteinOk && fatOk;
  }

  // Get warning message if outside recommendations
  String? getAMDRWarning() {
    if (isWithinAMDR()) return null;

    List<String> warnings = [];
    if (carbPercent < carbMinPercent || carbPercent > carbMaxPercent) {
      warnings.add(
          'Karbohidrat ${carbPercent.toStringAsFixed(1)}% (Aman: $carbMinPercent%-$carbMaxPercent%)');
    }
    if (proteinPercent < proteinMinPercent ||
        proteinPercent > proteinMaxPercent) {
      warnings.add(
          'Protein ${proteinPercent.toStringAsFixed(1)}% (Aman: $proteinMinPercent%-$proteinMaxPercent%)');
    }
    if (fatPercent < fatMinPercent || fatPercent > fatMaxPercent) {
      warnings.add(
          'Lemak ${fatPercent.toStringAsFixed(1)}% (Aman: $fatMinPercent%-$fatMaxPercent%)');
    }

    return 'Rasio di luar rekomendasi standar:\n' + warnings.join('\n');
  }

  // Calculate actual grams from calories
  Map<String, double> calculateGrams(int totalCalories) {
    // Rumus: (Total Kalori * Persen / 100) / Kalori per gram
    // Karbo & Protein = 4 kal/gram
    // Lemak = 9 kal/gram

    double carbGrams = (totalCalories * carbPercent / 100) / 4;
    double proteinGrams = (totalCalories * proteinPercent / 100) / 4;
    double fatGrams = (totalCalories * fatPercent / 100) / 9;

    return {
      'carbs': double.parse(carbGrams.toStringAsFixed(1)),
      'protein': double.parse(proteinGrams.toStringAsFixed(1)),
      'fat': double.parse(fatGrams.toStringAsFixed(1)),
    };
  }
}
