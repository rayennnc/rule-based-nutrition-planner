import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/calculator_service.dart';
import '../services/firestore_service.dart';
import '../services/macro_nutrient.dart'; // add import
import '../services/local_storage_service.dart';
import '../screens/macro_customization.dart'; // add import
import '../screens/food_search.dart'; // add import
import '../screens/input_form_screen.dart'; // add import
import '../auth/auth_service.dart';
import '../widgets/meal_item_card.dart'; // add import

class ResultsScreen extends StatefulWidget {
  final CalculatorService calculator;

  const ResultsScreen({super.key, required this.calculator});

  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late double _bmi;
  late String _bmiCategory;
  late double _bmr; // store BMR for display
  late int _tdee;

  DietGoal? _selectedGoal;
  int? _finalCalories;
  MacroNutrient? _selectedMacro; // add this
  MacroNutrient? _loadedMacro; // prefs loaded from local/firestore

  // simple meal & snack progress trackers
  bool _breakfastDone = false;
  bool _morningSnackDone = false;
  bool _lunchDone = false;
  bool _afternoonSnackDone = false;
  bool _dinnerDone = false;

  // Key untuk mengrefresh Menu
  int _refreshKey = 0;
  // cache for snack recommendation futures to prevent UI flicker
  final Map<String, Future<List<FoodItem>>> _snackFutures = {};

  // Last measurement cache
  Map<String, dynamic>? _lastMeasurement;
  bool _loadingLastMeasurement = true;

  // notifier for daily nutrient totals so UI can listen live
  final ValueNotifier<Map<String, double>> _totalsNotifier =
      ValueNotifier(<String, double>{});

  // ===== NEW: state untuk menyimpan nutrisi aktual setiap card =====
  // kunci dibentuk dari kombinasi section-title & index agar unik
  final Map<String, Map<String, double>> _currentMealsData = {};

  // Snack UI state is now simplified; recommendation is automatically applied without user selection.
  // (previously we tracked expansion and selected item, but those are removed)

  // Cache for meal plan futures so rebuilds don't re-trigger generation
  final Map<String, Future<List<FoodItem>>> _mealFutures = {};

  // Cache menu harian dari Firestore
  Map<String, dynamic>? _dailyMenuCache;
  bool _loadingDailyMenu = true;

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService(); // add this
  final LocalStorageService _storageService = LocalStorageService();

  @override
  void initState() {
    super.initState();
    _bmi = widget.calculator.calculateBmi();
    _bmiCategory = widget.calculator.getBmiCategory(_bmi);
    _bmr = widget.calculator.calculateBmr();
    _tdee = widget.calculator.calculateTdee();
    _loadLastMeasurement();
    _loadMacroPreferences();
    _loadDailyMenuCache();
    // initial totals
    _updateTotals();
  }

  /// Load menu harian dari Firestore
  Future<void> _loadDailyMenuCache() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingDailyMenu = false);
      return;
    }
    final data = await _firestoreService.loadDailyMenu(uid);
    if (mounted) {
      setState(() {
        _loadingDailyMenu = false;

        // Validasi TDEE — kalau berbeda dari yang tersimpan, abaikan menu lama
        if (data != null) {
          final savedTdee = (data['tdee'] as num?)?.toInt();
          final currentTdee = _tdee;
          if (savedTdee != null && savedTdee != currentTdee) {
            // TDEE berbeda → data tidak valid, generate ulang
            debugPrint('⚠️ TDEE berubah ($savedTdee → $currentTdee), menu lama diabaikan');
            _dailyMenuCache = null;
            return;
          }
        }

        _dailyMenuCache = data;

        // Auto-load goal dari daily menu kalau ada
        if (data != null && _selectedGoal == null) {
          final goalStr = data['goal'] as String?;
          DietGoal? autoGoal;
          if (goalStr == 'lose') autoGoal = DietGoal.lose;
          else if (goalStr == 'gain') autoGoal = DietGoal.gain;
          else if (goalStr == 'maintain') autoGoal = DietGoal.maintain;
          if (autoGoal != null) {
            _selectedGoal = autoGoal;
            _finalCalories = widget.calculator.getAdjustedCalories(autoGoal, _tdee);
          }
        }

        // Pre-populate _mealFutures dari cache Firestore
        if (data != null) {
          for (final section in ['Sarapan (06.00 - 09.00 Pagi)', 'Makan Siang (12.00 - 15.00)', 'Makan Malam  (selesai sebelum 19.00)']) {
            if (data.containsKey(section)) {
              final items = _firestoreService.parseFoodItems(data[section]);
              if (items.isNotEmpty) {
                _mealFutures[section] = Future.value(items);
              }
            }
          }
          for (final section in ['Camilan Pagi (10.00 Pagi)', 'Camilan Sore (16.00)']) {
            if (data.containsKey(section)) {
              final items = _firestoreService.parseFoodItems(data[section]);
              if (items.isNotEmpty) {
                _snackFutures[section] = Future.value(items);
              }
            }
          }
        }
      });
      _updateTotals();
    }
  }

  Future<void> _loadMacroPreferences() async {
    // Try local cache first
    try {
      final local = await _storageService.loadMacroPreferencesLocal();
      if (local != null && local.isNotEmpty) {
        final c = local['carbPercent'] ?? local['carb'] ?? 0.0;
        final p = local['proteinPercent'] ?? local['protein'] ?? 0.0;
        final f = local['fatPercent'] ?? local['fat'] ?? 0.0;
        setState(() {
          _loadedMacro =
              MacroNutrient(carbPercent: c, proteinPercent: p, fatPercent: f);
        });
        return;
      }
    } catch (_) {}

    // Fallback: try remote (single read)
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final remote = await _firestoreService.loadMacroPreferences(uid);
        if (remote != null) {
          setState(() => _loadedMacro = remote);
          // also save locally for faster next load
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
    setState(() => _loadingLastMeasurement = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingLastMeasurement = false);
      return;
    }
    final data = await _firestoreService.loadLastMeasurement(uid);
    if (mounted) {
      setState(() {
        _lastMeasurement = data;
        _loadingLastMeasurement = false;
      });
    }
  }

  void _setDietGoal(DietGoal goal) {
    setState(() {
      _selectedGoal = goal;
      _finalCalories = widget.calculator.getAdjustedCalories(goal, _tdee);
      // keep selected/loaded macro so the summary remains visible
    });
    _updateTotals();

    // Simpan measurement ke Firestore
    _saveMeasurementToFirestore(goal);
  }

  // Simpan measurement (BMI, weight, TDEE, goal) ke Firestore
  Future<void> _saveMeasurementToFirestore(DietGoal goal) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final goalStr =
          goal.toString().split('.').last; // "lose" / "maintain" / "gain"

      await _firestoreService.saveMeasurement(
        uid: uid,
        weight: widget.calculator.weight,
        bmi: _bmi,
        tdee: _tdee,
        goal: goalStr,
      );
    } catch (e) {
      debugPrint('❌ Error in _saveMeasurementToFirestore: $e');
    }
  }

  void _openMacroCustomization() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MacroCustomizationScreen(
          tdee: _finalCalories ?? _tdee,
          onSave: (macro) {
            // When user saves macro prefs, store it and force meal plan refresh
            setState(() {
              _selectedMacro = macro;
              // Invalidate cached meal futures so they regenerate with new ratios
              _mealFutures.clear();
            });

            // Also clear FirestoreService in-memory cache if needed
            try {
              _firestoreService.clearCache();
            } catch (_) {}

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Preferensi disimpan — menu akan direfresh')),
            );
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await _storageService.hapusDataUser();
      await _authService.signOut();
      if (mounted) {
        // Kembali ke halaman Welcome dan hapus semua rute sebelumnya
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/welcome', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logout error: $e')));
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Hitung'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Hitung Ulang',
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const InputFormScreen()),
              (route) => false,
            );
          },
        ),
        actions: [
          // 1. TOMBOL SEARCH BARU
          if (_selectedGoal != null)
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Ubah Tujuan Diet',
            onPressed: () {
              setState(() {
                _selectedGoal = null;
                _finalCalories = null;
                _mealFutures.clear();
                _currentMealsData.clear();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Cari Makanan',
            onPressed: () async {
              // TAMBAHKAN 1 BARIS INI UNTUK DEMO
              _firestoreService.clearCache(); // Paksa hapus ingatan lama HP
              // Ambil data dulu (cepat kok)
              // Kalau mau lebih cepat lagi, load data ini di initState
              final allFoods = await _firestoreService.getAllFoodItems();
              showSearch(
                context: context,
                delegate: FoodSearch(
                  foodList: allFoods,
                  onItemTap: (item) {
                    // Reuse fungsi popup detail kamu yang canggih itu!
                    _showFoodDetail(context, item);
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildResultCard(
                'Indeks Massa Tubuh (IMT)', _bmi.toString(), _bmiCategory),
            const SizedBox(height: 16),
            // show a custom card that includes BMR explanation
            _buildTdeeCard(),
            const SizedBox(height: 12),
            if (_loadingLastMeasurement)
              const Center(
                  child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(),
              )),
            if (!_loadingLastMeasurement && _lastMeasurement != null) ...[
              _buildLastMeasurementCard(),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 24),
            if (_selectedGoal == null) _buildGoalSelection(),
            if (_selectedGoal != null && _finalCalories != null) ...[
              // The summary card already includes an "Ubah" button to open
              // the customization screen.  The extra toolbar button above was
              // redundant and has been removed for a cleaner layout.
              _buildMacroSummary(), // always show summary (uses default if none saved)
              const SizedBox(height: 12),
              _buildMealProgressSummary(), // new progress indicator
              const SizedBox(height: 16),
              _buildMealPlan(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLastMeasurementCard() {
    if (_lastMeasurement == null) return const SizedBox.shrink();

    final weight = _lastMeasurement!['weight']?.toString() ?? '-';
    final bmi = _lastMeasurement!['bmi']?.toString() ?? '-';
    final tdee = _lastMeasurement!['tdee']?.toString() ?? '-';
    final ts = _lastMeasurement!['createdAt'];
    String dateStr = '';
    try {
      if (ts is Timestamp) {
        dateStr = DateTime.fromMillisecondsSinceEpoch(ts.millisecondsSinceEpoch)
            .toLocal()
            .toString();
      } else if (ts is String) {
        dateStr = ts;
      }
    } catch (_) {
      dateStr = '';
    }

    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pengukuran Terakhir',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Berat: $weight kg'),
                    Text('IMT: $bmi'),
                    Text('TDEE: $tdee kkal'),
                  ],
                ),
                Text(dateStr,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pilih Tujuan Utama',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _buildGoalButton('Menurunkan Berat Badan', 'Defisit Kalori 500kal/hari', DietGoal.lose),
        const SizedBox(height: 12),
        _buildGoalButton(
            'Mempertahankan Berat Badan', 'Sesuai TDEE', DietGoal.maintain),
        const SizedBox(height: 12),
        _buildGoalButton('Menaikkan Berat Badan', 'Surplus Kalori 500kal/hari', DietGoal.gain),
      ],
    );
  }

  Widget _buildGoalButton(String title, String subtitle, DietGoal goal) {
    return OutlinedButton(
      onPressed: () => _setDietGoal(goal),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        side: const BorderSide(color: Colors.green),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(color: Colors.black54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMealPlan() {
    // Calorie distribution based on proposal. Use final calories if set, otherwise TDEE
    final int baseCalories = _finalCalories ?? _tdee;
    int breakfastCals = (baseCalories * 0.20).round(); // 20%
    int lunchCals = (baseCalories * 0.30).round(); // 30%
    int dinnerCals = (baseCalories * 0.30).round(); // 30%

    // Snack allocation: 20% → 10% morning + 10% afternoon (per research)
    int morningSnackCals = (baseCalories * 0.10).round(); // 10%
    int afternoonSnackCals = (baseCalories * 0.10).round(); // 10%

    return Column(
      children: [
        // Tappable header yang membuka ringkasan nutrisi harian
        InkWell(
          onTap: _showNutritionDetail,
          child: Text(
            'Target Kalori Harian Anda: $baseCalories',
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        _buildMealSection('Sarapan (06.00 - 09.00 Pagi)', breakfastCals,
            _breakfastDone, (v) => setState(() => _breakfastDone = v ?? false)),
        _buildSnackSection(
            'Camilan Pagi (10.00 Pagi)',
            morningSnackCals,
            _morningSnackDone,
            (v) => setState(() => _morningSnackDone = v ?? false)),
        _buildMealSection('Makan Siang (12.00 - 15.00)', lunchCals, _lunchDone,
            (v) => setState(() => _lunchDone = v ?? false)),
        _buildSnackSection(
            'Camilan Sore (16.00)',
            afternoonSnackCals,
            _afternoonSnackDone,
            (v) => setState(() => _afternoonSnackDone = v ?? false)),
        _buildMealSection('Makan Malam  (selesai sebelum 19.00)', dinnerCals,
            _dinnerDone, (v) => setState(() => _dinnerDone = v ?? false)),
      ],
    );
  }

  Widget _buildMealSection(String title, int targetCalories, bool done,
      ValueChanged<bool?> onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: done,
                  onChanged: onToggle,
                ),
                SizedBox(
                  width: 8,
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    '$title (${targetCalories - 50}-${targetCalories + 50} kal)',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Tombol Refresh Menu — hanya invalidate cache untuk section ini
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.green),
              tooltip: "Acak Ulang Menu",
              onPressed: () {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                setState(() {
                  _mealFutures[title] = _firestoreService.generateMealPlan(
                    targetCalories,
                    ratios: _selectedMacro != null
                        ? {
                            'protein': _selectedMacro!.proteinPercent / 100,
                            'carbs': _selectedMacro!.carbPercent / 100,
                            'fat': _selectedMacro!.fatPercent / 100,
                          }
                        : null,
                  ).then((items) {
                    // Simpan menu baru ke Firestore setelah refresh
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
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<FoodItem>>(
          // Use cached future per section so it won't regenerate on every rebuild
          future: _mealFutures[title] ??= _firestoreService.generateMealPlan(
            targetCalories,
            ratios: _selectedMacro != null
                ? {
                    'protein': _selectedMacro!.proteinPercent / 100,
                    'carbs': _selectedMacro!.carbPercent / 100,
                    'fat': _selectedMacro!.fatPercent / 100,
                  }
                : null,
          ).then((items) {
            // Simpan menu ke Firestore saat pertama kali digenerate
            final uid = FirebaseAuth.instance.currentUser?.uid;
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
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Center(
                  child: Text('Tidak ada rekomendasi makanan ditemukan.'));
            }

            var combination = snapshot.data!;
            int totalCals =
                combination.fold<int>(0, (sum, item) => sum + item.calories);
            int diff = (targetCalories - totalCals).abs();

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  width: double.infinity,
                  color: Colors.green.withOpacity(0.1),
                  child: Text("Total Opsi Ini: $totalCals kkal",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green)),
                ),
                const SizedBox(height: 8),

                //FITUR UTAMA: MENGGUNAKAN MEAL ITEM CARD (BISA SWAP)
                ...combination.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final key = '$title-$idx';

                  // pastikan data awal tersimpan
                  _currentMealsData.putIfAbsent(
                      key,
                      () => {
                            'calories': item.calories.toDouble(),
                            'protein': item.protein.toDouble(),
                            'carbs': item.carbs.toDouble(),
                            'fat': item.fat.toDouble(),
                          });

                  return MealItemCard(
                    foodItem: item,
                    category: item.kategori,
                    onNutritionChanged: (c, p, carbs, fat) {
                      setState(() {
                        _currentMealsData[key] = {
                          'calories': c,
                          'protein': p,
                          'carbs': carbs,
                          'fat': fat,
                        };
                      });
                      _updateTotals(); // notify listeners
                    },
                  );
                }).toList(),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // simple summary bar showing number of meals ticked off
  Widget _buildMealProgressSummary() {
    int count = 0;
    if (_breakfastDone) count++;
    if (_morningSnackDone) count++;
    if (_lunchDone) count++;
    if (_afternoonSnackDone) count++;
    if (_dinnerDone) count++;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress Makan/Snack: $count dari 5',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: count / 5,
          backgroundColor: Colors.grey[200],
          color: Colors.green,
          minHeight: 6,
        ),
      ],
    );
  }

  // SNACK SECTION - High-Protein Recommendations
  // Based on research (Bermingham et al., 2024; Almoraie et al., 2021)
  // Snack quality emphasized: whole foods with protein >= 15%
  /// Helper untuk generate snack future (dipakai di refresh & generate pertama)
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
    final dailyTargetFat =
        (dailyCal * (macro?.fatPercent ?? 25.0) / 100) / 9;

    return _firestoreService.getHighProteinSnackRecommendations(
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
    );
  }

  Widget _buildSnackSection(String title, int targetCalories, bool done,
      ValueChanged<bool?> onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: done,
                  onChanged: onToggle,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Target: ${targetCalories - 20}-${targetCalories + 20} kal (High-Protein)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            // Refresh button
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.orange),
              tooltip: "Acak Ulang Snack",
              onPressed: () {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                setState(() {
                  _snackFutures[title] = _buildSnackFuture(title, targetCalories).then((items) {
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
                  _refreshKey++;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<FoodItem>>(
          future: _snackFutures.putIfAbsent(title, () {
            return _buildSnackFuture(title, targetCalories).then((items) {
              final uid = FirebaseAuth.instance.currentUser?.uid;
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
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                    'Rekomendasi snack berkualitas tinggi tidak ditemukan.',
                    style: TextStyle(color: Colors.orange)),
              );
            }

            var snackItems = snapshot.data!;

            // Don't sum all option calories (they are separate suggestions).
            // Show the target snack calories instead so the header matches the plan.
            final int displayedSnackCal = targetCalories;
            // simply pick the first recommendation as the snack
            final FoodItem mainItem = snackItems.first;

            // side effect: make sure snack macros are tracked so that
            // subsequent recommendations and the daily summary use real data
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final key = 'snack-$title';
              _currentMealsData[key] = {
                'calories': mainItem.calories.toDouble(),
                'protein': mainItem.protein.toDouble(),
                'carbs': mainItem.carbs.toDouble(),
                'fat': mainItem.fat.toDouble(),
              };
            });

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  width: double.infinity,
                  color: Colors.orange.withOpacity(0.15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Target Snack: $displayedSnackCal kkal",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        "Rekomendasi: Makanan berkualitas tinggi, protein ≥15%",
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // show recommended snack without selection ability
                MealItemCard(
                  foodItem: mainItem,
                  category: mainItem.kategori,
                  selectable: false,
                  isSelected: false,
                  onNutritionChanged: (c, p, carbs, fat) {
                    // snack key
                    final key = 'snack-$title';
                    setState(() {
                      _currentMealsData[key] = {
                        'calories': c,
                        'protein': p,
                        'carbs': carbs,
                        'fat': fat,
                      };
                    });
                    _updateTotals(); // update ringkasan nutrisi harian
                  },
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFoodItemRow(FoodItem item) {
    bool isMentah = item.kondisi.toLowerCase() == 'mentah';

    // Bungkus dengan InkWell agar bisa diklik
    return InkWell(
      onTap: () => _showFoodDetail(context, item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green.shade200, width: 1),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar Thumbnail
            Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.imageUrl != null
                    ? _buildImageWidget(item.imageUrl!)
                    : const Icon(Icons.fastfood, color: Colors.grey),
              ),
            ),

            // Info Makanan
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),

                  // Badge Status
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isMentah
                          ? Colors.orange.withOpacity(0.15)
                          : Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isMentah ? "Bahan Mentah" : "Siap Makan",
                      style: TextStyle(
                          fontSize: 10,
                          color:
                              isMentah ? Colors.deepOrange : Colors.blue[800],
                          fontWeight: FontWeight.bold),
                    ),
                  ),

                  Text(
                      'P: ${item.protein}g | K: ${item.carbs}g | L: ${item.fat}g',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),

            // Kalori
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${item.calories}',
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const Text('kkal',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Popup Detail Makanan (Modal Sheet)

  void _showFoodDetail(BuildContext context, FoodItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Gambar Besar
                  Center(
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.grey[100],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: item.imageUrl != null
                            ? _buildImageWidget(item.imageUrl!)
                            : const Icon(Icons.fastfood,
                                size: 80, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Judul
                  Text(item.name,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),

                  // Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Chip(
                        label: Text(item.kategori),
                        backgroundColor: Colors.green.withOpacity(0.1),
                        labelStyle: TextStyle(color: Colors.green[800]),
                      ),
                      const SizedBox(width: 10),
                      Chip(
                        label: Text(item.kondisi),
                        backgroundColor: item.kondisi.toLowerCase() == 'mentah'
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        labelStyle: TextStyle(
                            color: item.kondisi.toLowerCase() == 'mentah'
                                ? Colors.deepOrange
                                : Colors.blue[800]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Info Gizi Grid
                  const Text("Informasi Nilai Gizi (per 100g)",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNutrientBox("Kalori", "${item.calories}", "kkal",
                          Colors.redAccent),
                      _buildNutrientBox(
                          "Protein", "${item.protein}", "g", Colors.blueAccent),
                      _buildNutrientBox(
                          "Karbo", "${item.carbs}", "g", Colors.orange),
                      _buildNutrientBox(
                          "Lemak", "${item.fat}", "g", Colors.amber[700]!),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Catatan Edukasi
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueGrey.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blueGrey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.kondisi.toLowerCase() == 'mentah'
                                ? "Perhatian: Ini adalah berat bahan MENTAH. Pastikan Anda menimbang bahan ini sebanyak 100g sebelum dimasak untuk mendapatkan kalori yang akurat."
                                : "Makanan ini siap santap. Nikmati sesuai porsi yang dianjurkan.",
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Tutup"),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // hitung total nutrisi dari semua meal yang sudah di-generate
  Map<String, double> _calculateDailyTotals() {
    double calories = 0, protein = 0, carbs = 0, fat = 0;
    for (var m in _currentMealsData.values) {
      calories += m['calories'] ?? 0;
      protein += m['protein'] ?? 0;
      carbs += m['carbs'] ?? 0;
      fat += m['fat'] ?? 0;
    }
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  void _updateTotals() {
    _totalsNotifier.value = _calculateDailyTotals();
  }

  // menampilkan modal sheet ringkasan nutrisi harian
  void _showNutritionDetail() {
    final int baseCalories = _finalCalories ?? _tdee;
    final proteinPerc =
        _selectedMacro?.proteinPercent ?? _loadedMacro?.proteinPercent ?? 30.0;
    final carbPerc = _selectedMacro?.carbPercent ??
        _loadedMacro?.carbPercent ??
        40.0; // default ratios
    final fatPerc =
        _selectedMacro?.fatPercent ?? _loadedMacro?.fatPercent ?? 30.0;

    final macroService = MacroNutrient(
        proteinPercent: proteinPerc,
        carbPercent: carbPerc,
        fatPercent: fatPerc);
    final targets = macroService.calculateGrams(baseCalories);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Ringkasan Nutrisi Harian',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  // observe totals notifier for live updates
                  ValueListenableBuilder<Map<String, double>>(
                    valueListenable: _totalsNotifier,
                    builder: (context, totals, _) {
                      double actualCals = totals['calories'] ?? 0;
                      double actualProtein = totals['protein'] ?? 0;
                      double actualCarbs = totals['carbs'] ?? 0;
                      double actualFat = totals['fat'] ?? 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kalori',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(
                              '${actualCals.round()} / $baseCalories (${baseCalories > 0 ? (actualCals / baseCalories * 100).toStringAsFixed(0) : "0"}%)'),
                          const SizedBox(height: 12),
                          const SizedBox(height: 8),
                          _buildMacroRow('Protein', actualProtein,
                              targets['protein']!, proteinPerc),
                          _buildMacroRow('Karbs', actualCarbs,
                              targets['carbs']!, carbPerc),
                          const SizedBox(height: 8),
                          _buildMacroRow(
                              'Lemak', actualFat, targets['fat']!, fatPerc),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // helper bar grafik kecil
  Widget _buildMacroRow(
      String label, double actual, double target, double perc) {
    final percent = target > 0 ? (actual / target).clamp(0.0, 1.0) : 0.0;
    Color color;
    switch (label) {
      case 'Protein':
        color = Colors.purple;
        break;
      case 'Karbs':
        color = Colors.orange;
        break;
      default:
        color = Colors.teal;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            // display real realised percent (actual/target)
            '$label ${actual.round()}g ~ ${target.round()}g (${target > 0 ? (actual / target * 100).toStringAsFixed(0) : "0"}%)'),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percent,
          color: color,
          backgroundColor: Colors.grey[200],
          minHeight: 6,
        ),
      ],
    );
  }

  // Nutrient Info Box
  Widget _buildNutrientBox(
      String label, String value, String unit, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // Helper method to load image (supports data URL and external URL)
  Widget _buildImageWidget(String imageUrl) {
    // asset prefix is easiest for offline images
    if (imageUrl.startsWith('asset:')) {
      final assetPath = imageUrl.substring(6);
      return Image.asset(assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ));
    }

    if (imageUrl.startsWith('data:')) {
      // Data URL (base64)
      try {
        final base64Data = imageUrl.substring(imageUrl.indexOf(',') + 1);
        return Image.memory(
          Uri.parse(imageUrl).data!.contentAsBytes(),
          fit: BoxFit.cover,
        );
      } catch (e) {
        return const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        );
      }
    } else {
      // External URL
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
  }

  Widget _buildResultCard(String title, String value, String subtitle) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // specialized card for displaying TDEE with explanation
  Widget _buildTdeeCard() {
    final level = widget.calculator.activityLevel;
    String factorText = '';
    if (level != null) {
      // format multiplier with up to 3 decimals, but trim trailing zeros
      final f = _activityMultiplier(level);
      String formatted = f.toStringAsFixed(3);
      // remove trailing zeros and optional dot
      formatted = formatted.replaceAll(RegExp(r"\.?0+"), '');
      factorText = ' × $formatted';
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Rekomendasi Kalori Harian (TDEE)',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              _tdee.toString(),
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kalori',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Text(
              'BMR: ${_bmr.toStringAsFixed(1)}$factorText',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            const Text(
              'TDEE = BMR × faktor aktivitas',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // helper to convert activity enum to multiplier
  double _activityMultiplier(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.active:
        return 1.725;
      case ActivityLevel.veryActive:
        return 1.9;
    }
  }

  Widget _buildMacroSummary() {
    final macro = _selectedMacro ??
        _loadedMacro ??
        MacroNutrient(
            carbPercent: 50.0, proteinPercent: 25.0, fatPercent: 25.0);
    final int baseCalories = _finalCalories ?? _tdee;
    final grams = macro.calculateGrams(baseCalories);

    return Card(
      color: Colors.green.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Makronutrien Pilihan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMacroStat(
                    'Karbo',
                    '${macro.carbPercent.toStringAsFixed(1)}%',
                    '${grams['carbs']!.toStringAsFixed(0)}g'),
                _buildMacroStat(
                    'Protein',
                    '${macro.proteinPercent.toStringAsFixed(1)}%',
                    '${grams['protein']!.toStringAsFixed(0)}g'),
                _buildMacroStat(
                    'Lemak',
                    '${macro.fatPercent.toStringAsFixed(1)}%',
                    '${grams['fat']!.toStringAsFixed(0)}g'),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Ubah'),
              onPressed: _openMacroCustomization,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size.fromHeight(36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroStat(String label, String percent, String grams) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(percent,
            style: const TextStyle(
                fontSize: 16,
                color: Colors.green,
                fontWeight: FontWeight.bold)),
        Text(grams,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}