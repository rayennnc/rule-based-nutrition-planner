import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_nutrisee/services/calculator_service.dart';

void main() {
  group('Modul BMR / TDEE', () {
    test('TC-BMR-001: BMR pria 70/170/25 -> ~1642.5', () {
    print('\n[TEST START] TC-BMR-001: Hitung BMR Pria');
      final svc = CalculatorService(
        gender: Gender.male, 
        height: 170, 
        weight: 70, 
        age: 25, 
        activityLevel: ActivityLevel.sedentary);
      final bmr = svc.calculateBmr();

      print('Input: Pria, 70kg, 170cm, 25th');
      print('Output Harapan: ~1642.5 | Output Aktual: $bmr');

      expect(bmr, closeTo(1642.5, 0.1),
        reason: 'BMR harus mendekati 1642.5');
    });

    test('TC-BMR-002: usia 16 -> throws ArgumentError', () {
      print('\n[TEST START] TC-BMR-002: Validasi Usia (Boundary)');
      final svc = CalculatorService(
        gender: Gender.male, 
        height: 170, 
        weight: 70, 
        age: 16, 
        activityLevel: ActivityLevel.sedentary);

      print('Input: Usia 16 tahun (di bawah batas 18)');
      print('Harapan: Melempar ArgumentError');

      expect(() => svc.calculateBmr(), throwsA(isA<ArgumentError>()),
        reason: 'Usia di bawah 18 harus melempar ArgumentError');
    });

    test('TC-TDEE-001: TDEE dari BMR 1642.5 dengan Sedentary -> 1971', () {
      print('\n[TEST START] TC-TDEE-001: Hitung TDEE Sedentary');
      final svc = CalculatorService(
        gender: Gender.male, 
        height: 170, 
        weight: 70, 
        age: 25, 
        activityLevel: ActivityLevel.sedentary);
      final tdee = svc.calculateTdee(ActivityLevel.sedentary);

      print('Input: BMR (Implisit), Aktivitas Sedentary (x1.2)');
      print('Output Harapan: 1971 | Output Aktual: $tdee');

      expect(tdee, equals(1971),
        reason: 'TDEE = BMR * 1.2');
    });

    test('TC-TDEE-002: tidak memilih aktivitas -> throws ArgumentError', () {
      print('\n[TEST START] TC-TDEE-002: Validasi Aktivitas Kosong');
      final svc = CalculatorService(
        gender: Gender.male, 
        height: 170, 
        weight: 70, 
        age: 25,
      );

      print('Input: Aktivitas kosong (null)');
      print('Harapan: Melempar ArgumentError "Silakan pilih level aktivitas"');

      expect(
    () => svc.calculateTdee(),  
    throwsA(isA<ArgumentError>().having(
      (e) => e.message,
      'message',
      contains('pilih'),
    )),
    reason: 'Aktivitas tidak boleh null');
    });
  });
}