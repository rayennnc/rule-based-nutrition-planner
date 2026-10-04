import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_nutrisee/services/firestore_service.dart';
import 'package:final_project_nutrisee/widgets/meal_item_card.dart';

FoodItem _food({
  required String id,
  required String name,
  required int calories,
  num protein = 5,
  num carbs = 10,
  num fat = 2,
}) {
  return FoodItem(
    id: id,
    name: name,
    kategori: 'Buah',
    kondisi: 'Segar',
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('MealItemCard - render', () {
    testWidgets('TC-MIC-001: nampilin nama, berat default 100g, dan kalori',
        (tester) async {
      final food = _food(id: '1', name: 'Apel', calories: 52);

      await tester.pumpWidget(_wrap(
        MealItemCard(foodItem: food, category: 'Buah'),
      ));

      expect(find.text('Apel'), findsOneWidget);
      expect(find.text('100 gram'), findsOneWidget);
      expect(find.text('52 kkal'), findsOneWidget);
    });
  });

  group('MealItemCard - swap acak', () {
    testWidgets(
        'TC-MIC-002: swap acak ganti makanan & hitung ulang berat dengan bener',
        (tester) async {
      final current = _food(id: '1', name: 'Apel', calories: 200);
      final pengganti = _food(id: '2', name: 'Pisang', calories: 100);

      await tester.pumpWidget(_wrap(
        MealItemCard(
          foodItem: current,
          category: 'Buah',
          getFoodCandidatesOverride: (category, {excludeAllergens}) async =>
              [pengganti],
        ),
      ));

      await tester.tap(find.byTooltip('Ganti Acak'));
      await tester.pump(); // proses await getFoodCandidates
      await tester.pump(); // proses setState abis swap

      // Target kalori awal 200 (100g @ 200kkal). Pengganti 100kkal/100g,
      // jadi biar kalori tetep 200, beratnya harus jadi 200g.
      expect(find.text('Pisang'), findsOneWidget);
      expect(find.text('200 gram'), findsOneWidget);
    });

    testWidgets(
        'TC-MIC-003: kandidat 0 kalori nggak bikin crash (regresi fix isFinite/clamp)',
        (tester) async {
      final current = _food(id: '1', name: 'Apel', calories: 200);
      final kandidatAneh = _food(id: '2', name: 'Data Aneh', calories: 0);

      await tester.pumpWidget(_wrap(
        MealItemCard(
          foodItem: current,
          category: 'Buah',
          getFoodCandidatesOverride: (category, {excludeAllergens}) async =>
              [kandidatAneh],
        ),
      ));

      await tester.tap(find.byTooltip('Ganti Acak'));
      await tester.pump();
      await tester.pump();

      // Sebelum fix: 200/0*100 = Infinity, currentWeight.round() throw pas
      // render ulang. Sekarang: newWeightDouble.isFinite == false, fallback
      // ke 100.0 - harus render normal, nggak ada exception ke-capture.
      expect(tester.takeException(), isNull,
          reason: 'Harusnya nggak crash - kalori 0 harus fallback ke 100g, bukan Infinity');
      expect(find.text('Data Aneh'), findsOneWidget);
      expect(find.text('100 gram'), findsOneWidget);
    });
  });

  group('MealItemCard - mode selectable', () {
    testWidgets(
        'TC-MIC-004: mode selectable manggil onSelect, bukan buka detail sheet',
        (tester) async {
      final food = _food(id: '1', name: 'Apel', calories: 52);
      FoodItem? dipilih;

      await tester.pumpWidget(_wrap(
        MealItemCard(
          foodItem: food,
          category: 'Buah',
          selectable: true,
          onSelect: (item) => dipilih = item,
        ),
      ));

      await tester.tap(find.text('Apel'));
      await tester.pump();

      expect(dipilih?.id, equals('1'),
          reason: 'onSelect harus kepanggil dengan food yang lagi tampil');
      // Detail sheet (yang ada tombol "Tutup") harusnya TIDAK kebuka
      expect(find.text('Tutup'), findsNothing);
    });
  });
}