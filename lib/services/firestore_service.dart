import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

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
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _random = Random(); // Untuk randomisasi

  // Fetch semua food items dari Firestore
  Future<List<FoodItem>> getAllFoodItems() async {
    try {
      QuerySnapshot snapshot = await _db.collection('makanan').get();
      return snapshot.docs.map((doc) => FoodItem.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching all food items: $e");
      return [];
    }
  }

  // Group and filter foods to build balanced menus
  Future<Map<String, List<FoodItem>>> getBalancedFoods() async {
    final all = await getAllFoodItems();

    // Filter untuk makanan yang tidak bisa dimakan
    final edible = all.where((f) {
      final k = f.kategori.toLowerCase();
      final kond = f.kondisi.toLowerCase();
      final n = f.name.toLowerCase(); // Check nama

      // yang masuk daftar blacklist
      bool isBanned = n.contains('tepung') ||
          n.contains('minyak') ||
          n.contains('bumbu') ||
          n.contains('penyedap') ||
          n.contains('santan') ||
          n.contains('bubuk') ||
          n.contains('beras');

      if (isBanned) {
        return false; // Membuang item yang termasuk di daftar blacklist
      }
      
      // Keep only edible items: Matang / Olahan, or Buah/Minuman
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
              'beras',
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

    // Acak urutan list supaya pencarian tidak selalu dimulai dari item yang sama
    // Ini membantu variasi jika kandidat sangat sedikit
    karbo.shuffle();
    protein.shuffle();
    sayur.shuffle();

    return {
      'karbo': karbo,
      'protein': protein,
      'sayur': sayur,
    };
  }

  // Generate balanced meal plan
  Future<List<FoodItem>> generateMealPlan(int targetCalories) async {
    final cats = await getBalancedFoods();
    final karbo = cats['karbo'] ?? [];
    final lauk = cats['protein'] ?? [];
    final sayur = cats['sayur'] ?? [];

    if (karbo.isEmpty || lauk.isEmpty) return [];

    // List untuk menampung SEMUA kombinasi yang "Cukup Bagus"
    List<List<FoodItem>> candidates = [];

    // Variabel fallback (cadangan) jika tidak ada kandidat yang pas
    List<FoodItem> bestFallback = [];
    int bestDiffFallback = 99999;

    // Toleransi kalori yang dianggap "Bagus" (misal +/- 50 kalori)
    // Semakin besar angkanya, semakin banyak variasi menu, tapi kalori makin kurang akurat.
    int tolerance = 50;

    // A. Coba Kombinasi 3 Item (Karbo + Lauk + Sayur)
    if (sayur.isNotEmpty) {
      for (var k in karbo) {
        for (var p in lauk) {
          for (var s in sayur) {
            if (k.id == p.id || k.id == s.id || p.id == s.id) continue;

            final total = k.calories + p.calories + s.calories;
            final diff = (targetCalories - total).abs();

            // 1. Jika masuk toleransi, masukkan ke kandidat pool
            if (diff <= tolerance) {
              candidates.add([k, p, s]);
            }

            // 2. Simpan juga yang terbaik absolut sebagai cadangan
            if (diff < bestDiffFallback) {
              bestDiffFallback = diff;
              bestFallback = [k, p, s];
            }
          }
        }
      }
    }

    // B. Coba Kombinasi 2 Item (Karbo + Lauk)
    // Jika kandidat 3 item masih sedikit (kurang dari 3 opsi), cari juga dari 2 item
    if (candidates.length < 3) {
      for (var k in karbo) {
        for (var p in lauk) {
          if (k.id == p.id) continue;

          final total2 = k.calories + p.calories;
          final diff2 = (targetCalories - total2).abs();

          if (diff2 <= tolerance) {
            candidates.add([k, p]);
          }

          // Cek fallback, prioritas sedikit lebih rendah dari 3 item
          // Kita pilih 2 item jika selisihnya JAUH lebih baik daripada 3 item terbaik
          if (diff2 < bestDiffFallback && (bestDiffFallback - diff2 > 30)) {
            bestDiffFallback = diff2;
            bestFallback = [k, p];
          }
        }
      }
    }

    // LOGIC FINAL: MEMILIH PEMENANG
    if (candidates.isNotEmpty) {
      // Jika ada kandidat bagus, PILIH SECARA ACAK
      return candidates[_random.nextInt(candidates.length)];
    } else {
      // Jika tidak ada yang masuk toleransi, pakai yang terbaik absolut (fallback)
      if (bestFallback.isNotEmpty) {
        return bestFallback;
      }

      // Fallback terakhir: 1 item terdekat
      final allEdible = [...karbo, ...lauk];
      if (allEdible.isNotEmpty) {
        return [
          allEdible.reduce((a, b) => (a.calories - targetCalories).abs() <
                  (b.calories - targetCalories).abs()
              ? a
              : b)
        ];
      }

      return [];
    }
  }
}
