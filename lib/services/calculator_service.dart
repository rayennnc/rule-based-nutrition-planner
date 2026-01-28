import 'dart:math';

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
    if (bmi >= 18.5 && bmi <= 24.9) return "Normal";
    if (bmi >= 25.0 && bmi <= 29.9) return "Overweight";
    return "Obese";
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
        return tdee - 500; // Defisit 500 kalori kata ahli gizi di rumah sakit prof kandou Manado
      case DietGoal.maintain:
        return tdee;
      case DietGoal.gain:
        return tdee + 500; // Surplus 500 kalori kata ahli gizi di rumah sakit prof kandou Manado
    }
  }
}
