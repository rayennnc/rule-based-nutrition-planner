import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/calculator_service.dart';
import '../services/firestore_service.dart';
import '../services/macro_nutrient.dart';
import '../services/local_storage_service.dart';
import '../screens/macro_customization.dart';
import '../screens/food_search.dart';
import '../auth/auth_service.dart';
import '../widgets/meal_item_card.dart';
import '../widgets/food_image.dart';
import 'package:provider/provider.dart';
import '../models/profile_notifier.dart';
import '../view_models/results_view_model.dart';

class ResultsScreen extends StatefulWidget {
  final CalculatorService calculator;

  const ResultsScreen({super.key, required this.calculator});

  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _breakfastDone = false;
  bool _morningSnackDone = false;
  bool _lunchDone = false;
  bool _afternoonSnackDone = false;
  bool _dinnerDone = false;

  final Map<String, bool> _expandedSections = {
    'Sarapan (06.00 - 09.00 Pagi)': false,
    'Camilan Pagi (10.00 Pagi)': false,
    'Makan Siang (12.00 - 15.00)': false,
    'Camilan Sore (16.00)': false,
    'Makan Malam  (selesai sebelum 19.00)': false,
  };

  late final ResultsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ResultsViewModel(
      calculator: widget.calculator,
      firestoreService: FirestoreService(),
      storageService: LocalStorageService(),
      authService: AuthService(),
      getUid: () => FirebaseAuth.instance.currentUser?.uid,
    );
    _vm.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm.attachProfile(Provider.of<ProfileNotifier?>(context));
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _openMacroCustomization() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MacroCustomizationScreen(
          tdee: _vm.baseCalories,
          onSave: (macro) {
            _vm.applyMacro(macro);

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
      await _vm.signOut();
      if (mounted) {
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
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Hitung'),
        elevation: 0,
        actions: [
          // 1. TOMBOL SEARCH BARU
          if (_vm.selectedGoal != null)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Ubah Tujuan Diet',
              onPressed: _vm.resetGoal,
            ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Cari Makanan',
            onPressed: () async {
              // Ambil data dulu (cepat kok)
              // Kalau mau lebih cepat lagi, load data ini di initState
              final filteredFoods = await _vm.loadSearchableFoods();
              showSearch(
                context: context,
                delegate: FoodSearch(
                  foodList: filteredFoods,
                  onItemTap: (item) {
                    // Reuse fungsi popup detail kamu yang canggih itu!
                    _showFoodDetail(context, item);
                  },
                  allergens: _vm.excludeAllergies,
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
                'Indeks Massa Tubuh (IMT)', _vm.bmi.toString(), _vm.bmiCategory),
            const SizedBox(height: 16),
            _buildTdeeCard(),
            const SizedBox(height: 12),
            if (_vm.loadingLastMeasurement)
              const Center(
                  child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(),
              )),
            if (!_vm.loadingLastMeasurement && _vm.lastMeasurement != null) ...[
              _buildLastMeasurementCard(),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 24),
            if (_vm.selectedGoal == null) _buildGoalSelection(),
            if (_vm.selectedGoal != null && _vm.finalCalories != null) ...[
              _buildMacroSummary(),
              const SizedBox(height: 12),
              _buildMealProgressSummary(),
              const SizedBox(height: 16),
              _buildMealPlan(),
            ],
          ],
        ),
      ),
    );
  }
  Widget _buildLastMeasurementCard() {
    if (_vm.lastMeasurement == null) return const SizedBox.shrink();

    final weight = _vm.lastMeasurement!['weight']?.toString() ?? '-';
    final bmi = _vm.lastMeasurement!['bmi']?.toString() ?? '-';
    final tdee = _vm.lastMeasurement!['tdee']?.toString() ?? '-';
    final ts = _vm.lastMeasurement!['createdAt'];
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Berat: $weight kg'),
                      Text('IMT: $bmi'),
                      Text('TDEE: $tdee kkal'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    dateStr.isNotEmpty
                        ? dateStr.split(' ')[0]
                        : '', // Show only date part
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSelection() {
    bool canLose = !_vm.bmiCategory.toLowerCase().contains('kurus') &&
        !_vm.bmiCategory.toLowerCase().contains('underweight');
    bool canMaintain = true;
    bool canGain = !_vm.bmiCategory.toLowerCase().contains('overweight') &&
        !_vm.bmiCategory.toLowerCase().contains('obesitas');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pilih Tujuan Utama',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (canLose) ...[
          _buildGoalButton('Menurunkan Berat Badan',
              'Defisit Kalori 500kal/hari', DietGoal.lose),
          const SizedBox(height: 12),
        ],
        if (canMaintain)
          _buildGoalButton(
              'Mempertahankan Berat Badan', 'Sesuai TDEE', DietGoal.maintain),
        if (canMaintain) const SizedBox(height: 12),
        if (canGain)
          _buildGoalButton('Menaikkan Berat Badan',
              'Surplus Kalori 500kal/hari', DietGoal.gain),
      ],
    );
  }

  Widget _buildGoalButton(String title, String subtitle, DietGoal goal) {
    return OutlinedButton(
      onPressed: () => _vm.setDietGoal(goal),
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
    final int baseCalories = _vm.baseCalories;
    int breakfastCals = (baseCalories * 0.20).round();
    int lunchCals = (baseCalories * 0.30).round();
    int dinnerCals = (baseCalories * 0.30).round();

    int morningSnackCals = (baseCalories * 0.10).round();
    int afternoonSnackCals = (baseCalories * 0.10).round();

    return Column(
      children: [
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
    final isExpanded = _expandedSections[title] ?? false;

    return ExpansionTile(
      title: Row(
        children: [
          Checkbox(
            value: done,
            onChanged: onToggle,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
            tooltip: "Acak Ulang Menu",
            onPressed: () => _vm.refreshMeal(title, targetCalories),
          ),
        ],
      ),
      initiallyExpanded: isExpanded,
      onExpansionChanged: (expanded) {
        setState(() => _expandedSections[title] = expanded);
      },
      children: [
        FutureBuilder<List<FoodItem>>(
          future: _vm.mealFuture(title, targetCalories),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Tidak ada rekomendasi makanan ditemukan.'),
              );
            }

            var combination = snapshot.data!;
            // Update tracking untuk sumber kebenaran nutrisi harian
            // dan nilai awal nutrisi tiap item di section ini
            _vm.trackMealSection(title, combination);
            int totalCals =
                combination.fold<int>(0, (sum, item) => sum + item.calories);

            // ✨ PENTING: Update totals langsung setelah meals dimuat
            // Sehingga ringkasan harian terupdate tanpa perlu user buka cards
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _vm.updateTotals();
            });

            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Total Opsi Ini: $totalCals kkal",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...combination.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final key = '$title-$idx';

                    return MealItemCard(
                      foodItem: item,
                      category: item.kategori,
                      excludedAllergens: _vm.excludeAllergies,
                      onNutritionChanged: (c, p, carbs, fat) =>
                          _vm.setCardNutrition(key, c, p, carbs, fat),
                    );
                  }).toList(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

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

  Widget _buildSnackSection(String title, int targetCalories, bool done,
      ValueChanged<bool?> onToggle) {
    final isExpanded = _expandedSections[title] ?? false;

    return ExpansionTile(
      title: Row(
        children: [
          Checkbox(
            value: done,
            onChanged: onToggle,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            tooltip: "Acak Ulang Snack",
            onPressed: () => _vm.refreshSnack(title, targetCalories),
          ),
        ],
      ),
      initiallyExpanded: isExpanded,
      onExpansionChanged: (expanded) {
        setState(() => _expandedSections[title] = expanded);
      },
      children: [
        FutureBuilder<List<FoodItem>>(
          future: _vm.snackFuture(title, targetCalories),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Rekomendasi snack tidak ditemukan.',
                    style: TextStyle(color: Colors.orange)),
              );
            }

            var snackItems = snapshot.data!;
            _vm.trackSnackSection(title, snackItems);

            final int displayedSnackCal = targetCalories;
            final FoodItem mainItem = snackItems.first;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _vm.trackSnackMain(title, mainItem);
            });

            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  MealItemCard(
                    foodItem: mainItem,
                    category: mainItem.kategori,
                    excludedAllergens: _vm.excludeAllergies,
                    selectable: false,
                    isSelected: false,
                    onNutritionChanged: (c, p, carbs, fat) => _vm
                        .setCardNutrition('snack-$title', c, p, carbs, fat),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

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
                            ? buildFoodImage(item.imageUrl!)
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

  // Tampilkan ringkasan kebutuhan dan konsumsi nutrisi harian.
  // menampilkan modal sheet ringkasan nutrisi harian
  void _showNutritionDetail() {
    // tampilkan detail nutrisi harian berdasarkan ratio yang dipilih atau default
    final int baseCalories = _vm.baseCalories;
    final macro = _vm.effectiveMacro;
    final proteinPerc = macro?.proteinPercent ?? 30.0;
    final carbPerc = macro?.carbPercent ?? 40.0; // default ratios
    final fatPerc = macro?.fatPercent ?? 30.0;

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
                    valueListenable: _vm.totals,
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

    // Buat bar indikator untuk satu jenis makronutrien.
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

  // Tampilkan kotak ringkas untuk nilai gizi.
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

  // Tampilkan kartu ringkasan IMT.
  // specialized card for displaying IMT
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

  // Tampilkan kartu TDEE dengan penjelasan BMR.
  // specialized card for displaying TDEE with explanation
  Widget _buildTdeeCard() {
    final level = _vm.calculator.activityLevel;
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
              _vm.tdee.toString(),
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
              'BMR: ${_vm.bmr.toStringAsFixed(1)}$factorText',
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

  // Ubah level aktivitas menjadi faktor pengali BMR.
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

  // Tampilkan ringkasan makronutrien yang dipilih.
  Widget _buildMacroSummary() {
    final macro = _vm.effectiveMacro ??
        MacroNutrient(
            carbPercent: 50.0,
            proteinPercent: 25.0,
            fatPercent: 25.0); // fallback default
    final int baseCalories = _vm.baseCalories;
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

  // Tampilkan satu item ringkasan makro.
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