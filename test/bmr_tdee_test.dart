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

    test('TC-BMR-003: BMR wanita 70/170/25 -> ~1476.5', () {
      print('\n[TEST START] TC-BMR-003: Hitung BMR Wanita');
      final svc = CalculatorService(
        gender: Gender.female,
        height: 170,
        weight: 70,
        age: 25,
        activityLevel: ActivityLevel.sedentary);
      final bmr = svc.calculateBmr();

      print('Input: Wanita, 70kg, 170cm, 25th');
      print('Output Harapan: ~1476.5 | Output Aktual: $bmr');

      expect(bmr, closeTo(1476.5, 0.1),
        reason: 'BMR wanita pakai -161, bukan +5 kayak pria (selisih 166 dari TC-BMR-001)');
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

  group('Modul Penyesuaian Kalori (Diet Goal)', () {
    test('TC-GOAL-001: goal lose -> TDEE dikurangi 500', () {
      final svc = CalculatorService(gender: Gender.male, height: 170, weight: 70, age: 25);
      final result = svc.getAdjustedCalories(DietGoal.lose, 2000);

      print('\n[TEST START] TC-GOAL-001: Goal Lose');
      print('Input: TDEE 2000, goal lose | Harapan: 1500 | Aktual: $result');

      expect(result, equals(1500), reason: 'Goal lose harus TDEE - 500');
    });

    test('TC-GOAL-002: goal maintain -> TDEE tetap', () {
      final svc = CalculatorService(gender: Gender.male, height: 170, weight: 70, age: 25);
      final result = svc.getAdjustedCalories(DietGoal.maintain, 2000);

      print('\n[TEST START] TC-GOAL-002: Goal Maintain');
      print('Input: TDEE 2000, goal maintain | Harapan: 2000 | Aktual: $result');

      expect(result, equals(2000), reason: 'Goal maintain harus sama kayak TDEE');
    });

    test('TC-GOAL-003: goal gain -> TDEE ditambah 500', () {
      final svc = CalculatorService(gender: Gender.male, height: 170, weight: 70, age: 25);
      final result = svc.getAdjustedCalories(DietGoal.gain, 2000);

      print('\n[TEST START] TC-GOAL-003: Goal Gain');
      print('Input: TDEE 2000, goal gain | Harapan: 2500 | Aktual: $result');

      expect(result, equals(2500), reason: 'Goal gain harus TDEE + 500');
    });
  });

  group('Modul Perhitungan Umur', () {
    // Pakai tanggal RELATIF ke hari ini (bukan hardcode), biar test ini
    // tetap valid kapanpun dijalankan, bukan cuma hari ini doang.
    test('TC-UMUR-001: ulang tahun belum lewat tahun ini -> umur dikurangi 1', () {
      final now = DateTime.now();
      final besok = now.add(const Duration(days: 1));
      final tanggalLahir = DateTime(now.year - 25, besok.month, besok.day);

      final umur = CalculatorService.hitungUmurDariTanggalLahir(tanggalLahir);

      print('\n[TEST START] TC-UMUR-001: Ulang Tahun Belum Lewat');
      print('Lahir 25 tahun lalu, tanggal ultah = besok ($besok)');
      print('Harapan: 24 | Aktual: $umur');

      expect(umur, equals(24),
        reason: 'Belum ulang tahun tahun ini, umur harus 24 bukan 25');
    });

    test('TC-UMUR-002: ulang tahun sudah lewat tahun ini -> umur pas', () {
      final now = DateTime.now();
      final kemarin = now.subtract(const Duration(days: 1));
      final tanggalLahir = DateTime(now.year - 25, kemarin.month, kemarin.day);

      final umur = CalculatorService.hitungUmurDariTanggalLahir(tanggalLahir);

      print('\n[TEST START] TC-UMUR-002: Ulang Tahun Sudah Lewat');
      print('Lahir 25 tahun lalu, tanggal ultah = kemarin ($kemarin)');
      print('Harapan: 25 | Aktual: $umur');

      expect(umur, equals(25),
        reason: 'Udah ulang tahun tahun ini, umur pas 25');
    });
  });
}