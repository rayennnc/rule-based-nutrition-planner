import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/macro_nutrient.dart';
import '../services/firestore_service.dart';
import '../services/local_storage_service.dart';

class MacroCustomizationScreen extends StatefulWidget {
  final int tdee;
  final Function(MacroNutrient) onSave;

  const MacroCustomizationScreen({
    super.key,
    required this.tdee,
    required this.onSave,
  });

  @override
  State<MacroCustomizationScreen> createState() =>
      _MacroCustomizationScreenState();
}

class _MacroCustomizationScreenState extends State<MacroCustomizationScreen> {
  late TextEditingController _carbCtl;
  late TextEditingController _proteinCtl;
  late TextEditingController _fatCtl;

  MacroNutrient? _currentMacro;
  String? _errorMessage;
  String? _warningMessage;
  bool _showWarning = false;
  final FirestoreService _firestoreService = FirestoreService();
  final LocalStorageService _localStorage = LocalStorageService();

  @override
  void initState() {
    super.initState();
    // Default start with Balanced Diet (WHO Standard)
    _carbCtl = TextEditingController(
        text: MacroNutrient.balanced.carbPercent.toStringAsFixed(0));
    _proteinCtl = TextEditingController(
        text: MacroNutrient.balanced.proteinPercent.toStringAsFixed(0));
    _fatCtl = TextEditingController(
        text: MacroNutrient.balanced.fatPercent.toStringAsFixed(0));
    _updateMacro();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    // 1) Try local cache first (very cheap)
    final local = await _localStorage.loadMacroPreferencesLocal();
    if (local != null && local.isNotEmpty) {
      final c = local['carbPercent'] ?? local['carb'] ?? 0.0;
      final p = local['proteinPercent'] ?? local['protein'] ?? 0.0;
      final f = local['fatPercent'] ?? local['fat'] ?? 0.0;
      _carbCtl.text = c.toStringAsFixed(0);
      _proteinCtl.text = p.toStringAsFixed(0);
      _fatCtl.text = f.toStringAsFixed(0);
      _updateMacro();
      return;
    }

    // 2) If not in local, try Firestore (single read)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final remote = await _firestoreService.loadMacroPreferences(uid);
        if (remote != null) {
          _carbCtl.text = remote.carbPercent.toStringAsFixed(0);
          _proteinCtl.text = remote.proteinPercent.toStringAsFixed(0);
          _fatCtl.text = remote.fatPercent.toStringAsFixed(0);
          _updateMacro();
          // Save to local for faster next load
          await _localStorage.saveMacroPreferencesLocal(
            carbPercent: remote.carbPercent,
            proteinPercent: remote.proteinPercent,
            fatPercent: remote.fatPercent,
          );
        }
      } catch (e) {
        debugPrint('❌ Error loading remote macro prefs: $e');
      }
    }
  }

  @override
  void dispose() {
    _carbCtl.dispose();
    _proteinCtl.dispose();
    _fatCtl.dispose();
    super.dispose();
  }

  void _updateMacro() {
    try {
      final carb = double.tryParse(_carbCtl.text) ?? 0;
      final protein = double.tryParse(_proteinCtl.text) ?? 0;
      final fat = double.tryParse(_fatCtl.text) ?? 0;

      _currentMacro = MacroNutrient(
        carbPercent: carb,
        proteinPercent: protein,
        fatPercent: fat,
      );

      // Check total
      double total = carb + protein + fat;
      if ((total - 100.0).abs() > 0.1) {
        _errorMessage =
            'Total rasio harus 100% (sekarang: ${total.toStringAsFixed(1)}%)';
      } else {
        _errorMessage = null;

        // Check AMDR / WHO Limits
        _warningMessage = _currentMacro!.getAMDRWarning();
        _showWarning = _warningMessage != null;
      }
    } catch (e) {
      _errorMessage = 'Input tidak valid';
    }

    setState(() {});
  }

  Future<void> _save() async {
    _updateMacro();

    if (_errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Simpan ke Firestore sebelum close dialog (jangan lupa cache lokal)
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && _currentMacro != null) {
        await _firestoreService.saveMacroPreferences(
          uid: uid,
          carbPercent: _currentMacro!.carbPercent,
          proteinPercent: _currentMacro!.proteinPercent,
          fatPercent: _currentMacro!.fatPercent,
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving macro preferences: $e');
    }

    // Simpan juga ke cache lokal agar tidak perlu read saat app restart
    try {
      if (_currentMacro != null) {
        await _localStorage.saveMacroPreferencesLocal(
          carbPercent: _currentMacro!.carbPercent,
          proteinPercent: _currentMacro!.proteinPercent,
          fatPercent: _currentMacro!.fatPercent,
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving local macro prefs: $e');
    }

    // Even if warning, save (user acknowledge)
    widget.onSave(_currentMacro!);
    if (mounted) Navigator.pop(context);
  }

  void _setPreset(double carb, double protein, double fat) {
    _carbCtl.text = carb.toStringAsFixed(0); // Hilangkan koma desimal di UI
    _proteinCtl.text = protein.toStringAsFixed(0);
    _fatCtl.text = fat.toStringAsFixed(0);
    _updateMacro();
  }

  // Helper untuk menggunakan Preset Object langsung
  void _usePreset(MacroNutrient preset) {
    _setPreset(preset.carbPercent, preset.proteinPercent, preset.fatPercent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kustomisasi Makronutrien')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Card(
              color: Colors.green.withOpacity(0.1), // Ganti hijau biar fresh
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target Kalori Harian (TDEE)',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    Text(
                      '${widget.tdee} kkal',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Input fields
            const Text(
              'Masukkan Rasio Makronutrien (%)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Carbs
            _buildMacroInput(
              label: 'Karbohidrat (%)',
              controller: _carbCtl,
              hint: '45-75', // Updated hint sesuai WHO
              color: Colors.orange,
            ),
            const SizedBox(height: 12),

            // Protein
            _buildMacroInput(
              label: 'Protein (%)',
              controller: _proteinCtl,
              hint: '10-35', // Updated hint sesuai AMDR
              color: Colors.red,
            ),
            const SizedBox(height: 12),

            // Fat
            _buildMacroInput(
              label: 'Lemak (%)',
              controller: _fatCtl,
              hint: '15-35', // Updated hint sesuai WHO/AMDR
              color: Colors.yellow[700]!,
            ),
            const SizedBox(height: 24),

            // Total & Error Validation
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),

            if (_errorMessage == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Persentase:",
                        style: TextStyle(color: Colors.green)),
                    Text(
                      '${((double.tryParse(_carbCtl.text) ?? 0) + (double.tryParse(_proteinCtl.text) ?? 0) + (double.tryParse(_fatCtl.text) ?? 0)).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ],
                ),
              ),

            // Warning AMDR/WHO
            if (_showWarning && _warningMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Perhatian (Standar Kesehatan)',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _warningMessage!,
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // --- TOMBOL PRESET (INI YANG PENTING DIUBAH) ---
            const Text(
              'Rekomendasi',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // 1. Tombol Balanced (WHO)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _usePreset(MacroNutrient.balanced),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Column(
                      children: [
                        Text('Seimbang',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('(WHO Standard)\n60-15-25',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Tombol High Protein (Atlet)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _usePreset(MacroNutrient.highProtein),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Column(
                      children: [
                        Text('Atlet',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('(High Protein)\n50-30-20',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Tombol Low Fat (Opsional)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _usePreset(MacroNutrient.lowFat),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Column(
                      children: [
                        Text('Low Fat',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('(Cegah Obesitas)\n70-15-15',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Macro breakdown preview (Lingkaran/Bar Visual)
            if (_currentMacro != null && _errorMessage == null)
              _buildMacroBreakdown(),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text('SIMPAN PREFERENSI',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _errorMessage == null ? _save : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                      _errorMessage == null ? Colors.green : Colors.grey,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    required Color color,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: '%',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: 2),
        ),
        prefixIcon: Icon(Icons.pie_chart, color: color),
      ),
      onChanged: (_) => _updateMacro(),
    );
  }

  Widget _buildMacroBreakdown() {
    final grams = _currentMacro!.calculateGrams(widget.tdee);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estimasi Gram per Hari',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMacroCard(
                label: 'Karbohidrat',
                percent: _currentMacro!.carbPercent,
                grams: grams['carbs']!,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMacroCard(
                label: 'Protein',
                percent: _currentMacro!.proteinPercent,
                grams: grams['protein']!,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMacroCard(
                label: 'Lemak',
                percent: _currentMacro!.fatPercent,
                grams: grams['fat']!,
                color: Colors.yellow[700]!,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroCard({
    required String label,
    required double percent,
    required double grams,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700]),
              maxLines: 1,
            ),
            const SizedBox(height: 8),
            Text(
              '${percent.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              '${grams.toStringAsFixed(0)}g',
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
