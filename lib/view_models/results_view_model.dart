import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import '../models/profile_notifier.dart';
import '../services/calculator_service.dart';
import '../services/firestore_service.dart';
import '../services/local_storage_service.dart';
import '../services/macro_nutrient.dart';

class ResultsViewModel extends ChangeNotifier {
  ResultsViewModel({
    required CalculatorService calculator,
    required FirestoreService firestoreService,
    required LocalStorageService storageService,
    required AuthService authService,
    required String? Function() getUid,
  })  : _firestoreService = firestoreService,
        _storageService = storageService,
        _authService = authService,
        _getUid = getUid {
    _applyCalculator(calculator);
  }

  final FirestoreService _firestoreService;
  final LocalStorageService _storageService;
  final AuthService _authService;
  final String? Function() _getUid;

  late CalculatorService _calculator;
  late double _bmi;
  late String _bmiCategory;
  late double _bmr;
  late int _tdee;

  DietGoal? _selectedGoal;
  int? _finalCalories;
  MacroNutrient? _selectedMacro;
  MacroNutrient? _loadedMacro;

  List<String> _excludeAllergies = [];

  Map<String, dynamic>? _lastMeasurement;
  bool _loadingLastMeasurement = true;

  final ValueNotifier<Map<String, double>> _totalsNotifier =
      ValueNotifier(<String, double>{});

  final Map<String, Map<String, double>> _currentMealsData = {};
  final Map<String, Future<List<FoodItem>>> _mealFutures = {};
  final Map<String, Future<List<FoodItem>>> _snackFutures = {};
  final Map<String, List<FoodItem>> _allLoadedMeals = {};

  ProfileNotifier? _profileNotifier;
  bool _disposed = false;

  double get bmi => _bmi;
  String get bmiCategory => _bmiCategory;
  double get bmr => _bmr;
  int get tdee => _tdee;
  CalculatorService get calculator => _calculator;
  DietGoal? get selectedGoal => _selectedGoal;
  int? get finalCalories => _finalCalories;

  int get baseCalories => _finalCalories ?? _tdee;

  MacroNutrient? get effectiveMacro => _selectedMacro ?? _loadedMacro;

  List<String> get excludeAllergies => _excludeAllergies;
  Map<String, dynamic>? get lastMeasurement => _lastMeasurement;
  bool get loadingLastMeasurement => _loadingLastMeasurement;
  ValueListenable<Map<String, double>> get totals => _totalsNotifier;

  void init() {
    _loadLastMeasurement();
    _loadMacroPreferences();
    _bootstrap();
    updateTotals();
  }

  void attachProfile(ProfileNotifier? pn) {
    if (pn != null && pn != _profileNotifier) {
      _profileNotifier?.removeListener(_onProfileChanged);
      _profileNotifier = pn;
      pn.addListener(_onProfileChanged);
      if (pn.calculator != null) {
        _onProfileChanged();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _profileNotifier?.removeListener(_onProfileChanged);
    _totalsNotifier.dispose();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setDietGoal(DietGoal goal) {
    _invalidateMenuCaches();
    _selectedGoal = goal;
    _finalCalories = _calculator.getAdjustedCalories(goal, _tdee);

    _prepareAllSectionFutures();
    updateTotals();
    _notify();

    _saveMeasurementToFirestore(goal);
  }

  void resetGoal() {
    _selectedGoal = null;
    _finalCalories = null;
    _invalidateMenuCaches();
    _notify();
  }

  void applyMacro(MacroNutrient macro) {
    _selectedMacro = macro;
    _invalidateMenuCaches();
    _prepareAllSectionFutures();
    _notify();
  }

  void refreshMeal(String title, int targetCalories) {
    _currentMealsData.removeWhere((k, v) => k.startsWith('$title-'));
    _allLoadedMeals.remove(title);
    _mealFutures[title] = _generateMeal(title, targetCalories, track: false);
    _notify();
  }

  void refreshSnack(String title, int targetCalories) {
    _currentMealsData.removeWhere((k, v) => k == 'snack-$title');
    _allLoadedMeals.remove(title);
    _snackFutures[title] = _generateSnack(title, targetCalories, track: false);
    _notify();
  }

  Future<List<FoodItem>> mealFuture(String title, int targetCalories) {
    return _mealFutures[title] ??=
        _generateMeal(title, targetCalories, track: false);
  }

  Future<List<FoodItem>> snackFuture(String title, int targetCalories) {
    return _snackFutures.putIfAbsent(
        title, () => _generateSnack(title, targetCalories, track: false));
  }

  void trackMealSection(String title, List<FoodItem> items) {
    _allLoadedMeals[title] = items;

    items.asMap().forEach((idx, item) {
      final key = '$title-$idx';
      _currentMealsData.putIfAbsent(
          key,
          () => {
                'calories': item.calories.toDouble(),
                'protein': item.protein.toDouble(),
                'carbs': item.carbs.toDouble(),
                'fat': item.fat.toDouble(),
              });
    });
  }

  void trackSnackSection(String title, List<FoodItem> items) {
    _allLoadedMeals[title] = items;
  }

  void trackSnackMain(String title, FoodItem item) {
    _currentMealsData['snack-$title'] = {
      'calories': item.calories.toDouble(),
      'protein': item.protein.toDouble(),
      'carbs': item.carbs.toDouble(),
      'fat': item.fat.toDouble(),
    };
    updateTotals();
  }

  void setCardNutrition(String key, double calories, double protein,
      double carbs, double fat) {
    _currentMealsData[key] = {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
    _notify();
    updateTotals();
  }

  void updateTotals() {
    if (_disposed) return;
    _totalsNotifier.value = _calculateDailyTotals();
  }

  Future<List<FoodItem>> loadSearchableFoods() async {
    _firestoreService.clearCache();
    final allFoods = await _firestoreService.getAllFoodItems();
    return _filterAllergicItems(allFoods);
  }

  Future<void> signOut() async {
    await _storageService.hapusDataUser();
    await _authService.signOut();
  }

  Future<void> _bootstrap() async {
    await _loadAllergies();
    await _loadDailyMenuCache();
  }

  List<String> _normalizeAllergens(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _loadAllergies() async {
    final data = await _storageService.loadDataUser();
    final raw = data['alergi'] ?? '';
    _excludeAllergies = _normalizeAllergens(raw);
    _notify();
  }

  bool _isExcludedByAllergens(FoodItem item) {
    return item.matchesAllergens(_excludeAllergies);
  }

  List<FoodItem> _filterAllergicItems(List<FoodItem> items) {
    if (_excludeAllergies.isEmpty) return items;
    return items
        .where((item) => !item.matchesAllergens(_excludeAllergies))
        .toList();
  }

  Future<void> _onProfileChanged() async {
    final calc = _profileNotifier?.calculator;
    if (calc != null) {
      await _loadAllergies();
      if (_disposed) return;
      _applyCalculator(calc);
      _invalidateMenuCaches();
      _prepareAllSectionFutures();
      _notify();
    }
  }

  void _applyCalculator(CalculatorService calc) {
    _calculator = calc;
    _bmi = _calculator.calculateBmi();
    _bmiCategory = _calculator.getBmiCategory(_bmi);
    _bmr = _calculator.calculateBmr();
    _tdee = _calculator.calculateTdee();
  }

  Future<void> _loadDailyMenuCache() async {
    final uid = _getUid();
    if (uid == null) return;
    final data = await _firestoreService.loadDailyMenu(uid);
    if (_disposed) return;
    _applyDailyMenu(data);
    _prepareAllSectionFutures();
    updateTotals();
    _notify();
  }

  void _applyDailyMenu(Map<String, dynamic>? data) {
    if (data != null) {
      final savedTdee = (data['tdee'] as num?)?.toInt();
      final currentTdee = _tdee;
      if (savedTdee != null && savedTdee != currentTdee) {
        debugPrint(
            '⚠️ TDEE berubah ($savedTdee → $currentTdee), menu lama diabaikan');
        return;
      }
    }

    if (data != null && _selectedGoal == null) {
      final goalStr = data['goal'] as String?;
      DietGoal? autoGoal;
      if (goalStr == 'lose') {
        autoGoal = DietGoal.lose;
      } else if (goalStr == 'gain') {
        autoGoal = DietGoal.gain;
      } else if (goalStr == 'maintain') {
        autoGoal = DietGoal.maintain;
      }
      if (autoGoal != null) {
        _selectedGoal = autoGoal;
        _finalCalories = _calculator.getAdjustedCalories(autoGoal, _tdee);
      }
    }

    if (data != null) {
      bool invalidCache = false;

      for (final section in [
        'Sarapan (06.00 - 09.00 Pagi)',
        'Makan Siang (12.00 - 15.00)',
        'Makan Malam  (selesai sebelum 19.00)'
      ]) {
        if (data.containsKey(section)) {
          final items = _firestoreService.parseFoodItems(data[section]);
          if (items.any(_isExcludedByAllergens)) {
            invalidCache = true;
            break;
          }
          if (items.isNotEmpty) {
            _mealFutures[section] = Future.value(items);
            _allLoadedMeals[section] = items;
          }
        }
      }

      for (final section in [
        'Camilan Pagi (10.00 Pagi)',
        'Camilan Sore (16.00)'
      ]) {
        if (data.containsKey(section)) {
          final items = _firestoreService.parseFoodItems(data[section]);
          if (items.any(_isExcludedByAllergens)) {
            invalidCache = true;
            break;
          }
          if (items.isNotEmpty) {
            _snackFutures[section] = Future.value(items);
            _allLoadedMeals[section] = items;
          }
        }
      }

      if (invalidCache) {
        debugPrint(
            '⚠️ Cached daily menu berisi makanan yang harus dihindari, menu lama diabaikan');
        _invalidateMenuCaches();
        return;
      }
    }
  }

  Map<String, double>? _macroRatios() {
    final macro = _selectedMacro ?? _loadedMacro;
    if (macro == null) return null;
    return {
      'protein': macro.proteinPercent / 100,
      'carbs': macro.carbPercent / 100,
      'fat': macro.fatPercent / 100,
    };
  }

  void _prepareAllSectionFutures() {
    final Map<String, int> mealTargets = {
      'Sarapan (06.00 - 09.00 Pagi)': (baseCalories * 0.20).round(),
      'Makan Siang (12.00 - 15.00)': (baseCalories * 0.30).round(),
      'Makan Malam  (selesai sebelum 19.00)': (baseCalories * 0.30).round(),
    };
    final Map<String, int> snackTargets = {
      'Camilan Pagi (10.00 Pagi)': (baseCalories * 0.10).round(),
      'Camilan Sore (16.00)': (baseCalories * 0.10).round(),
    };

    for (final entry in mealTargets.entries) {
      final title = entry.key;
      if (!_mealFutures.containsKey(title)) {
        _mealFutures[title] = _generateMeal(title, entry.value, track: true);
      }
    }

    for (final entry in snackTargets.entries) {
      final title = entry.key;
      if (!_snackFutures.containsKey(title)) {
        _snackFutures[title] = _generateSnack(title, entry.value, track: true);
      }
    }
  }

  Future<List<FoodItem>> _generateMeal(String title, int targetCalories,
      {required bool track}) {
    return _firestoreService
        .generateMealPlan(
      targetCalories,
      ratios: _macroRatios(),
      excludeAllergens: _excludeAllergies,
    )
        .then((items) {
      if (track && items.isNotEmpty) {
        _allLoadedMeals[title] = items;
        updateTotals();
      }
      final uid = _getUid();
      if (uid != null && _selectedGoal != null) {
        _firestoreService.saveSectionMenu(
          uid: uid,
          section: title,
          items: items,
          goal: _selectedGoal!.toString().split('.').last,
          tdee: _tdee,
        );
      }
      return items;
    });
  }

  Future<List<FoodItem>> _generateSnack(String title, int targetCalories,
      {required bool track}) {
    return _buildSnackFuture(title, targetCalories).then((items) {
      if (track && items.isNotEmpty) {
        _allLoadedMeals[title] = items;
        final key = 'snack-$title';
        _currentMealsData[key] = {
          'calories': items.first.calories.toDouble(),
          'protein': items.first.protein.toDouble(),
          'carbs': items.first.carbs.toDouble(),
          'fat': items.first.fat.toDouble(),
        };
        updateTotals();
      }
      final uid = _getUid();
      if (uid != null && _selectedGoal != null && items.isNotEmpty) {
        _firestoreService.saveSectionMenu(
          uid: uid,
          section: title,
          items: [items.first],
          goal: _selectedGoal!.toString().split('.').last,
          tdee: _tdee,
        );
      }
      return items;
    });
  }

  Future<void> _loadMacroPreferences() async {
    try {
      final local = await _storageService.loadMacroPreferencesLocal();
      if (local != null && local.isNotEmpty) {
        final c = local['carbPercent'] ?? local['carb'] ?? 0.0;
        final p = local['proteinPercent'] ?? local['protein'] ?? 0.0;
        final f = local['fatPercent'] ?? local['fat'] ?? 0.0;
        _loadedMacro =
            MacroNutrient(carbPercent: c, proteinPercent: p, fatPercent: f);
        _notify();
        return;
      }
    } catch (_) {}

    try {
      final uid = _getUid();
      if (uid != null) {
        final remote = await _firestoreService.loadMacroPreferences(uid);
        if (remote != null) {
          _loadedMacro = remote;
          _notify();
          try {
            await _storageService.saveMacroPreferencesLocal(
                carbPercent: remote.carbPercent,
                proteinPercent: remote.proteinPercent,
                fatPercent: remote.fatPercent);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _loadLastMeasurement() async {
    _loadingLastMeasurement = true;
    _notify();
    final uid = _getUid();
    if (uid == null) {
      _loadingLastMeasurement = false;
      _notify();
      return;
    }
    final data = await _firestoreService.loadLastMeasurement(uid);
    if (_disposed) return;
    _lastMeasurement = data;
    _loadingLastMeasurement = false;
    _notify();
  }

  void _invalidateMenuCaches() {
    _mealFutures.clear();
    _snackFutures.clear();
    _allLoadedMeals.clear();
    _currentMealsData.clear();
  }

  Future<void> _saveMeasurementToFirestore(DietGoal goal) async {
    try {
      final uid = _getUid();
      if (uid == null) return;

      final goalStr = goal.toString().split('.').last;

      await _firestoreService.saveMeasurement(
        uid: uid,
        weight: _calculator.weight,
        bmi: _bmi,
        tdee: _tdee,
        goal: goalStr,
      );
    } catch (e) {
      debugPrint('❌ Error in _saveMeasurementToFirestore: $e');
    }
  }

  Future<List<FoodItem>> _buildSnackFuture(String title, int targetCalories) {
    double totalCarbsEaten = 0;
    double totalProteinEaten = 0;
    double totalFatEaten = 0;
    _currentMealsData.forEach((key, macros) {
      totalCarbsEaten += macros['carbs'] ?? 0;
      totalProteinEaten += macros['protein'] ?? 0;
      totalFatEaten += macros['fat'] ?? 0;
    });

    final macro = _selectedMacro ?? _loadedMacro;
    final dailyCal = _finalCalories ?? _tdee;
    final dailyTargetCarbs =
        (dailyCal * (macro?.carbPercent ?? 60.0) / 100) / 4;
    final dailyTargetProtein =
        (dailyCal * (macro?.proteinPercent ?? 15.0) / 100) / 4;
    final dailyTargetFat = (dailyCal * (macro?.fatPercent ?? 25.0) / 100) / 9;

    return _firestoreService.getSnackRecommendations(
      targetCalories,
      macroPrefs: macro,
      dailyTargetCal: dailyCal,
      dailyTargetCarbs: dailyTargetCarbs,
      dailyTargetProtein: dailyTargetProtein,
      dailyTargetFat: dailyTargetFat,
      macrosEaten: {
        'carbs': totalCarbsEaten,
        'protein': totalProteinEaten,
        'fat': totalFatEaten,
      },
      excludeAllergens: _excludeAllergies,
    );
  }

  Map<String, double> _calculateDailyTotals() {
    double calories = 0, protein = 0, carbs = 0, fat = 0;

    final sections = <String>{};
    sections.addAll(_allLoadedMeals.keys);

    for (final key in _currentMealsData.keys) {
      if (key.startsWith('snack-')) {
        sections.add(key.substring('snack-'.length));
      } else {
        final idx = key.lastIndexOf('-');
        if (idx > 0) sections.add(key.substring(0, idx));
      }
    }

    for (final section in sections) {
      final currentKeys = _currentMealsData.keys
          .where((k) => k == 'snack-$section' || k.startsWith('$section-'))
          .toList();

      if (currentKeys.isNotEmpty) {
        for (final k in currentKeys) {
          final m = _currentMealsData[k]!;
          calories += (m['calories'] ?? 0);
          protein += (m['protein'] ?? 0);
          carbs += (m['carbs'] ?? 0);
          fat += (m['fat'] ?? 0);
        }
      } else if (_allLoadedMeals.containsKey(section)) {
        for (final item in _allLoadedMeals[section]!) {
          calories += item.calories;
          protein += item.protein;
          carbs += item.carbs;
          fat += item.fat;
        }
      }
    }

    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat
    };
  }
}