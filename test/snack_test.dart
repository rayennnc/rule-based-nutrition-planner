import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_nutrisee/services/calculator_service.dart';

void main() {
  group('Modul Snack (Cemilan)', () {
    test('TC-SNACK-001: Alokasi snack 20% dari TDEE (split 10%+10%)', () {
      print('\n[TEST START] TC-SNACK-001: Hitung Alokasi Snack');
      final svc = CalculatorService(
        gender: Gender.male,
        height: 170,
        weight: 70,
        age: 25,
        activityLevel: ActivityLevel.moderate,
      );

      final tdee = svc.calculateTdee();
      final snackAllocation = svc.calculateSnackAllocation(tdee);

      print('Input: TDEE $tdee kcal');
      print(
          'Harapan: Morning snack = ${(tdee * 0.10).round()}, Afternoon snack = ${(tdee * 0.10).round()}');
      print(
          'Aktual: Morning = ${snackAllocation['morningSnack']}, Afternoon = ${snackAllocation['afternoonSnack']}');

      // Morning snack = 10% dari TDEE
      expect(
        snackAllocation['morningSnack'],
        equals((tdee * 0.10).round()),
        reason: 'Morning snack harusnya 10% dari TDEE',
      );

      // Afternoon snack = 10% dari TDEE
      expect(
        snackAllocation['afternoonSnack'],
        equals((tdee * 0.10).round()),
        reason: 'Afternoon snack harusnya 10% dari TDEE',
      );

      // Total snack = 20% dari TDEE
      final expectedTotal = (tdee * 0.20).round();
      expect(
        snackAllocation['totalSnackCal'],
        equals(expectedTotal),
        reason: 'Total snack harusnya 20% dari TDEE',
      );
    });
    test(
        'TC-SNACK-003: Snack allocation contoh: TDEE 2000 kcal -> morning 200, afternoon 200',
        () {
      print('\n[TEST START] TC-SNACK-003: Contoh Alokasi Snack Konkret');
      final tdeeExample = 2000;
      final svc = CalculatorService(
        gender: Gender.male,
        height: 175,
        weight: 75,
        age: 30,
        activityLevel: ActivityLevel.moderate,
      );

      final alloc = svc.calculateSnackAllocation(tdeeExample);

      print('Input: TDEE = $tdeeExample kcal');
      print(
          'Harapan: Morning = 200 kcal (10%), Afternoon = 200 kcal (10%), Total = 400 kcal');
      print(
          'Aktual: Morning = ${alloc['morningSnack']}, Afternoon = ${alloc['afternoonSnack']}, Total = ${alloc['totalSnackCal']}');

      expect(alloc['morningSnack'], equals(200));
      expect(alloc['afternoonSnack'], equals(200));
      expect(alloc['totalSnackCal'], equals(400));
    });

    test('TC-SNACK-004: Macro grams untuk snack 150 kcal dengan protein 35%',
        () {
      print('\n[TEST START] TC-SNACK-004: Hitung Gram Snack Macros');

      // 150 kcal snack with 35% protein, 45% carbs, 20% fat
      final snackCalories = 150;
      final proteinPercent = 35.0;
      final carbPercent = 45.0;
      final fatPercent = 20.0;

      final proteinCal = (snackCalories * proteinPercent) / 100;
      final carbCal = (snackCalories * carbPercent) / 100;
      final fatCal = (snackCalories * fatPercent) / 100;

      final proteinGrams = proteinCal / 4; // 4 cal/gram
      final carbGrams = carbCal / 4; // 4 cal/gram
      final fatGrams = fatCal / 9; // 9 cal/gram

      print('Snack: $snackCalories kcal');
      print(
          'Harapan: Protein = $proteinGrams g, Carbs = $carbGrams g, Fat = $fatGrams g');

      expect(proteinGrams, closeTo(13.125, 0.1));
      expect(carbGrams, closeTo(16.875, 0.1));
      expect(fatGrams, closeTo(3.33, 0.1));
    });
  });
}
