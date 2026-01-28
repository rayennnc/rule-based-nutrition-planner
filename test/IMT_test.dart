import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_nutrisee/services/calculator_service.dart';

void main() {
  group('Modul Perhitungan IMT', () {
    test('TC-IMT-001: 70kg,170cm -> IMT 24.2, Normal', () {
      print('[TEST START] TC-IMT-001: Hitung IMT Normal');
      final svc = CalculatorService(
        gender: Gender.male,
        height: 170,
        weight: 70,
        age: 25,
        activityLevel: ActivityLevel.sedentary,
      );
      final imt = svc.calculateBmi();

      print('Input: Berat 70kg, Tinggi 170cm');
      print('Output Harapan: 24.2 (Normal) | Output Aktual: $imt (${svc.getBmiCategory(imt)})');

      expect(imt, equals(24.2));
      expect(svc.getBmiCategory(imt).toLowerCase(), contains('normal'));
    });

    test('TC-IMT-002: Berat 0 -> throws ArgumentError', () {
      print('\n[TEST START] TC-IMT-002: Validasi Berat 0');
      final svc = CalculatorService(
        gender: Gender.female, 
        height: 170, 
        weight: 0, 
        age: 25, 
        activityLevel: ActivityLevel.sedentary);

      print('Input: Berat 0 kg');
      print('Harapan: Melempar ArgumentError');

      expect(() => svc.calculateBmi(), throwsA(isA<ArgumentError>()));
    });

    test('TC-IMT-003: Tinggi 300 -> throws ArgumentError', () {
      print('\n[TEST START] TC-IMT-003: Validasi Tinggi Ekstrem');
      final svc = CalculatorService(
        gender: Gender.male, 
        height: 300, 
        weight: 70, 
        age: 25, 
        activityLevel: ActivityLevel.sedentary);

      print('Input: Tinggi 300 cm');
      print('Harapan: Melempar ArgumentError');

      expect(() => svc.calculateBmi(), throwsA(isA<ArgumentError>()));
    });
  });
}