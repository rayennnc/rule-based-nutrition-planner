import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_nutrisee/services/macro_nutrient.dart';

void main() {
  group('Modul Kustomisasi Makronutrien', () {
    test('TC-MAKRO-001: Rasio valid 50/25/25 -> total 100% & within AMDR', () {
      print('\n[TEST START] TC-MAKRO-001: Rasio Valid');
      final macro = MacroNutrient(
        carbPercent: 50,
        proteinPercent: 25,
        fatPercent: 25,
      );

      print('Input: C:50, P:25, F:25');
      print('Harapan: Valid Total (True) | Aktual: ${macro.isValidTotal()}');

      expect(macro.isValidTotal(), isTrue, reason: 'Total harus 100%');
      expect(macro.isWithinAMDR(), isTrue, reason: 'Rasio harus dalam AMDR');
      expect(macro.getAMDRWarning(), isNull, reason: 'Tidak boleh ada warning');
    });

    test('TC-MAKRO-002: Total != 100% -> error (60/30/20)', () {
      print('\n[TEST START] TC-MAKRO-002: Validasi Total > 100%');
      final macro = MacroNutrient(
        carbPercent: 60,
        proteinPercent: 30,
        fatPercent: 20,
      );

      print('Input: Total 110%');
      print('Harapan: Valid Total (False) | Aktual: ${macro.isValidTotal()}');

      expect(macro.isValidTotal(), isFalse, reason: 'Total 110% != 100%');
    });

    test('TC-MAKRO-003: Rasio di luar AMDR -> warning (30/40/30)', () {
      print('\n[TEST START] TC-MAKRO-003: Validasi Rentang AMDR');
      final macro = MacroNutrient(
        carbPercent: 30, // below 45% min
        proteinPercent: 40, // above 35% max
        fatPercent: 30,
      );

      print('Input: Karbo 30% (Rendah), Protein 40% (Tinggi)');
      
      expect(macro.isValidTotal(), isTrue, reason: 'Total tetap 100%');
      expect(macro.isWithinAMDR(), isFalse, reason: 'Rasio di luar AMDR');
      expect(macro.getAMDRWarning(), isNotNull, reason: 'Harus ada warning');
      expect(macro.getAMDRWarning(),
          stringContainsInOrder(['Karbohidrat', 'Protein']),
          reason: 'Warning harus sebut karbo & protein');
    });
  });
}
