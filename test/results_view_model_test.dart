import 'dart:async';

import 'package:final_project_nutrisee/auth/auth_service.dart';
import 'package:final_project_nutrisee/services/calculator_service.dart';
import 'package:final_project_nutrisee/services/firestore_service.dart';
import 'package:final_project_nutrisee/services/local_storage_service.dart';
import 'package:final_project_nutrisee/services/macro_nutrient.dart';
import 'package:final_project_nutrisee/view_models/results_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

// Judul section harus sama persis dengan yang dipakai di ViewModel.
const sarapan = 'Sarapan (06.00 - 09.00 Pagi)';
const camilanPagi = 'Camilan Pagi (10.00 Pagi)';

// Fake FirestoreService. Yang diisi cuma method yang dipakai ViewModel,
// panggilan lain bakal lempar UnimplementedError (bawaan Fake).
class FakeFirestoreService extends Fake implements FirestoreService {
  // data yang dikembalikan
  Map<String, dynamic>? dailyMenu;
  Map<String, dynamic>? lastMeasurement;
  MacroNutrient? remoteMacro;
  List<FoodItem> mealItems = [];
  List<FoodItem> snackItems = [];
  List<FoodItem> parsedItems = [];
  List<FoodItem> allFoods = [];

  // kalau diisi, generateMealPlan baru selesai setelah completer ini selesai
  Completer<List<FoodItem>>? mealGate;

  // catatan panggilan
  final List<Map<String, dynamic>> mealCalls = [];
  final List<List<String>?> snackAllergens = [];
  int measurementSaves = 0;
  int cacheClears = 0;

  @override
  Future<List<FoodItem>> generateMealPlan(
    int targetCalories, {
    Map<String, double>? ratios,
    List<String>? excludeAllergens,
  }) {
    mealCalls.add({
      'target': targetCalories,
      'ratios': ratios,
      'allergens':
          excludeAllergens == null ? null : List<String>.of(excludeAllergens),
    });
    return mealGate?.future ?? Future.value(mealItems);
  }

  @override
  Future<List<FoodItem>> getSnackRecommendations(
    int targetCalories, {
    MacroNutrient? macroPrefs,
    int? dailyTargetCal,
    double? dailyTargetCarbs,
    double? dailyTargetProtein,
    double? dailyTargetFat,
    Map<String, double>? macrosEaten,
    List<String>? excludeAllergens,
  }) {
    snackAllergens.add(
        excludeAllergens == null ? null : List<String>.of(excludeAllergens));
    return Future.value(snackItems);
  }

  @override
  Future<void> saveSectionMenu({
    required String uid,
    required String section,
    required List<FoodItem> items,
    required String goal,
    required int tdee,
  }) async {}

  @override
  Future<void> saveMeasurement({
    required String uid,
    required double weight,
    required double bmi,
    required int tdee,
    required String goal,
  }) async {
    measurementSaves++;
  }

  @override
  Future<Map<String, dynamic>?> loadDailyMenu(String uid) async => dailyMenu;

  @override
  Future<Map<String, dynamic>?> loadLastMeasurement(String uid) async =>
      lastMeasurement;

  @override
  Future<MacroNutrient?> loadMacroPreferences(String uid) async => remoteMacro;

  @override
  List<FoodItem> parseFoodItems(dynamic data) => parsedItems;

  @override
  Future<List<FoodItem>> getAllFoodItems() async => allFoods;

  @override
  void clearCache() {
    cacheClears++;
  }
}

// Fake LocalStorageService. Dibuat lewat noSuchMethod supaya tidak
// tergantung signature aslinya.
class FakeLocalStorageService extends Fake implements LocalStorageService {
  FakeLocalStorageService(this.log);

  final List<String> log;
  String allergies = '';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #loadDataUser:
        return Future.value(<String, String>{'alergi': allergies});
      case #loadMacroPreferencesLocal:
        return Future.value(null);
      case #saveMacroPreferencesLocal:
        return Future<void>.value();
      case #hapusDataUser:
        log.add('hapusDataUser');
        return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeAuthService extends Fake implements AuthService {
  FakeAuthService(this.log);

  final List<String> log;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #signOut) {
      log.add('signOut');
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

FoodItem food(
  String id, {
  int calories = 100,
  num protein = 10,
  num carbs = 10,
  num fat = 5,
  List<String> alergen = const [],
}) {
  return FoodItem(
    id: id,
    name: 'Makanan $id',
    kategori: 'Test',
    kondisi: 'Test',
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    alergen: alergen,
  );
}

// ratios yang dikirim ke generateMealPlan berbentuk pecahan (0-1).
void expectRatios(Object? ratios,
    {required double carbs, required double protein, required double fat}) {
  final r = ratios as Map<String, double>;
  expect(r['carbs'], closeTo(carbs, 1e-9));
  expect(r['protein'], closeTo(protein, 1e-9));
  expect(r['fat'], closeTo(fat, 1e-9));
}

void main() {
  late FakeFirestoreService firestore;
  late FakeLocalStorageService storage;
  late FakeAuthService auth;
  late List<String> log;
  late ResultsViewModel vm;
  String? uid;

  // Pria 70 kg, 170 cm, 25 th, sedentary -> BMR 1642.5, TDEE 1971
  ResultsViewModel makeVm() {
    return ResultsViewModel(
      calculator: CalculatorService(
        gender: Gender.male,
        height: 170,
        weight: 70,
        age: 25,
        activityLevel: ActivityLevel.sedentary,
      ),
      firestoreService: firestore,
      storageService: storage,
      authService: auth,
      getUid: () => uid,
    );
  }

  // Kasih waktu supaya future yang sudah selesai menjalankan callback-nya.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    log = [];
    uid = 'user-1';
    firestore = FakeFirestoreService()
      ..mealItems = [food('m1'), food('m2')]
      ..snackItems = [food('s1', calories: 150)];
    storage = FakeLocalStorageService(log);
    auth = FakeAuthService(log);
    vm = makeVm();
    addTearDown(vm.dispose);
  });

  group('ResultsViewModel - data awal', () {
    test('TC-RVM-001: nilai awal dihitung dari calculator', () {
      expect(vm.bmi, 24.2);
      expect(vm.bmiCategory, 'Overweight');
      expect(vm.bmr, 1642.5);
      expect(vm.tdee, 1971);
      expect(vm.baseCalories, 1971);
      expect(vm.selectedGoal, isNull);
    });

    test('TC-RVM-002: tujuan dan menu hari ini dipulihkan dari Firestore',
        () async {
      firestore.dailyMenu = {
        'tdee': 1971,
        'goal': 'lose',
        sarapan: ['data mentah'],
      };
      firestore.parsedItems = [food('cached')];

      vm.init();
      await settle();

      expect(vm.selectedGoal, DietGoal.lose);
      expect(vm.finalCalories, 1471); // 1971 - 500
      final cached = await vm.mealFuture(sarapan, 394);
      expect(cached.single.id, 'cached');
      // sarapan sudah ada di cache, jadi cuma 2 section lain yang di-generate
      expect(firestore.mealCalls.length, 2);
    });

    test('TC-RVM-003: menu tersimpan dengan TDEE beda diabaikan', () async {
      firestore.dailyMenu = {
        'tdee': 9999,
        'goal': 'lose',
        sarapan: ['data mentah'],
      };
      firestore.parsedItems = [food('cached')];

      vm.init();
      await settle();

      expect(vm.selectedGoal, isNull);
      expect(vm.baseCalories, 1971);
      expect(firestore.mealCalls.length, 3); // semua di-generate ulang
    });

    test('TC-RVM-004: menu tersimpan yang kena alergi diabaikan', () async {
      storage.allergies = 'telur';
      firestore.dailyMenu = {
        'tdee': 1971,
        'goal': 'maintain',
        sarapan: ['data mentah'],
      };
      firestore.parsedItems = [
        food('telur-dadar', alergen: ['telur']),
      ];

      vm.init();
      await settle();

      // tujuan tetap dipulihkan, tapi menu lama dibuang dan di-generate ulang
      expect(vm.selectedGoal, DietGoal.maintain);
      expect(firestore.mealCalls.length, 3);
      final cached = await vm.mealFuture(sarapan, 394);
      expect(cached.map((f) => f.id), ['m1', 'm2']);
    });

    test('TC-RVM-005: tanpa uid, Firestore tidak dipanggil dan loading selesai',
        () async {
      uid = null;

      vm.init();
      await settle();

      expect(vm.loadingLastMeasurement, isFalse);
      expect(firestore.mealCalls, isEmpty);
      expect(firestore.snackAllergens, isEmpty);
    });

    test('TC-RVM-006: pengukuran terakhir dimuat dari Firestore', () async {
      firestore.lastMeasurement = {'weight': 70};

      vm.init();
      await settle();

      expect(vm.lastMeasurement, {'weight': 70});
      expect(vm.loadingLastMeasurement, isFalse);
    });
  });

  group('ResultsViewModel - cache menu', () {
    test('TC-RVM-007: mealFuture dipakai ulang per section', () {
      final f1 = vm.mealFuture('A', 400);
      final f2 = vm.mealFuture('A', 400);
      expect(identical(f1, f2), isTrue);
      expect(firestore.mealCalls.length, 1);

      vm.mealFuture('B', 400);
      expect(firestore.mealCalls.length, 2);
    });

    test('TC-RVM-008: refreshMeal membuat future baru', () {
      final f1 = vm.mealFuture('A', 400);
      vm.refreshMeal('A', 400);
      final f2 = vm.mealFuture('A', 400);

      expect(identical(f1, f2), isFalse);
      expect(firestore.mealCalls.length, 2);
    });

    test('TC-RVM-009: setDietGoal membersihkan cache lama dan siapkan menu baru',
        () async {
      vm.mealFuture('A', 400);
      expect(firestore.mealCalls.length, 1);

      vm.setDietGoal(DietGoal.maintain);
      await settle();

      expect(vm.selectedGoal, DietGoal.maintain);
      expect(vm.finalCalories, 1971);
      // 1 panggilan tadi + 3 menu utama yang disiapkan, snack 2
      expect(firestore.mealCalls.length, 4);
      expect(firestore.snackAllergens.length, 2);
      expect(firestore.measurementSaves, 1);

      // cache section 'A' sudah dibersihkan, jadi di-generate lagi
      vm.mealFuture('A', 400);
      expect(firestore.mealCalls.length, 5);
    });

    test('TC-RVM-010: resetGoal mengosongkan tujuan dan cache', () async {
      vm.setDietGoal(DietGoal.lose);
      await settle();
      expect(vm.finalCalories, 1471);

      vm.resetGoal();

      expect(vm.selectedGoal, isNull);
      expect(vm.finalCalories, isNull);
      expect(vm.baseCalories, 1971);
      final before = firestore.mealCalls.length;
      vm.mealFuture(sarapan, 394);
      expect(firestore.mealCalls.length, before + 1);
    });

    test('TC-RVM-011: applyMacro membersihkan cache dan pakai rasio baru',
        () async {
      vm.applyMacro(
        MacroNutrient(carbPercent: 40, proteinPercent: 35, fatPercent: 25),
      );
      await settle();

      expect(firestore.mealCalls.length, 3);
      for (final call in firestore.mealCalls) {
        expectRatios(call['ratios'], carbs: 0.40, protein: 0.35, fat: 0.25);
      }
      expect(vm.effectiveMacro?.proteinPercent, 35);
    });
  });

  group('ResultsViewModel - alergi dan makro saat generate', () {
    test('TC-RVM-012: semua jalur menu utama mengirim alergi', () async {
      storage.allergies = 'telur, kacang';

      vm.init();
      await settle();
      vm.refreshMeal('A', 400);
      vm.mealFuture('B', 400);

      expect(vm.excludeAllergies, ['telur', 'kacang']);
      // 3 prefetch + 1 refresh + 1 fallback
      expect(firestore.mealCalls.length, 5);
      expect(
        firestore.mealCalls.map((c) => c['allergens']),
        everyElement(['telur', 'kacang']),
      );
    });

    test('TC-RVM-013: snack juga mengirim alergi', () async {
      storage.allergies = 'telur, kacang';

      vm.init();
      await settle();
      vm.refreshSnack(camilanPagi, 197);
      vm.snackFuture('Camilan Baru', 100);

      // 2 prefetch + 1 refresh + 1 baru
      expect(firestore.snackAllergens.length, 4);
      expect(firestore.snackAllergens, everyElement(['telur', 'kacang']));
    });

    test('TC-RVM-014: tanpa makro tersimpan, rasio null (skor kalori saja)',
        () async {
      vm.init();
      await settle();
      firestore.mealCalls.clear();

      vm.refreshMeal('A', 400);

      expect(vm.effectiveMacro, isNull);
      expect(firestore.mealCalls.single['ratios'], isNull);
    });

    test('TC-RVM-015: makro tersimpan dipakai untuk menu utama', () async {
      firestore.remoteMacro =
          MacroNutrient(carbPercent: 40, proteinPercent: 30, fatPercent: 30);

      vm.init();
      await settle();
      firestore.mealCalls.clear();
      vm.refreshMeal('A', 400);

      expectRatios(firestore.mealCalls.single['ratios'],
          carbs: 0.40, protein: 0.30, fat: 0.30);
    });

    test('TC-RVM-016: makro pilihan sesi ini menggantikan yang tersimpan',
        () async {
      firestore.remoteMacro =
          MacroNutrient(carbPercent: 40, proteinPercent: 30, fatPercent: 30);

      vm.init();
      await settle();
      vm.applyMacro(
        MacroNutrient(carbPercent: 50, proteinPercent: 25, fatPercent: 25),
      );
      firestore.mealCalls.clear();
      vm.refreshMeal('A', 400);

      expectRatios(firestore.mealCalls.single['ratios'],
          carbs: 0.50, protein: 0.25, fat: 0.25);
    });
  });

  group('ResultsViewModel - total nutrisi', () {
    final items = [
      food('m1', calories: 300, protein: 20, carbs: 30, fat: 10),
      food('m2', calories: 200, protein: 10, carbs: 25, fat: 5),
    ];

    test('TC-RVM-017: total dihitung dari menu yang dimuat', () {
      vm.trackMealSection(sarapan, items);
      vm.updateTotals();

      final t = vm.totals.value;
      expect(t['calories'], closeTo(500, 0.001));
      expect(t['protein'], closeTo(30, 0.001));
      expect(t['carbs'], closeTo(55, 0.001));
      expect(t['fat'], closeTo(15, 0.001));
    });

    test('TC-RVM-018: setCardNutrition mengubah total dan memberi notifikasi',
        () {
      var notified = 0;
      vm.addListener(() => notified++);

      // dipanggil dari builder, jadi tidak boleh memicu notifikasi
      vm.trackMealSection(sarapan, items);
      expect(notified, 0);

      vm.setCardNutrition('$sarapan-0', 100, 5, 10, 2);

      expect(notified, 1);
      final t = vm.totals.value;
      expect(t['calories'], closeTo(300, 0.001)); // 100 + 200
      expect(t['protein'], closeTo(15, 0.001));
      expect(t['carbs'], closeTo(35, 0.001));
      expect(t['fat'], closeTo(7, 0.001));
    });

    test('TC-RVM-019: snack utama tidak dihitung dobel', () {
      final snack = food('s1', calories: 150, protein: 8, carbs: 20, fat: 4);

      vm.trackSnackSection(camilanPagi, [snack]);
      vm.trackSnackMain(camilanPagi, snack);

      final t = vm.totals.value;
      expect(t['calories'], closeTo(150, 0.001));
      expect(t['protein'], closeTo(8, 0.001));
    });
  });

  group('ResultsViewModel - lifecycle dan sesi', () {
    test('TC-RVM-020: signOut hapus data lokal dulu baru sign out', () async {
      await vm.signOut();

      expect(log, ['hapusDataUser', 'signOut']);
    });

    test('TC-RVM-021: loadSearchableFoods bersihkan cache dan saring alergi',
        () async {
      storage.allergies = 'telur';
      firestore.allFoods = [
        food('aman'),
        food('telur-dadar', alergen: ['telur']),
      ];

      vm.init();
      await settle();
      final foods = await vm.loadSearchableFoods();

      expect(foods.map((f) => f.id), ['aman']);
      expect(firestore.cacheClears, 1);
    });

    test('TC-RVM-022: callback async setelah dispose tidak error', () async {
      final other = makeVm();
      firestore.mealGate = Completer<List<FoodItem>>();

      other.setDietGoal(DietGoal.maintain);
      other.dispose();
      // menu utama baru selesai setelah ViewModel di-dispose
      firestore.mealGate!.complete([food('terlambat')]);
      await settle();

      expect(() => other.updateTotals(), returnsNormally);
    });
  });
}