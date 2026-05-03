enum Gender { male, female }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum DietGoal { lose, maintain, gain }

class CalculatorService {
  final Gender gender;
  final double height; // in cm
  final double weight; // in kg
  final int age;
  final ActivityLevel? activityLevel;

  CalculatorService({
    required this.gender,
    required this.height,
    required this.weight,
    required this.age,
    this.activityLevel,
  });

  // Validate inputs
  void _validateWeight() {
    if (weight <= 0) {
      throw ArgumentError('Berat badan harus lebih dari 0 kg');
    }
  }

  void _validateHeight() {
    if (height < 50 || height > 250) {
      throw ArgumentError('Tinggi badan tidak valid (50–250 cm)');
    }
  }

  void _validateAge() {
    if (age < 18 || age > 75) {
      throw ArgumentError('Aplikasi hanya untuk usia 18–75 tahun');
    }
  }

  // Calculate BMI based on formula
  double calculateBmi() {
    _validateWeight();
    _validateHeight();

    double heightInMeters = height / 100;
    double bmi = weight / (heightInMeters * heightInMeters);
    return double.parse(bmi.toStringAsFixed(1));
  }

  // Get BMI Category based on WHO classification
  String getBmiCategory(double bmi) {
    if (bmi < 18.5) return "Underweight";
    if (bmi >= 18.5 && bmi <= 22.9) return "Normal";
    if (bmi >= 23.0 && bmi <= 24.9) return "Overweight";
    if (bmi >= 25.0 && bmi <= 29.9) return "Obesitas 1";
    return "Obesitas 2";
  }

  // Calculate BMR using Mifflin-St Jeor Equation
  double calculateBmr() {
    _validateWeight();
    _validateHeight();
    _validateAge();

    // Pria = 10 * berat(kg) + 6.25 * tinggi(cm) - 5 * umur(tahun) + 5
    // Wanita = 10 * berat(kg) + 6.25 * tinggi(cm) - 5 * umur(tahun) - 161
    if (gender == Gender.male) {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
  }

  // Calculate TDEE based on BMR and activity level
  // Accept nullable activity parameter to allow test of "tidak memilih aktivitas"
  int calculateTdee([ActivityLevel? level]) {
    final ActivityLevel? lvl = level ?? activityLevel;
    if (lvl == null) {
      throw ArgumentError('Silakan pilih level aktivitas');
    }

    double bmr = calculateBmr();
    double multiplier = 1.2; // Default to Sedentary

    switch (lvl) {
      case ActivityLevel.sedentary:
        multiplier = 1.2;
        break;
      case ActivityLevel.light:
        multiplier = 1.375;
        break;
      case ActivityLevel.moderate:
        multiplier = 1.55;
        break;
      case ActivityLevel.active:
        multiplier = 1.725;
        break;
      case ActivityLevel.veryActive:
        multiplier = 1.9;
        break;
      default:
        multiplier = 1.2;
    }
    return (bmr * multiplier).round();
  }

  // Adjust calories based on diet goal
  int getAdjustedCalories(DietGoal goal, int tdee) {
    switch (goal) {
      case DietGoal.lose:
        return tdee -
            500; // Defisit 500 kalori kata ahli gizi di rumah sakit prof kandou Manado
      case DietGoal.maintain:
        return tdee;
      case DietGoal.gain:
        return tdee +
            500; // Surplus 500 kalori kata ahli gizi di rumah sakit prof kandou Manado
    }
  }

  // ===== SNACK ALLOCATION (Cemilan) =====
  // Based on research (Bermingham et al., 2024): 20% of daily calories allocated to snacks
  // Split: 10% morning snack (10:00 AM), 10% afternoon snack (4:00 PM)
  // Purpose: appetite control & blood glucose stability through high-protein snacking

  /// Calculate snack calorie allocation from TDEE
  /// Returns map with morning and afternoon snack targets (in calories)
  Map<String, int> calculateSnackAllocation(int tdee) {
    // Morning and afternoon snack shown as 10% each (rounded)
    final int morningSnackCal = (tdee * 0.10).round();
    final int afternoonSnackCal = (tdee * 0.10).round();

    // Total snack reported as 20% (rounded). Note: due to rounding
    // morning+afternoon may differ from this total by ±1.
    final int totalSnackCal = (tdee * 0.20).round();

    return {
      'morningSnack': morningSnackCal,
      'afternoonSnack': afternoonSnackCal,
      'totalSnackCal': totalSnackCal,
    };
  }

  /// Get recommended macronutrient ratios for high-protein snacks
  ///
  /// Research insight (Almoraie et al., 2021):
  /// - High-protein snacks provide superior satiety vs carb/fat-dominant snacks
  /// - Helps control appetite & reduce empty calorie consumption
  /// - Improves snack diet quality (SDI - Snack Diet Index)
  ///
  /// Recommended ratio for snacks (vs typical snacking behavior):
  /// - Protein: 35% (vs current pattern: 10%) ← EMPHASIS
  /// - Carbs: 45% (vs current pattern: 58%)
  /// - Fat: 20% (vs current pattern: 32%)
  Map<String, double> getSnackMacroRatios() {
    return {
      'proteinPercent': 35.0, // High-protein for satiety
      'carbPercent': 45.0, // Moderate carbs
      'fatPercent': 20.0, // Lower fat
    };
  }
}
