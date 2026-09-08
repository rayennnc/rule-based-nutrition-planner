import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_nutrisee/services/firestore_service.dart';

// Semua test di sini manggil filterSnackRecommendations/filterHighQualitySnacks
// langsung (bukan getSnackRecommendations/getHighQualitySnacks yang butuh
// Firestore) - itu kenapa nggak perlu Firebase.initializeApp() sama sekali.

FoodItem _food({
  required String id,
  required String name,
  required int calories,
  required num protein,
  required num carbs,
  required num fat,
  String kategori = 'Buah',
  List<String> alergen = const [],
}) {
  return FoodItem(
    id: id,
    name: name,
    kategori: kategori,
    kondisi: 'Segar',
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    alergen: alergen,
  );
}

void main() {
  group('filterSnackRecommendations - prioritas kalori vs makro', () {
    test(
        'TC-SNACKREC-001: match kalori persis menang, walau makronya jelek, '
        'dibanding kandidat kalori dikit meleset tapi makronya bagus', () {
      final kaloriPasMakroJelek = _food(
          id: 'a', name: 'Snack A', calories: 100, protein: 0, carbs: 25, fat: 0);
      final kaloriMelesetMakroBagus = _food(
          id: 'b', name: 'Snack B', calories: 110, protein: 9.6, carbs: 12.4, fat: 2.4);

      final result = filterSnackRecommendations(
        [kaloriPasMakroJelek, kaloriMelesetMakroBagus],
        100,
      );

      print('\n[TEST START] TC-SNACKREC-001');
      print('Harapan: Snack A (kalori pas) menang meski makronya 100% karbo');
      print('Aktual: item pertama = ${result.first.name}');

      expect(result.first.id, equals('a'),
          reason: 'Exact-calorie match harus menang, macro belum sempat '
              'dipertimbangkan sama sekali di tier ini');
    });

    test(
        'TC-SNACKREC-002: kalau kalorinya SAMA PERSIS di beberapa kandidat, '
        'baru makro yang jadi penentu', () {
      final makroJelek = _food(
          id: 'c', name: 'Snack C', calories: 100, protein: 0, carbs: 25, fat: 0);
      final makroBagus = _food(
          id: 'd', name: 'Snack D', calories: 100, protein: 8.75, carbs: 11.25, fat: 2.22);

      final result = filterSnackRecommendations(
        [makroJelek, makroBagus],
        100,
      );

      print('\n[TEST START] TC-SNACKREC-002');
      print('Harapan: Snack D (makro 35/45/20 pas target) menang, kalorinya sama-sama pas');
      print('Aktual: item pertama = ${result.first.name}');

      expect(result.first.id, equals('d'),
          reason: 'Kalori seri (0 vs 0), jadi macro error yang nentuin urutan');
    });
  });

  group('filterSnackRecommendations - alergen', () {
    test('TC-SNACKREC-003: item dengan alergen yang di-exclude tidak ikut muncul', () {
      final amanKacang = _food(
          id: 'e', name: 'Buah Aman', calories: 100, protein: 5, carbs: 20, fat: 2);
      final adaKacang = _food(
        id: 'f',
        name: 'Camilan Kacang',
        calories: 100,
        protein: 5,
        carbs: 20,
        fat: 2,
        alergen: const ['kacang'],
      );

      final result = filterSnackRecommendations(
        [amanKacang, adaKacang],
        100,
        excludeAllergens: const ['kacang'],
      );

      print('\n[TEST START] TC-SNACKREC-003');
      print('Harapan: cuma "Buah Aman" yang muncul, "Camilan Kacang" ke-exclude');
      print('Aktual: ${result.map((f) => f.name).toList()}');

      expect(result.any((f) => f.id == 'f'), isFalse,
          reason: 'Item beralergen kacang harus ke-exclude');
      expect(result.any((f) => f.id == 'e'), isTrue,
          reason: 'Item aman harus tetap muncul');
    });
  });

  group('filterHighQualitySnacks - fallback', () {
    test('TC-SNACKREC-004: nggak ada match persis -> fallback ke toleransi ±15%', () {
      final dekat = _food(
          id: 'g', name: 'Snack Dekat', calories: 108, protein: 3, carbs: 15, fat: 1);
      final jauh = _food(
          id: 'h', name: 'Snack Jauh', calories: 200, protein: 3, carbs: 15, fat: 1);

      final result = filterHighQualitySnacks([dekat, jauh], 100);

      print('\n[TEST START] TC-SNACKREC-004');
      print('Target 100 kcal, toleransi 15 -> cuma "Snack Dekat" (108) yang masuk');
      print('Aktual: ${result.map((f) => f.name).toList()}');

      expect(result.length, equals(1));
      expect(result.first.id, equals('g'));
    });
  });
}