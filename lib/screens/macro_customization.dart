import 'package:flutter/material.dart';
import '../services/macro_nutrient.dart';

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

  @override
  void initState() {
    super.initState();
    // Default: 50% carb, 25% protein, 25% fat
    _carbCtl = TextEditingController(text: '50');
    _proteinCtl = TextEditingController(text: '25');
    _fatCtl = TextEditingController(text: '25');
    _updateMacro();
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

        // Check AMDR
        _warningMessage = _currentMacro!.getAMDRWarning();
        _showWarning = _warningMessage != null;
      }
    } catch (e) {
      _errorMessage = 'Input tidak valid';
    }

    setState(() {});
  }

  void _save() {
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

    // Even if warning, save (user acknowledge)
    widget.onSave(_currentMacro!);
    Navigator.pop(context);
  }

  void _setPreset(double carb, double protein, double fat) {
    _carbCtl.text = carb.toString();
    _proteinCtl.text = protein.toString();
    _fatCtl.text = fat.toString();
    _updateMacro();
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
              color: Colors.blue.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target Kalori Harian',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    Text(
                      '${widget.tdee} kalori',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
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
              hint: '45-65',
              color: Colors.orange,
            ),
            const SizedBox(height: 12),

            // Protein
            _buildMacroInput(
              label: 'Protein (%)',
              controller: _proteinCtl,
              hint: '10-35',
              color: Colors.red,
            ),
            const SizedBox(height: 12),

            // Fat
            _buildMacroInput(
              label: 'Lemak (%)',
              controller: _fatCtl,
              hint: '20-35',
              color: Colors.yellow,
            ),
            const SizedBox(height: 24),

            // Total & Error
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
                child: Text(
                  'Total: ${((double.tryParse(_carbCtl.text) ?? 0) + (double.tryParse(_proteinCtl.text) ?? 0) + (double.tryParse(_fatCtl.text) ?? 0)).toStringAsFixed(1)}%',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w600),
                ),
              ),

            // Warning
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
                        Icon(Icons.warning, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Peringatan',
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

            // Preset buttons
            const Text(
              'Preset Populer',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setPreset(50, 25, 25),
                    child: const Text('50-25-25\n(Balanced)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setPreset(55, 30, 15),
                    child: const Text('55-30-15\n(Lean)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setPreset(45, 35, 20),
                    child: const Text('45-35-20\n(High Protein)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Macro breakdown preview
            if (_currentMacro != null && _errorMessage == null)
              _buildMacroBreakdown(),

            const SizedBox(height: 24),

            // Save button
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Simpan'),
              onPressed: _errorMessage == null ? _save : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor:
                    _errorMessage == null ? Colors.green : Colors.grey,
              ),
            ),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: 2),
        ),
        prefixIcon: Icon(Icons.percent, color: color),
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
          'Breakdown Makronutrien',
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
                color: Colors.yellow,
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              '${grams.toStringAsFixed(0)}g',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
