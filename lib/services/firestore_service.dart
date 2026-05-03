import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'macro_nutrient.dart';

class FoodItem {
  final String id;
  final String name;
  final String kategori;
  final String kondisi;
  final int calories;
  final num protein;
  final num carbs;
  final num fat;
  final String? imageUrl;

  FoodItem({
    required this.id,
    required this.name,
    required this.kategori,
    required this.kondisi,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.imageUrl,
  });

  factory FoodItem.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data =
        (doc.data() ?? {}) as Map<String, dynamic>;

    String name = (data['nama'] as String?)?.trim() ?? 'Tanpa Nama';
    String kategori = (data['kategori'] as String?)?.trim() ?? 'Lainnya';
    String kondisi = (data['kondisi'] as String?)?.trim() ?? 'Tidak Diketahui';

    return FoodItem(
      id: doc.id,
      name: name,
      kategori: kategori,
      kondisi: kondisi,
      calories: (data['kalori'] as num?)?.toInt() ?? 0,
      protein: (data['protein'] as num?) ?? 0,
      carbs: (data['karbohidrat'] as num?) ?? 0,
      fat: (data['lemak'] as num?) ?? 0,
      imageUrl: (data['gambarUrl'] as String?) ?? (data['gambar'] as String?),
    );
  }

  /// Construct a FoodItem from a simple Map (used for isolate serialization)
  factory FoodItem.fromMap(Map<String, dynamic> m) {
    return FoodItem(
      id: m['id'] as String,
      name: m['name'] as String,
      kategori: m['kategori'] as String,
      kondisi: m['kondisi'] as String,
      calories: m['calories'] as int,
      protein: m['protein'] as num,
      carbs: m['carbs'] as num,
      fat: m['fat'] as num,
      imageUrl: m['imageUrl'] as String?,
    );
  }
}

/// Background isolate entrypoint that performs the heavy combination search.
///
/// [params] is expected to be a Map containing serialized lists and other
/// primitive inputs; it returns a list of serialized FoodItem maps.
Future<List<Map<String, dynamic>>> _computeMealPlan(
    Map<String, dynamic> params) async {
  final int targetCalories = params['target'] as int;
  final Map<String, double>? ratios =
      (params['ratios'] as Map?)?.cast<String, double>();

  List<Map<String, dynamic>> karbo =
      List<Map<String, dynamic>>.from(params['karbo'] as List);
  List<Map<String, dynamic>> lauk =
      List<Map<String, dynamic>>.from(params['lauk'] as List);
  List<Map<String, dynamic>> sayur =
      List<Map<String, dynamic>>.from(params['sayur'] as List);
  List<Map<String, dynamic>> buah =
      List<Map<String, dynamic>>.from(params['buah'] as List);

  // helpers to convert back and forth
  FoodItem toFood(Map<String, dynamic> m) =>
      FirestoreService._mapToFood(m); // uses static helper

  // convert all maps to FoodItem once for easy use
  var klist = karbo.map(toFood).toList();
  var plist = lauk.map(toFood).toList();
  var slist = sayur.map(toFood).toList();
  var blist = buah.map(toFood).toList();

  List<List<FoodItem>> candidates = [];
  List<FoodItem> bestFallback = [];
  int bestDiffFallback = 99999;
  double bestScoreFallback = double.infinity;
  int tolerance = 50;

  // determine combos (similar to original logic but in isolate)
  void evaluateCombo(List<FoodItem> combo) {
    int total = combo.fold(0, (sum, f) => sum + f.calories);
    int diff = (targetCalories - total).abs();
    
    // Evaluasi batas toleransi kalori
    if (diff <= tolerance) {
      candidates.add(combo);
    }

    double score = diff.toDouble();

    // Perhitungan penyimpangan rasio makronutrien (jika ada ratios)
    if (ratios != null) {
      int tot = total;
      double carbCals = combo.fold(0, (sum, f) => sum + f.carbs.toDouble() * 4);
      double proteinCals = combo.fold(0, (sum, f) => sum + f.protein.toDouble() * 4);
      double fatCals = combo.fold(0, (sum, f) => sum + f.fat.toDouble() * 9);

      double percCarbs = carbCals / tot;
      double percProtein = proteinCals / tot;
      double percFat = fatCals / tot;

      double tc = ratios['carbs'] ?? 0;
      double tp = ratios['protein'] ?? 0;
      double tf = ratios['fat'] ?? 0;

      // Perhitungan penyimpangan rasio makronutrien
      double mErr = (percCarbs - tc) * (percCarbs - tc) +
          (percProtein - tp) * (percProtein - tp) +
          (percFat - tf) * (percFat - tf);
      score = (diff / (targetCalories > 0 ? targetCalories : 1)) + 5.0 * mErr;
    }
    if (score < bestScoreFallback) {
      bestScoreFallback = score;
      bestDiffFallback = diff;
      bestFallback = combo;
    }
  }

  // Loop with early exit when candidates large
  const int maxCandidates = 50;
  if (slist.isNotEmpty && blist.isNotEmpty) {
    for (var k in klist) {
      for (var p in plist) {
        for (var s in slist) {
          for (var b in blist) {
            if (k.id == p.id ||
                k.id == s.id ||
                k.id == b.id ||
                p.id == s.id ||
                p.id == b.id ||
                s.id == b.id) continue;
            evaluateCombo([k, p, s, b]);
            if (candidates.length >= maxCandidates) break;
          }
          if (candidates.length >= maxCandidates) break;
        }
        if (candidates.length >= maxCandidates) break;
      }
      if (candidates.length >= maxCandidates) break;
    }
  }
  if (candidates.length < 3 && slist.isNotEmpty) {
    for (var k in klist) {
      for (var p in plist) {
        for (var s in slist) {
          if (k.id == p.id || k.id == s.id || p.id == s.id) continue;
          evaluateCombo([k, p, s]);
          if (candidates.length >= maxCandidates) break;
        }
        if (candidates.length >= maxCandidates) break;
      }
      if (candidates.length >= maxCandidates) break;
    }
  }
  if (candidates.length < 3) {
    for (var k in klist) {
      for (var p in plist) {
        if (k.id == p.id) continue;
        evaluateCombo([k, p]);
        if (candidates.length >= maxCandidates) break;
      }
      if (candidates.length >= maxCandidates) break;
    }
  }

  // pick winner (use local Random to avoid accessing service instance)
  final rand = Random();
  List<FoodItem> finalCombo;
  if (candidates.isNotEmpty) {
    finalCombo = candidates[rand.nextInt(candidates.length)];
  } else if (bestFallback.isNotEmpty) {
    finalCombo = bestFallback;
  } else {
    finalCombo = [
      [...klist, ...plist].reduce((a, b) =>
          (a.calories - targetCalories).abs() <
                  (b.calories - targetCalories).abs()
              ? a
              : b)
    ];
  }

  // return serialized using the static helper on FirestoreService
  return finalCombo.map(FirestoreService._foodToMap).toList();
}

class MealCombination {
  final List<FoodItem> items;
  final int totalCalories;

  MealCombination({required this.items, required this.totalCalories});

  int get caloriesDifference =>
      (totalCalories - items.fold<int>(0, (sum, item) => sum + item.calories))
          .abs();
}

class FirestoreService {
// Tambahkan ini
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _random = Random(); // Untuk randomisasi

  // helper serialisation for isolate
  static Map<String, dynamic> _foodToMap(FoodItem f) => {
        'id': f.id,
        'name': f.name,
        'kategori': f.kategori,
        'kondisi': f.kondisi,
        'calories': f.calories,
        'protein': f.protein,
        'carbs': f.carbs,
        'fat': f.fat,
        'imageUrl': f.imageUrl,
      };

  // create from map (reverse)
  static FoodItem _mapToFood(Map<String, dynamic> m) => FoodItem(
        id: m['id'],
        name: m['name'],
        kategori: m['kategori'],
        kondisi: m['kondisi'],
        calories: m['calories'],
        protein: m['protein'],
        carbs: m['carbs'],
        fat: m['fat'],
        imageUrl: m['imageUrl'],
      );

  // Cache sederhana untuk mengurangi beban fetch berulang
  List<FoodItem>? _cachedFoodItems;

  // Clear cache (useful when data changed or when we want fresh fetch)
  void clearCache() => _cachedFoodItems = null;

  // Simpan measurement (BMI, weight, TDEE) ke Firestore
  // Dipanggil setiap kali user set diet goal
  Future<void> saveMeasurement({
    required String uid,
    required double weight,
    required double bmi,
    required int tdee,
    required String goal,
  }) async {
    try {
      final now = Timestamp.now();
      final docId =
          now.millisecondsSinceEpoch.toString(); // Use timestamp as doc ID
          await _db
          .collection('users').doc(uid)
          .collection('measurements').doc(docId)
          .set({
        'date': now,
        'weight': weight,
        'bmi': bmi,
        'tdee': tdee,
        'goal': goal,
        'createdAt': now,
      });

      print('Measurement saved to Firestore');
    } catch (e) {
      print('Error saving measurement: $e');
    }
  }

  // Simpan macro preferences ke Firestore
  // Dipanggil saat user selesai customize macro ratio
  Future<void> saveMacroPreferences({
    required String uid,
    required double carbPercent,
    required double proteinPercent,
    required double fatPercent,
  }) async {
    try {
      await _db
          .collection('users').doc(uid)
          .collection('preferences').doc('macros')
          .set({
        'carbPercent': carbPercent,
        'proteinPercent': proteinPercent,
        'fatPercent': fatPercent,
        'updatedAt': Timestamp.now(),
      });
      print('Macro preferences saved to Firestore');
    } catch (e) {
      print('Error saving macro preferences: $e');
    }
  }

  // Load macro preferences from Firestore (returns null if not found)
  Future<MacroNutrient?> loadMacroPreferences(String uid) async {
    try {
      final doc = await _db
          .collection('users').doc(uid)
          .collection('preferences').doc('macros')
          .get();
      if (!doc.exists) return null;
      final data = (doc.data() ?? {}) as Map<String, dynamic>;
      final carb = (data['carbPercent'] as num?)?.toDouble();
      final protein = (data['proteinPercent'] as num?)?.toDouble();
      final fat = (data['fatPercent'] as num?)?.toDouble();
      if (carb == null || protein == null || fat == null) return null;
      return MacroNutrient(
        carbPercent: carb,
        proteinPercent: protein,
        fatPercent: fat,
      );
    } catch (e) {
      print('Error loading macro preferences: $e');
      return null;
    }
  }

  // Load user profile from /users/{uid} (one-time read)
  // Returns null if not found
  Future<Map<String, dynamic>?> loadUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = (doc.data() ?? {}) as Map<String, dynamic>;

      // Normalize keys we use in the app
      final profile = <String, dynamic>{};
      if (data.containsKey('weightKg')) profile['weightKg'] = data['weightKg'];
      if (data.containsKey('heightCm')) profile['heightCm'] = data['heightCm'];
      if (data.containsKey('age')) profile['age'] = data['age'];
      if (data.containsKey('gender')) profile['gender'] = data['gender'];
      if (data.containsKey('activityLevel'))
        profile['activityLevel'] = data['activityLevel'];

      return profile;
    } catch (e) {
      print('Error loading user profile: $e');
      return null;
    }
  }

  // Load the most recent measurement for a user (measurements subcollection)
  Future<Map<String, dynamic>?> loadLastMeasurement(String uid) async {
    try {
      final col = _db.collection('users').doc(uid).collection('measurements');
      final q = await col.orderBy('createdAt', descending: true).limit(1).get();
      if (q.docs.isEmpty) return null;
      final doc = q.docs.first;
      return (doc.data() ?? {}) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading last measurement: $e');
      return null;
    }
  }

  // Fetch semua food items dari Firestore
  Future<List<FoodItem>> getAllFoodItems() async {
    try {
      // Check cache dulu
      if (_cachedFoodItems != null && _cachedFoodItems!.isNotEmpty) {
        return _cachedFoodItems!;
      }

      // Jika tidak ada di cache, fetch dari Firestore
      QuerySnapshot snapshot = await _db.collection('makanan').get();

      // Simpan ke cache
      _cachedFoodItems =
          snapshot.docs.map((doc) => FoodItem.fromFirestore(doc)).toList();
      return _cachedFoodItems!;
    } catch (e) {
      print("Error fetching all food items: $e");
      return [];
    }
  }

  // Fetch food items by category for swapping
  Future<List<FoodItem>> getFoodCandidates(String category) async {
    final allFoods = await getAllFoodItems();

    // Filter di aplikasi (bukan di database) supaya hemat read
    // Cari yang kategorinya sama
    return allFoods
        .where((item) => item.kategori.toLowerCase() == category.toLowerCase())
        .toList();
  }

  // Group and filter foods to build balanced menus
  Future<Map<String, List<FoodItem>>> getBalancedFoods() async {
    final all = await getAllFoodItems();

    // Filter untuk makanan yang tidak bisa dimakan
    final edible = all.where((f) {
      final k = f.kategori.toLowerCase();
      final kond = f.kondisi.toLowerCase();
      final n = f.name.toLowerCase(); // Check nama

      // yang masuk daftar blacklist (Bahan mentah non-lauk)
      bool isBanned = n.contains('tepung') ||
          n.contains('minyak') ||
          n.contains('bumbu') ||
          n.contains('penyedap') ||
          n.contains('santan') ||
          n.contains('bubuk') ||
          n.contains('beras'); // Beras diban, Nasi diizinkan

      if (isBanned) {
        return false; // Membuang item yang termasuk di daftar blacklist
      }

      // Keep only edible items: Matang / Olahan, Mentah (Lauk), or Buah/Minuman
      return kond == 'matang' ||
          kond == 'olahan' ||
          kond == 'mentah' ||
          k == 'buah' ||
          k == 'minuman';
    }).toList();

    // Helper untuk check kategori
    bool catMatches(FoodItem f, List<String> patterns) {
      final k = f.kategori.toLowerCase();
      return patterns.any((p) => k.contains(p));
    }

    final karbo = edible
        .where((f) => catMatches(f, [
              'nasi',
              'serealia',
              'beras', // Jaga-jaga kalau lolos filter nama
              'umbi',
              'ubi',
              'roti',
              'kentang',
              'jagung',
              'mie',
              'bihun'
            ]))
        .toList();

    final protein = edible
        .where((f) => catMatches(f, [
              'daging',
              'unggas',
              'ikan',
              'kerang',
              'udang',
              'telur',
              'tempe',
              'tahu',
              'kacang',
              'biji',
              'bean',
              'ayam',
              'sapi',
            ]))
        .toList();

    final sayur = edible
        .where((f) => catMatches(
            f, ['sayur', 'sayuran', 'lalap', 'bayam', 'kangkung', 'sop']))
        .toList();

    final buah = edible
        .where((f) => catMatches(f, [
              'buah',
              'pisang',
              'apel',
              'jeruk',
              'mangga',
              'avokad',
              'pepaya',
              'melon'
            ]))
        .toList();

    // Acak urutan list supaya pencarian tidak selalu dimulai dari item yang sama
    // Ini membantu variasi jika kandidat sangat sedikit
    karbo.shuffle();
    protein.shuffle();
    sayur.shuffle();
    buah.shuffle();

    return {
      'karbo': karbo,
      'protein': protein,
      'sayur': sayur,
      'buah': buah,
    };
  }

  // Generate balanced meal plan with SMART SORTING based on Macros
  // Parameter 'ratios' ditambahkan (opsional) untuk prioritas nutrisi
  Future<List<FoodItem>> generateMealPlan(int targetCalories,
      {Map<String, double>? ratios}) async {
    // fetch categories first
    final cats = await getBalancedFoods();
    final karbo = cats['karbo'] ?? [];
    final lauk = cats['protein'] ?? [];
    final sayur = cats['sayur'] ?? [];
    final buah = cats['buah'] ?? [];

    if (karbo.isEmpty || lauk.isEmpty) return [];

    // to avoid quadratic/cubic explosion we sample each list if it's very long
    List<FoodItem> sample(List<FoodItem> list, int max) {
      if (list.length <= max) return list;
      list.shuffle(_random);
      return list.take(max).toList();
    }

    // limit each category to at most 20 items for combination search
    final karboSample = sample(karbo, 20);
    final laukSample = sample(lauk, 20);
    final sayurSample = sample(sayur, 20);
    final buahSample = sample(buah, 20);

    // prepare data for isolate: convert FoodItem -> Map
    Map<String, dynamic> payload = {
      'target': targetCalories,
      'ratios': ratios,
      'karbo': karboSample.map((f) => _foodToMap(f)).toList(),
      'lauk': laukSample.map((f) => _foodToMap(f)).toList(),
      'sayur': sayurSample.map((f) => _foodToMap(f)).toList(),
      'buah': buahSample.map((f) => _foodToMap(f)).toList(),
    };

    // compute in background isolate
    final result = await compute(_computeMealPlan, payload);

    // convert back to FoodItem
    return result.map((m) => FoodItem.fromMap(m)).toList();
  }

  // ===== SNACK RECOMMENDATION METHODS =====
  // Based on research (Bermingham et al., 2024; Almoraie et al., 2021)
  // High-quality snacks = whole foods with high nutrient density
  // High-protein snacks = emphasis on protein for satiety & appetite control

  /// Classify snack quality based on criteria from literature
  ///
  /// High-quality snack criteria:
  /// 1. Whole foods (non-processed): buah, sayur, kacang, biji-bijian
  /// 2. Low in added sugar
  /// 3. Good fiber content (typically from whole foods)
  /// 4. NOT: ultra-processed, cookies, candy, sugary drinks 
  
  bool _isHighQualitySnack(FoodItem food) {
    // High-quality snack categories based on research
    final highQualityCategories = [
      'buah',
      'sayur',
      'kacang',
      'biji-bijian',
      'dairy',
      'yogurt',
      'keju',
      'nuts',
      'seeds',
    ];

    // Lowercase untuk case-insensitive matching
    final category = food.kategori.toLowerCase();
    final name = food.name.toLowerCase();

    // Check if kategori matches high-quality
    final isCategoryMatched = highQualityCategories.any(
      (hq) => category.contains(hq),
    );

    // Avoid explicitly known low-quality snacks
    final isLowQuality = name.contains('kue') ||
        name.contains('cookies') ||
        name.contains('permen') ||
        name.contains('candy') ||
        name.contains('cokelat') ||
        name.contains('chocolate') ||
        name.contains('soda') ||
        name.contains('minuman manis') ||
        category.contains('kue') ||
        category.contains('candy');

    return isCategoryMatched && !isLowQuality;
  }

  /// Calculate protein percentage from macros
  double _calculateProteinPercent(FoodItem food) {
    if (food.calories == 0) return 0;
    // `food.protein` is stored as num, Firestore may return int on Android
    // so convert safely to double instead of casting.
    final proteinCal = food.protein.toDouble() * 4; // 4 cal/gram
    return (proteinCal / food.calories) * 100;
  }

  /// persentase karbo dari total kalori
  double _calculateCarbPercent(FoodItem food) {
    if (food.calories == 0) return 0;
    final carbCal = food.carbs.toDouble() * 4; // 4 cal/gram
    return (carbCal / food.calories) * 100;
  }

  /// persentase lemak dari total kalori
  double _calculateFatPercent(FoodItem food) {
    if (food.calories == 0) return 0;
    final fatCal = food.fat.toDouble() * 9; // 9 cal/gram
    return (fatCal / food.calories) * 100;
  }

  /// Get high-quality snacks filtered by target calories
  ///
  /// Returns list of snacks that are:
  /// - Whole foods (fruits, vegetables, nuts, seeds, dairy)
  /// - Close to target calorie range (±20%)
  /// - Sorted by protein content (high-protein first)
  Future<List<FoodItem>> getHighQualitySnacks(int targetCalories) async {
    try {
      final allFoods = await getAllFoodItems();

      // Filter for high-quality snacks
      final snacks = allFoods.where(_isHighQualitySnack).toList();

      // Filter by calorie range (±20% tolerance)
      final tolerance = (targetCalories * 0.20).ceil();
      final filtered = snacks.where((f) {
        final diff = (f.calories - targetCalories).abs();
        return diff <= tolerance;
      }).toList();

      // Sort by protein percentage (descending) → high-protein first
      filtered.sort((a, b) {
        final proteinPercentA = _calculateProteinPercent(a);
        final proteinPercentB = _calculateProteinPercent(b);
        return proteinPercentB.compareTo(proteinPercentA);
      });

      return filtered;
    } catch (e) {
      debugPrint('Error getting high-quality snacks: $e');
      return [];
    }
  }

  /// Get snack recommendations matching user's macro preferences
  ///
  /// If macroPrefs provided: filters and sorts based on user's target ratios
  /// If macroPrefs null: defaults to high-protein emphasis (research-backed)
  ///
  /// Sorted by:
  /// 1. Distance from user's macro target (best match first)
  /// 2. Calorie proximity to target
  /// 3. Does not cause daily macro overshoot
  Future<List<FoodItem>> getHighProteinSnackRecommendations(int targetCalories,
      {MacroNutrient? macroPrefs,
      int? dailyTargetCal,
      double? dailyTargetCarbs,
      double? dailyTargetProtein,
      double? dailyTargetFat,
      Map<String, double>? macrosEaten}) async {
    try {
      final allFoods = await getAllFoodItems();

      // Filter for high-quality snacks
      final candidates = allFoods.where(_isHighQualitySnack).toList();

      if (candidates.isEmpty) {
        return await getHighQualitySnacks(targetCalories);
      }

      // Determine macro thresholds based on user preference or default
      final double targetProtein = macroPrefs?.proteinPercent ?? 35.0; // default: 35%
      final double targetCarbs = macroPrefs?.carbPercent ?? 45.0; // default: 45%
      final double targetFat = macroPrefs?.fatPercent ?? 20.0; // default: 20%

      // Calculate remaining macro budget (to prevent overshoot)
      final double remainingCarbs =
          dailyTargetCarbs != null && macrosEaten != null
              ? (dailyTargetCarbs - (macrosEaten['carbs'] ?? 0))
                  .clamp(0, double.infinity)
              : double.infinity;
      final double remainingProtein =
          dailyTargetProtein != null && macrosEaten != null
              ? (dailyTargetProtein - (macrosEaten['protein'] ?? 0))
                  .clamp(0, double.infinity)
              : double.infinity;
      final double remainingFat = dailyTargetFat != null && macrosEaten != null
          ? (dailyTargetFat - (macrosEaten['fat'] ?? 0))
              .clamp(0, double.infinity)
          : double.infinity;

      // Step 1: Filter minimum protein baseline (snack quality assurance)
      // Minimum adalah 80% dari target protein (atau 15%, whichever is higher)
      final double minProtein = (targetProtein * 0.8).clamp(15.0, 100.0);
      final lowProteinCandidates = candidates
          .where((f) => _calculateProteinPercent(f) >= minProtein)
          .toList();

      // Step 2: Filter snacks that won't cause daily overshoot
      final nonOvershooting = lowProteinCandidates.where((f) {
        return f.protein <= remainingProtein &&
            f.carbs <= remainingCarbs &&
            f.fat <= remainingFat;
      }).toList();

      // Fallback if overshoot filtering too strict
      final baseCandidates =
          nonOvershooting.isNotEmpty ? nonOvershooting : lowProteinCandidates;
      final tolerance = (targetCalories * 0.15).ceil();

      // Primary: prefer items that do not exceed the calorie target
      List<FoodItem> filtered = baseCandidates.where((f) {
        final diff = (f.calories - targetCalories).abs();
        return diff <= tolerance && f.calories <= targetCalories;
      }).toList();

      // If nothing fits under the target, relax to any item <= target
      if (filtered.isEmpty) {
        filtered =
            candidates.where((f) => f.calories <= targetCalories).toList();
      }

      // If still empty, allow overshoot within tolerance
      if (filtered.isEmpty) {
        filtered = candidates.where((f) {
          final diff = (f.calories - targetCalories).abs();
          return diff <= tolerance;
        }).toList();
      }

      // Last resort: if still empty, just take some high-quality foods
      if (filtered.isEmpty) {
        return candidates.take(5).toList();
      }

      // Sort by macro match quality
      filtered.sort((a, b) {
  // =========================
  // PRIORITAS 1: KALORI TERDEKAT
  // =========================
  final diffA = (a.calories - targetCalories).abs();
  final diffB = (b.calories - targetCalories).abs();

  if (diffA != diffB) {
    return diffA.compareTo(diffB);
  }

  // =========================
  // PRIORITAS 2: MACRO MATCH
  // =========================
  final aProtein = _calculateProteinPercent(a);
  final aCarbs = a.carbs.toDouble() * 4 / a.calories * 100;
  final aFat = _calculateFatPercent(a);

  final bProtein = _calculateProteinPercent(b);
  final bCarbs = b.carbs.toDouble() * 4 / b.calories * 100;
  final bFat = _calculateFatPercent(b);

  // kalau ada remaining macro (biar ga overshoot)
  if (remainingCarbs != double.infinity &&
      remainingProtein != double.infinity &&
      remainingFat != double.infinity) {
    
    final aRemainError =
        ((a.carbs - remainingCarbs) * (a.carbs - remainingCarbs)) +
        ((a.protein - remainingProtein) * (a.protein - remainingProtein)) +
        ((a.fat - remainingFat) * (a.fat - remainingFat));

    final bRemainError =
        ((b.carbs - remainingCarbs) * (b.carbs - remainingCarbs)) +
        ((b.protein - remainingProtein) * (b.protein - remainingProtein)) +
        ((b.fat - remainingFat) * (b.fat - remainingFat));

    return aRemainError.compareTo(bRemainError);
  } else {
    // fallback ke target macro
    final aError =
        (aProtein - targetProtein) * (aProtein - targetProtein) +
        (aCarbs - targetCarbs) * (aCarbs - targetCarbs) +
        (aFat - targetFat) * (aFat - targetFat);

    final bError =
        (bProtein - targetProtein) * (bProtein - targetProtein) +
        (bCarbs - targetCarbs) * (bCarbs - targetCarbs) +
        (bFat - targetFat) * (bFat - targetFat);

    return aError.compareTo(bError);
  }
});

      return filtered;
    } catch (e) {
      debugPrint('Error getting snack recommendations: $e');
      return [];
    }
  }

  // ===== DAILY MENU PERSISTENCE =====
  // Simpan menu harian ke Firestore dengan key tanggal hari ini
  // Dipanggil setelah menu digenerate atau di-refresh

  String _todayKey() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.year}';
  }

  /// Simpan menu 1 section ke Firestore
  Future<void> saveSectionMenu({
    required String uid,
    required String section,
    required List<FoodItem> items,
    required String goal,
    required int tdee,
  }) async {
    try {
      final docRef = _db
          .collection('users')
          .doc(uid)
          .collection('daily_menus')
          .doc(_todayKey());

      final itemsData = items.map((f) => {
        'id': f.id,
        'name': f.name,
        'kategori': f.kategori,
        'kondisi': f.kondisi,
        'calories': f.calories,
        'protein': f.protein,
        'carbs': f.carbs,
        'fat': f.fat,
        'imageUrl': f.imageUrl ?? '',
      }).toList();

      await docRef.set({
        section: itemsData,
        'goal': goal,
        'tdee': tdee,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      debugPrint('✅ Menu $section saved for ${_todayKey()}');
    } catch (e) {
      debugPrint('❌ Error saving section menu: $e');
    }
  }

  /// Load menu harian dari Firestore
  /// Returns null kalau tidak ada data untuk hari ini
  Future<Map<String, dynamic>?> loadDailyMenu(String uid) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('daily_menus')
          .doc(_todayKey())
          .get();

      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('❌ Error loading daily menu: $e');
      return null;
    }
  }

  /// Parse list of FoodItem dari data Firestore
  List<FoodItem> parseFoodItems(dynamic data) {
    if (data == null) return [];
    try {
      final list = data as List<dynamic>;
      return list.map((item) {
        final m = item as Map<String, dynamic>;
        return FoodItem(
          id: m['id'] as String,
          name: m['name'] as String,
          kategori: m['kategori'] as String,
          kondisi: m['kondisi'] as String,
          calories: (m['calories'] as num).toInt(),
          protein: m['protein'] as num,
          carbs: m['carbs'] as num,
          fat: m['fat'] as num,
          imageUrl: m['imageUrl'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error parsing food items: $e');
      return [];
    }
  }
}