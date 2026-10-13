import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'macro_nutrient.dart';

/// Model data untuk satu item makanan.
///
/// Unit dasar yang dievaluasi oleh fungsi rule-based (pemilihan menu,
/// rekomendasi snack, dan penyimpanan ke Firestore).
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
  final List<String>
      alergen; // Daftar alergen yang terkandung (dari admin panel)

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
    this.alergen = const [],
  });

  // Buat FoodItem dari dokumen Firestore.
  factory FoodItem.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    String name = (data['nama'] as String?)?.trim() ?? 'Tanpa Nama';
    String kategori = (data['kategori'] as String?)?.trim() ?? 'Lainnya';
    String kondisi = (data['kondisi'] as String?)?.trim() ?? 'Tidak Diketahui';

    // Baca daftar alergen dari Firestore (checkbox admin panel)
    List<String> alergenList = [];
    if (data['alergen'] != null && data['alergen'] is List) {
      alergenList = List<String>.from((data['alergen'] as List)
          .map((a) => (a as String).toLowerCase().trim()));
    }

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
      alergen: alergenList,
    );
  }

  /// Check if the item matches any allergen keywords.
  /// Prioritas:
  /// 1. Cek field alergen eksplisit dari Firestore (admin panel)
  /// 2. Fallback: substring matching pada name/kondisi
  bool matchesAllergens(List<String>? allergens) {
    if (allergens == null || allergens.isEmpty) return false;

    // STEP 1: CEK FIELD EKSPLISIT DARI FIRESTORE DULU
    if ((alergen.isNotEmpty)) {
      final userAllergens =
          allergens.map((a) => a.trim().toLowerCase()).toSet();

      // Cek apakah ada overlap dengan field alergen dari DB
      for (final dbAllergen in alergen) {
        if (userAllergens.contains(dbAllergen)) {
          return true; // MATCH: item punya alergen yang user hindari
        }
      }
      // Jika field alergen ada tapi tidak cocok, langsung return false
      return false;
    }

    // STEP 2: FALLBACK - Substring matching untuk data lama tanpa field alergen
    final nameLower = name.toLowerCase();
    final kategoriLower = kategori.toLowerCase();
    final kondisiLower = kondisi.toLowerCase();

    // split category tokens (handles "Ikan, Kerang, Udang" etc.)
    final kategoriTokens = kategoriLower
        .split(RegExp(r'[\,\/]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // if the category is a mixed group like "Ikan, Kerang, Udang",
    // we do not want to automatically exclude all items in that group
    // based on one selected allergen. We only use category matching for
    // single-token categories.
    final bool kategoriIsMixed = kategoriTokens.length > 1;

    // Canonical mapping (based on common terms + FDA major allergens)
    final Map<String, List<String>> canonical = {
      'milk': ['susu', 'milk', 'dairy', 'keju', 'yoghurt', 'yogurt'],
      'eggs': ['telur', 'egg'],
      'fish': ['ikan', 'fish', 'salmon', 'tuna', 'cod', 'mackerel'],
      'crustacean': [
        'udang',
        'kepiting',
        'lobster',
        'crab',
        'shrimp',
        'kerang'
      ],
      'tree nuts': [
        'kacang mete',
        'almond',
        'kenari',
        'walnut',
        'hazelnut',
        'pistachio',
        'macadamia',
        'kacang pohon'
      ],
      'peanuts': ['kacang tanah', 'peanut', 'peanuts'],
      'wheat': ['gandum', 'wheat', 'tepung', 'roti'],
      'soybeans': ['kedelai', 'soy', 'soya', 'tempe', 'tahu'],
      'gluten': ['gluten']
    };

    // Build expanded keyword set from user-provided allergens.
    final Set<String> keywords = <String>{};
    for (final raw in allergens) {
      final r = raw.trim().toLowerCase();
      if (r.isEmpty) continue;

      // direct match to canonical key
      if (canonical.containsKey(r)) {
        keywords.addAll(canonical[r]!);
        continue;
      }

      // match against known synonyms/values
      var matched = false;
      for (final entry in canonical.entries) {
        if (entry.value.any((v) => v == r)) {
          keywords.addAll(entry.value);
          matched = true;
        }
      }
      if (matched) continue;

      // if not matched, accept the raw token as keyword (user may type 'udang')
      keywords.add(r);
    }

    // Final check: see if any keyword appears in name/kategori/kondisi or
    // matches one of the comma-separated kategori tokens exactly.
    for (final k in keywords) {
      if (k.isEmpty) continue;

      // direct substring checks on name and kondisi are the most reliable.
      if (nameLower.contains(k) || kondisiLower.contains(k)) {
        return true;
      }

      // category token matching is allowed only for simple categories.
      if (!kategoriIsMixed && kategoriTokens.any((t) => t == k)) return true;
    }

    return false;
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
      alergen: List<String>.from(m['alergen'] as List? ?? []),
    );
  }
}

/// Hitung kombinasi menu di isolate.
///
/// Rule-based: pilih kombinasi yang cocok dengan target kalori dan
/// rasio makro opsional.
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

  FoodItem toFood(Map<String, dynamic> m) =>
      FirestoreService._mapToFood(m);

  // convert all maps to FoodItem once for easy use
  var klist = karbo.map(toFood).toList();
  var plist = lauk.map(toFood).toList();
  var slist = sayur.map(toFood).toList();
  var blist = buah.map(toFood).toList();

  List<List<FoodItem>> candidates = [];
  List<FoodItem> bestFallback = [];
  double bestScoreFallback = double.infinity;

  void evaluateCombo(List<FoodItem> combo) {
    int total = combo.fold(0, (acc, f) => acc + f.calories);
    int diff = (targetCalories - total).abs();

    // RULE 1: jadikan kombinasi valid jika kalori pas (tidak ada toleransi).
    if (diff == 0) {
      candidates.add(combo);
    }

    double score = diff.toDouble();

    // RULE 2: Jika ada rasio makro target, gunakan perhitungan kesalahan
    // rasio makronutrien supaya sistem memilih menu yang tidak hanya cocok
    // secara kalori tetapi juga secara komposisi karbohidrat/protein/lemak.
    if (ratios != null) {
      int tot = total;
      double carbCals = combo.fold(0, (acc, f) => acc + f.carbs.toDouble() * 4);
      double proteinCals =
          combo.fold(0, (acc, f) => acc + f.protein.toDouble() * 4);
      double fatCals = combo.fold(0, (acc, f) => acc + f.fat.toDouble() * 9);

      double percCarbs = carbCals / tot;
      double percProtein = proteinCals / tot;
      double percFat = fatCals / tot;

      double tc = ratios['carbs'] ?? 0;
      double tp = ratios['protein'] ?? 0;
      double tf = ratios['fat'] ?? 0;

      // Hitung error antara rasio aktual dan rasio target.
      // Semakin kecil error, semakin baik.
      double mErr = (percCarbs - tc) * (percCarbs - tc) +
          (percProtein - tp) * (percProtein - tp) +
          (percFat - tf) * (percFat - tf);
      score = (diff / (targetCalories > 0 ? targetCalories : 1)) + 5.0 * mErr;
    }
    if (score < bestScoreFallback) {
      bestScoreFallback = score;
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

  return finalCombo.map(FirestoreService._foodToMap).toList();
}

// Menyimpan hasil kombinasi menu dan total kalorinya.
class MealCombination {
  final List<FoodItem> items;
  final int totalCalories;

  MealCombination({required this.items, required this.totalCalories});

  int get caloriesDifference =>
      (totalCalories - items.fold<int>(0, (acc, item) => acc + item.calories))
          .abs();
}

// ===== LOGIC SNACK YANG DITARIK KELUAR BIAR BISA DITEST =====

bool isHighQualitySnack(FoodItem food) {
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

  final category = food.kategori.toLowerCase();
  final name = food.name.toLowerCase();

  final isCategoryMatched = highQualityCategories.any(
    (hq) => category.contains(hq),
  );

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

double calculateProteinPercent(FoodItem food) {
  if (food.calories == 0) return 0;
  final proteinCal = food.protein.toDouble() * 4;
  return (proteinCal / food.calories) * 100;
}

double calculateCarbPercent(FoodItem food) {
  if (food.calories == 0) return 0;
  final carbCal = food.carbs.toDouble() * 4;
  return (carbCal / food.calories) * 100;
}

double calculateFatPercent(FoodItem food) {
  if (food.calories == 0) return 0;
  final fatCal = food.fat.toDouble() * 9;
  return (fatCal / food.calories) * 100;
}

/// Versi murni dari getHighQualitySnacks - nerima allFoods langsung.
List<FoodItem> filterHighQualitySnacks(
    List<FoodItem> allFoods, int targetCalories,
    {List<String>? excludeAllergens}) {
  final snacks = allFoods
      .where((f) => !f.matchesAllergens(excludeAllergens))
      .where(isHighQualitySnack)
      .toList();

  final exactMatch =
      snacks.where((f) => f.calories == targetCalories).toList();
  if (exactMatch.isNotEmpty) {
    exactMatch.sort((a, b) {
      final diffA = (a.calories - targetCalories).abs();
      final diffB = (b.calories - targetCalories).abs();
      return diffA.compareTo(diffB);
    });
    return exactMatch;
  }

  final tolerance = (targetCalories * 0.15).ceil();
  final filtered = snacks.where((f) {
    final diff = (f.calories - targetCalories).abs();
    return diff <= tolerance && f.calories <= targetCalories;
  }).toList();

  if (filtered.isNotEmpty) {
    filtered.sort((a, b) {
      final diffA = (a.calories - targetCalories).abs();
      final diffB = (b.calories - targetCalories).abs();
      return diffA.compareTo(diffB);
    });
    return filtered;
  }

  final overshootFallback = snacks.where((f) {
    final diff = (f.calories - targetCalories).abs();
    return diff <= tolerance;
  }).toList();

  overshootFallback.sort((a, b) {
    final diffA = (a.calories - targetCalories).abs();
    final diffB = (b.calories - targetCalories).abs();
    return diffA.compareTo(diffB);
  });

  return overshootFallback;
}

/// Versi murni dari getSnackRecommendations - nerima allFoods langsung.
/// Kalori diprioritasin duluan, rasio makro cuma tie-breaker pas last-resort.
List<FoodItem> filterSnackRecommendations(
  List<FoodItem> allFoods,
  int targetCalories, {
  MacroNutrient? macroPrefs,
  int? dailyTargetCal,
  double? dailyTargetCarbs,
  double? dailyTargetProtein,
  double? dailyTargetFat,
  Map<String, double>? macrosEaten,
  List<String>? excludeAllergens,
}) {
  final candidates = allFoods
      .where((f) => !f.matchesAllergens(excludeAllergens))
      .where(isHighQualitySnack)
      .toList();

  if (candidates.isEmpty) {
    return filterHighQualitySnacks(allFoods, targetCalories,
        excludeAllergens: excludeAllergens);
  }

  final double targetProtein = macroPrefs?.proteinPercent ?? 35.0;
  final double targetCarbs = macroPrefs?.carbPercent ?? 45.0;
  final double targetFat = macroPrefs?.fatPercent ?? 20.0;

  final double remainingCarbs = dailyTargetCarbs != null && macrosEaten != null
      ? (dailyTargetCarbs - (macrosEaten['carbs'] ?? 0))
          .clamp(0, double.infinity)
      : double.infinity;
  final double remainingProtein =
      dailyTargetProtein != null && macrosEaten != null
          ? (dailyTargetProtein - (macrosEaten['protein'] ?? 0))
              .clamp(0, double.infinity)
          : double.infinity;
  final double remainingFat = dailyTargetFat != null && macrosEaten != null
      ? (dailyTargetFat - (macrosEaten['fat'] ?? 0)).clamp(0, double.infinity)
      : double.infinity;

  final nonOvershooting = candidates.where((f) {
    return f.protein <= remainingProtein &&
        f.carbs <= remainingCarbs &&
        f.fat <= remainingFat;
  }).toList();

  final baseCandidates =
      nonOvershooting.isNotEmpty ? nonOvershooting : candidates;
  const double tolerancePercent = 0.15;

  List<FoodItem> filtered =
      baseCandidates.where((f) => f.calories == targetCalories).toList();

  if (filtered.isEmpty) {
    final tolerance = (targetCalories * tolerancePercent).ceil();
    filtered = baseCandidates.where((f) {
      final diff = (f.calories - targetCalories).abs();
      return diff <= tolerance && f.calories <= targetCalories;
    }).toList();
  }

  if (filtered.isEmpty) {
    final tolerance = (targetCalories * tolerancePercent).ceil();
    filtered = candidates.where((f) {
      final diff = (f.calories - targetCalories).abs();
      return diff <= tolerance && f.calories <= targetCalories;
    }).toList();
  }

  if (filtered.isEmpty) {
    final tolerance = (targetCalories * tolerancePercent).ceil();
    filtered = baseCandidates.where((f) {
      final diff = (f.calories - targetCalories).abs();
      return diff <= tolerance;
    }).toList();
  }

  if (filtered.isEmpty) {
    final tolerance = (targetCalories * tolerancePercent).ceil();
    filtered = candidates.where((f) {
      final diff = (f.calories - targetCalories).abs();
      return diff <= tolerance;
    }).toList();
  }

  if (filtered.isEmpty) {
    final fallback = [
      ...baseCandidates.isNotEmpty ? baseCandidates : candidates
    ];
    fallback.sort((a, b) {
      final diffA = (a.calories - targetCalories).abs();
      final diffB = (b.calories - targetCalories).abs();
      if (diffA != diffB) {
        return diffA.compareTo(diffB);
      }

      final aProtein = calculateProteinPercent(a);
      final aCarbs = a.carbs.toDouble() * 4 / a.calories * 100;
      final aFat = calculateFatPercent(a);

      final bProtein = calculateProteinPercent(b);
      final bCarbs = b.carbs.toDouble() * 4 / b.calories * 100;
      final bFat = calculateFatPercent(b);

      final aError = (aProtein - targetProtein) * (aProtein - targetProtein) +
          (aCarbs - targetCarbs) * (aCarbs - targetCarbs) +
          (aFat - targetFat) * (aFat - targetFat);

      final bError = (bProtein - targetProtein) * (bProtein - targetProtein) +
          (bCarbs - targetCarbs) * (bCarbs - targetCarbs) +
          (bFat - targetFat) * (bFat - targetFat);

      return aError.compareTo(bError);
    });
    return fallback;
  }

  filtered.sort((a, b) {
    final diffA = (a.calories - targetCalories).abs();
    final diffB = (b.calories - targetCalories).abs();

    if (diffA != diffB) {
      return diffA.compareTo(diffB);
    }

    final aProtein = calculateProteinPercent(a);
    final aCarbs = a.carbs.toDouble() * 4 / a.calories * 100;
    final aFat = calculateFatPercent(a);

    final bProtein = calculateProteinPercent(b);
    final bCarbs = b.carbs.toDouble() * 4 / b.calories * 100;
    final bFat = calculateFatPercent(b);

    if (remainingCarbs != double.infinity &&
        remainingProtein != double.infinity &&
        remainingFat != double.infinity) {
      final aRemainError =
          ((a.carbs - remainingCarbs) * (a.carbs - remainingCarbs)) +
              ((a.protein - remainingProtein) *
                  (a.protein - remainingProtein)) +
              ((a.fat - remainingFat) * (a.fat - remainingFat));

      final bRemainError =
          ((b.carbs - remainingCarbs) * (b.carbs - remainingCarbs)) +
              ((b.protein - remainingProtein) *
                  (b.protein - remainingProtein)) +
              ((b.fat - remainingFat) * (b.fat - remainingFat));

      return aRemainError.compareTo(bRemainError);
    } else {
      final aError = (aProtein - targetProtein) * (aProtein - targetProtein) +
          (aCarbs - targetCarbs) * (aCarbs - targetCarbs) +
          (aFat - targetFat) * (aFat - targetFat);

      final bError = (bProtein - targetProtein) * (bProtein - targetProtein) +
          (bCarbs - targetCarbs) * (bCarbs - targetCarbs) +
          (bFat - targetFat) * (bFat - targetFat);

      return aError.compareTo(bError);
    }
  });

  return filtered;
}

// Layanan utama untuk akses Firestore.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // late final: baru jalan pas pertama kali kepake, jadi FakeFirestoreService()
  // aman di-construct di test tanpa Firebase ke-init.
  late final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _random = Random();

  // Ubah FoodItem menjadi map (serialisasi untuk isolate).
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
        'alergen': f.alergen,
      };

    // Ubah map kembali menjadi FoodItem.
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
        alergen: List<String>.from(m['alergen'] as List? ?? []),
      );

  // Cache sederhana untuk mengurangi beban fetch berulang
  List<FoodItem>? _cachedFoodItems;

  // Hapus cache makanan (dipakai saat data berubah atau mau fetch ulang).
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
          .collection('users')
          .doc(uid)
          .collection('measurements')
          .doc(docId)
          .set({
        'date': now,
        'weight': weight,
        'bmi': bmi,
        'tdee': tdee,
        'goal': goal,
        'createdAt': now,
      });

      debugPrint('Measurement saved to Firestore');
    } catch (e) {
      debugPrint('Error saving measurement: $e');
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
          .collection('users')
          .doc(uid)
          .collection('preferences')
          .doc('macros')
          .set({
        'carbPercent': carbPercent,
        'proteinPercent': proteinPercent,
        'fatPercent': fatPercent,
        'updatedAt': Timestamp.now(),
      });
      debugPrint('Macro preferences saved to Firestore');
    } catch (e) {
      debugPrint('Error saving macro preferences: $e');
    }
  }

  // Load macro preferences from Firestore (returns null if not found)
  Future<MacroNutrient?> loadMacroPreferences(String uid) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('preferences')
          .doc('macros')
          .get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
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
      debugPrint('Error loading macro preferences: $e');
      return null;
    }
  }

  // Load user profile from /users/{uid} (one-time read)
  // Returns null if not found
  Future<Map<String, dynamic>?> loadUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;

      // Normalize keys we use in the app
      final profile = <String, dynamic>{};
      if (data.containsKey('weightKg')) profile['weightKg'] = data['weightKg'];
      if (data.containsKey('heightCm')) profile['heightCm'] = data['heightCm'];
      if (data.containsKey('tanggalLahir')) {
        final tgl = data['tanggalLahir'];
        // Firestore menyimpan sebagai Timestamp; ubah ke DateTime agar
        // mudah dipakai di sisi Flutter.
        profile['tanggalLahir'] = (tgl is Timestamp) ? tgl.toDate() : tgl;
      }
      if (data.containsKey('gender')) profile['gender'] = data['gender'];
      if (data.containsKey('activityLevel')) {
        profile['activityLevel'] = data['activityLevel'];
      }
      if (data.containsKey('allergies')) profile['alergi'] = data['allergies'];

      return profile;
    } catch (e) {
      debugPrint('Error loading user profile: $e');
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
      return doc.data();
    } catch (e) {
      debugPrint('Error loading last measurement: $e');
      return null;
    }
  }

  // Fetch semua food items dari Firestore
  Future<List<FoodItem>> getAllFoodItems() async {
    try {
      if (_cachedFoodItems != null && _cachedFoodItems!.isNotEmpty) {
        return _cachedFoodItems!;
      }

      QuerySnapshot snapshot = await _db.collection('makanan').get();

      _cachedFoodItems =
          snapshot.docs.map((doc) => FoodItem.fromFirestore(doc)).toList();
      return _cachedFoodItems!;
    } catch (e) {
      debugPrint("Error fetching all food items: $e");
      return [];
    }
  }

  // Fetch food items by category for swapping
  Future<List<FoodItem>> getFoodCandidates(String category,
      {List<String>? excludeAllergens}) async {
    final allFoods = await getAllFoodItems();

    // Filter di aplikasi (bukan di database) supaya hemat read.
    // Swap otomatis hanya boleh mengambil menu siap makan.
    return allFoods
        .where((item) => item.kategori.toLowerCase() == category.toLowerCase())
        .where((item) => !item.matchesAllergens(excludeAllergens))
        .where((item) {
          final kond = item.kondisi.toLowerCase();
          final cat = item.kategori.toLowerCase();
          return kond == 'matang' ||
              kond == 'olahan' ||
              cat == 'buah' ||
              cat == 'minuman';
        })
        .where((item) => item.calories > 0)
        .toList();
  }

  // Group and filter foods to build balanced menus
  Future<Map<String, List<FoodItem>>> getBalancedFoods(
      {List<String>? excludeAllergens}) async {
    final all = await getAllFoodItems();

    // Rule-based filter: tolak item yang tidak layak dan pilih kategori sehat.
    final edible = all.where((f) {
      final k = f.kategori.toLowerCase();
      final kond = f.kondisi.toLowerCase();
      final n = f.name.toLowerCase();

      if (f.matchesAllergens(excludeAllergens)) {
        return false;
      }

      // yang masuk daftar blacklist (Bahan mentah non-lauk)
      bool isBanned = n.contains('tepung') ||
          n.contains('minyak') ||
          n.contains('bumbu') ||
          n.contains('penyedap') ||
          n.contains('santan') ||
          n.contains('bubuk') ||
          n.contains('beras'); // Beras diban, Nasi diizinkan

      if (isBanned) {
        return false;
      }

      // Keep only edible items: Matang / Olahan, Mentah (Lauk), or Buah/Minuman
      return kond == 'matang' ||
          kond == 'olahan' ||
          k == 'buah' ||
          k == 'minuman';
    }).toList();

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
  // 'ratios' (opsional) untuk prioritas nutrisi
  Future<List<FoodItem>> generateMealPlan(int targetCalories,
      {Map<String, double>? ratios, List<String>? excludeAllergens}) async {
    final cats = await getBalancedFoods(excludeAllergens: excludeAllergens);
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

    return result.map((m) => FoodItem.fromMap(m)).toList();
  }

  // ===== SNACK RECOMMENDATION METHODS =====
  // Based on research (Bermingham et al., 2024; Almoraie et al., 2021)
  // High-quality snacks = whole foods with high nutrient density
  // Snack recommendations = emphasis on protein quality for satiety & appetite control
  // Klasifikasi dan hitung persen makro ada di top-level (di atas class ini).

  /// Get high-quality snacks filtered by target calories
  ///
  /// Returns list of snacks that are:
  /// - Whole foods (fruits, vegetables, nuts, seeds, dairy)
  /// - Close to target calorie range (0% first, then ±15% fallback)
  /// - Sorted by calorie proximity (closest calories first)
  Future<List<FoodItem>> getHighQualitySnacks(int targetCalories,
      {List<String>? excludeAllergens}) async {
    try {
      final allFoods = await getAllFoodItems();
      return filterHighQualitySnacks(allFoods, targetCalories,
          excludeAllergens: excludeAllergens);
    } catch (e) {
      debugPrint('Error getting high-quality snacks: $e');
      return [];
    }
  }

  /// Rekomendasi snack berbasis aturan.
  ///
  /// Filter snack sehat, pilih menu yang memenuhi target kalori dan makro,
  /// serta hindari overshoot macro.
  Future<List<FoodItem>> getSnackRecommendations(int targetCalories,
      {MacroNutrient? macroPrefs,
      int? dailyTargetCal,
      double? dailyTargetCarbs,
      double? dailyTargetProtein,
      double? dailyTargetFat,
      Map<String, double>? macrosEaten,
      List<String>? excludeAllergens}) async {
    try {
      final allFoods = await getAllFoodItems();
      return filterSnackRecommendations(
        allFoods,
        targetCalories,
        macroPrefs: macroPrefs,
        dailyTargetCal: dailyTargetCal,
        dailyTargetCarbs: dailyTargetCarbs,
        dailyTargetProtein: dailyTargetProtein,
        dailyTargetFat: dailyTargetFat,
        macrosEaten: macrosEaten,
        excludeAllergens: excludeAllergens,
      );
    } catch (e) {
      debugPrint('Error getting snack recommendations: $e');
      return [];
    }
  }

  // ===== DAILY MENU PERSISTENCE =====
  // Buat key tanggal untuk menu harian.
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

      final itemsData = items
          .map((f) => {
                'id': f.id,
                'name': f.name,
                'kategori': f.kategori,
                'kondisi': f.kondisi,
                'calories': f.calories,
                'protein': f.protein,
                'carbs': f.carbs,
                'fat': f.fat,
                'imageUrl': f.imageUrl ?? '',
                'alergen': f.alergen,
              })
          .toList();

      await docRef.set({
        section: itemsData,
        'goal': goal,
        'tdee': tdee,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      debugPrint(' Menu $section saved for ${_todayKey()}');
    } catch (e) {
      debugPrint(' Error saving section menu: $e');
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
      debugPrint(' Error loading daily menu: $e');
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
      debugPrint(' Error parsing food items: $e');
      return [];
    }
  }
}