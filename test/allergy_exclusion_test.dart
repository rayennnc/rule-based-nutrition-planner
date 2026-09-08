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

    test('FoodItem.matchesAllergens field alergen eksplisit dicek duluan',
        () {
      final item = FoodItem(
        id: '5',
        name: 'Sup Krim Ayam',
        kategori: 'Daging',
        kondisi: 'Matang',
        calories: 180,
        protein: 15,
        carbs: 5,
        fat: 8,
        alergen: const ['susu'],
      );

      expect(item.matchesAllergens(['susu']), isTrue,
          reason: 'Field alergen eksplisit cocok, harus match');
    });

    test(
        'FoodItem.matchesAllergens: kalau field alergen udah keisi, nama/kategori '
        'nggak dicek lagi - bisa "meleset" kalau field-nya nggak lengkap', () {
      // Nama-nya jelas nyebut "udang", tapi field alergen cuma nyebut susu.
      // Behavior sekarang: field eksplisit menang total begitu ada isinya,
      // fallback nama/kategori nggak pernah dijalanin lagi buat item ini.
      final item = FoodItem(
        id: '6',
        name: 'Udang Saus Mentega',
        kategori: 'Ikan, Kerang, Udang',
        kondisi: 'Matang',
        calories: 220,
        protein: 18,
        carbs: 4,
        fat: 14,
        alergen: const ['susu'], // field ada isi, tapi 'udang' nggak disebut
      );

      expect(item.matchesAllergens(['udang']), isFalse,
          reason: 'Field alergen eksplisit nggak nyebut udang, jadi nggak '
              'match - meski namanya jelas mengandung udang. Ini konfirmasi '
              'perilaku "field eksplisit menang total", bukan bug.');
      expect(item.matchesAllergens(['susu']), isTrue,
          reason: 'Tapi buat susu (yang emang ada di field), tetep match');
    });
  });
}