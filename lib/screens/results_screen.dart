import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/calculator_service.dart';
import '../services/firestore_service.dart';
import '../services/macro_nutrient.dart'; // add import
import '../screens/macro_customization.dart'; // add import
import '../screens/food_search.dart'; // add import
import '../auth/auth_service.dart';

class ResultsScreen extends StatefulWidget {
  final CalculatorService calculator;

  const ResultsScreen({super.key, required this.calculator});

  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late double _bmi;
  late String _bmiCategory;
  late int _tdee;

  DietGoal? _selectedGoal;
  int? _finalCalories;
  MacroNutrient? _selectedMacro; // add this

  // Key untuk mengrefresh Menu
  int _refreshKey = 0;

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService(); // add this

  @override
  void initState() {
    super.initState();
    _bmi = widget.calculator.calculateBmi();
    _bmiCategory = widget.calculator.getBmiCategory(_bmi);
    _tdee = widget.calculator.calculateTdee();
  }

  void _setDietGoal(DietGoal goal) {
    setState(() {
      _selectedGoal = goal;
      _finalCalories = widget.calculator.getAdjustedCalories(goal, _tdee);
      _selectedMacro = null; // reset macro when changing goal
    });
  }

  void _openMacroCustomization() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MacroCustomizationScreen(
          tdee: _finalCalories!,
          onSave: (macro) {
            setState(() => _selectedMacro = macro);
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        // Navigate to welcome screen & remove all routes
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
        actions: [
          // 1. TOMBOL SEARCH BARU
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Cari Makanan',
            onPressed: () async {
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
            _buildResultCard(
                'Rekomendasi Kalori Harian (TDEE)', _tdee.toString(), 'Kalori'),
            const SizedBox(height: 24),
            if (_selectedGoal == null) _buildGoalSelection(),
            if (_selectedGoal != null && _finalCalories != null) ...[
              if (_selectedMacro == null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.tune),
                  label: const Text('Kustomisasi Makronutrien'),
                  onPressed: _openMacroCustomization,
                ),
              const SizedBox(height: 16),
              if (_selectedMacro != null)
                _buildMacroSummary(), // add this widget
              _buildMealPlan(),
            ],
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
        _buildGoalButton('Menurunkan Berat Badan', 'Defisit Kalori 500kal/hari',
            DietGoal.lose),
        const SizedBox(height: 12),
        _buildGoalButton(
            'Mempertahankan Berat Badan', 'Sesuai TDEE', DietGoal.maintain),
        const SizedBox(height: 12),
        _buildGoalButton('Menaikkan Berat Badan',
            'Surplus Kalori 300-500kal/hari', DietGoal.gain),
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
    // Calorie distribution based on proposal
    int breakfastCals = (_finalCalories! * 0.25).round(); // 20-25%
    int lunchCals = (_finalCalories! * 0.35).round(); // 30-35%
    int dinnerCals = (_finalCalories! * 0.30).round(); // 30%
    // Snacks would be the remaining ~10-15%

    return Column(
      children: [
        Text(
          'Target Kalori Harian Anda: $_finalCalories',
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildMealSection('Sarapan', breakfastCals),
        _buildMealSection('Makan Siang', lunchCals),
        _buildMealSection('Makan Malam', dinnerCals),
      ],
    );
  }

  Widget _buildMealSection(String title, int targetCalories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$title (${targetCalories - 50}-${targetCalories + 50} kal)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // Tombol Refresh Menu
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.green),
              tooltip: "Acak Ulang Menu",
              onPressed: () {
                setState(() {
                  _refreshKey++; // Trigger rebuild
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 8),
        FutureBuilder<List<FoodItem>>(

          // Panggil generateMealPlan dari firestore_service.dart
          future: _firestoreService.generateMealPlan(targetCalories),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                  child: Text('Tidak ada rekomendasi makanan ditemukan.'));
            }

            var combination = snapshot.data!;
            int totalCals = combination.fold<int>(0, (sum, item) => sum + item.calories);
            int diff = (targetCalories - totalCals).abs();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display combination info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kombinasi ${combination.length} item',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Total: $totalCals kalori (selisih: $diff kal)',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Display food items in combination
                Column(
                  children: combination.map((item) => _buildFoodItemRow(item)).toList(),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),

                  // Badge Status
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isMentah ? Colors.orange.withOpacity(0.15) : Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isMentah ? "Bahan Mentah" : "Siap Makan",
                      style: TextStyle(
                        fontSize: 10,
                        color: isMentah ? Colors.deepOrange : Colors.blue[800],
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),

                  Text('P: ${item.protein}g | K: ${item.carbs}g | L: ${item.fat}g',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            
            // Kalori
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${item.calories}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
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
                      width: 40, height: 5,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
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
                          : const Icon(Icons.fastfood, size: 80, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Judul
                  Text(item.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
                            color: item.kondisi.toLowerCase() == 'mentah' ? Colors.deepOrange : Colors.blue[800]
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Info Gizi Grid
                  const Text("Informasi Nilai Gizi (per 100g)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNutrientBox("Kalori", "${item.calories}", "kkal", Colors.redAccent),
                      _buildNutrientBox("Protein", "${item.protein}", "g", Colors.blueAccent),
                      _buildNutrientBox("Karbo", "${item.carbs}", "g", Colors.orange),
                      _buildNutrientBox("Lemak", "${item.fat}", "g", Colors.amber[700]!),
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
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
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

  // Nutrient Info Box
  Widget _buildNutrientBox(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // Helper method to load image (supports data URL and external URL)
  Widget _buildImageWidget(String imageUrl) {
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

  Widget _buildMacroSummary() {
    final grams = _selectedMacro!.calculateGrams(_finalCalories!);
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
                    '${_selectedMacro!.carbPercent.toStringAsFixed(1)}%',
                    '${grams['carbs']!.toStringAsFixed(0)}g'),
                _buildMacroStat(
                    'Protein',
                    '${_selectedMacro!.proteinPercent.toStringAsFixed(1)}%',
                    '${grams['protein']!.toStringAsFixed(0)}g'),
                _buildMacroStat(
                    'Lemak',
                    '${_selectedMacro!.fatPercent.toStringAsFixed(1)}%',
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
