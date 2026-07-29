import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_nutrisee/services/firestore_service.dart';

void main() {
  group('Alergi dan pengecualian makanan', () {
    test(
        'FoodItem.matchesAllergens mengecualikan item yang mengandung kata kunci alergi',
        () {
      final item = FoodItem(
        id: '1',
        name: 'Sate Kacang Ayam',
        kategori: 'Daging',
        kondisi: 'Matang',
        calories: 250,
        protein: 20,
        carbs: 15,
        fat: 12,
      );

      expect(item.matchesAllergens(['kacang']), isTrue);
      expect(item.matchesAllergens(['susu']), isFalse);
      expect(item.matchesAllergens(['ayam']), isTrue);
    });

    test(
        'FoodItem.matchesAllergens tidak salah mengecualikan ikan dari kategori campuran jika alergi udang',
        () {
      final item = FoodItem(
        id: '3',
        name: 'Ikan Mujair',
        kategori: 'Ikan, Kerang, Udang',
        kondisi: 'Segar',
        calories: 120,
        protein: 20,
        carbs: 0,
        fat: 3,
      );

      expect(item.matchesAllergens(['udang']), isFalse);
      expect(item.matchesAllergens(['ikan']), isTrue);
    });

    test(
        'FoodItem.matchesAllergens benar mengecualikan udang dalam kategori campuran',
        () {
      final item = FoodItem(
        id: '4',
        name: 'Udang Rebus',
        kategori: 'Ikan, Kerang, Udang',
        kondisi: 'Matang',
        calories: 150,
        protein: 18,
        carbs: 0,
        fat: 4,
      );

      expect(item.matchesAllergens(['udang']), isTrue);
    });

    test('FoodItem.matchesAllergens tidak error saat daftar alergi kosong', () {
      final item = FoodItem(
        id: '2',
        name: 'Buah Apel',
        kategori: 'Buah',
        kondisi: 'Segar',
        calories: 52,
        protein: 0.3,
        carbs: 14,
        fat: 0.2,
      );

      expect(item.matchesAllergens([]), isFalse);
      expect(item.matchesAllergens(null), isFalse);
    });
  });
}
