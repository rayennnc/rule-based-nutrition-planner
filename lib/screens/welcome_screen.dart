import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _weightCtl = TextEditingController();
  final TextEditingController _heightCtl = TextEditingController();

  double? _bmi;
  String? _bmiCategory;

  @override
  void dispose() {
    _weightCtl.dispose();
    _heightCtl.dispose();
    super.dispose();
  }

  void _calculateBmi() {
    if (!_formKey.currentState!.validate()) return;

    final double weight =
        double.tryParse(_weightCtl.text.replaceAll(',', '.')) ?? 0;
    final double height =
        double.tryParse(_heightCtl.text.replaceAll(',', '.')) ?? 0;

    if (weight <= 0 || height <= 0) return;

    final hMeters = height / 100;
    final bmi = weight / (hMeters * hMeters);
    final rounded = double.parse(bmi.toStringAsFixed(1));

    String category;
    if (rounded < 18.5) {
      category = 'Kurus (Underweight)';
    } else if (rounded >= 18.5 && rounded <= 22.9) {
      category = 'Normal';
    } else if (rounded >= 23.0 && rounded <= 24.9) {
      category = 'Overweight';
    } else if (rounded >= 25.0 && rounded <= 29.9) {
      category = 'Obesitas Kelas 1';
    } else {
      category = 'Obesitas Kelas 2';
    }

    setState(() {
      _bmi = rounded;
      _bmiCategory = category;
    });
  }

  Color _resultColor() {
    if (_bmi == null) return Colors.grey.shade100;

    if (_bmi! < 18.5) return Colors.blue.shade50;
    if (_bmi! < 23.0) return Colors.green.shade50;
    if (_bmi! < 25.0) return Colors.amber.shade100;
    if (_bmi! < 30.0) return Colors.orange.shade200;
    return Colors.red.shade100;
  }

  String _categoryAdvice() {
    if (_bmi == null) return '';
    if (_bmi! < 18.5)
      return 'Kurus: Pertimbangkan peningkatan asupan kalori dan pemeriksaan kesehatan jika penurunan berat tidak diinginkan.';
    if (_bmi! >= 18.5 && _bmi! <= 22.9)
      return 'Normal: Pertahankan pola makan seimbang dan aktivitas fisik teratur.';
    if (_bmi! >= 23.0 && _bmi! <= 24.9)
      return 'Overweight: Kurangi asupan kalori sedikit dan tingkatkan aktivitas fisik.';
    if (_bmi! >= 25.0 && _bmi! <= 29.9)
      return 'Obesitas Kelas 1: Konsultasikan kepada dokter untuk rencana penurunan berat badan.';
    return 'Obesitas Kelas 2: Konsultasikan ke profesional kesehatan untuk rencana penurunan berat yang aman.';
  }

  Widget _legendChip(String title, String range, Color color) {
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          Text(range,
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }

  void _gotoMealPlanner() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Perlu Login'),
          content: const Text(
              'Untuk mendapatkan meal planner, silakan login atau daftar terlebih dahulu.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Login'),
            ),
          ],
        ),
      );
      return;
    }

    // Jika sudah login, arahkan ke route input/profile (app sudah punya '/input')
    Navigator.pushNamed(context, '/input');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IMT - NutriSee')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: const [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.local_florist,
                          color: Colors.white, size: 36),
                    ),
                    SizedBox(height: 12),
                    Text('NUTRISEE',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Hitung IMT Anda',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'Masukkan berat (kg) dan tinggi (cm). Untuk mendapatkan meal planner, silakan login.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Form(
                    key: _formKey,
                    child: Column(children: [
                      TextFormField(
                        controller: _weightCtl,
                        decoration: const InputDecoration(
                          labelText: 'Berat (kg)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.monitor_weight),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          final val =
                              double.tryParse(v?.replaceAll(',', '.') ?? '');
                          if (val == null || val <= 0) {
                            return 'Masukkan berat valid';
                          }
                          if (val > 300) return 'Berat tidak boleh lebih dari 300 kg';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _heightCtl,
                        decoration: const InputDecoration(
                          labelText: 'Tinggi (cm)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.height),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          final val =
                              double.tryParse(v?.replaceAll(',', '.') ?? '');
                          if (val == null || val <= 0)
                            return 'Masukkan tinggi valid';
                            if (val < 50 || val > 250) return 'Tinggi harus antara 50-250 cm';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _calculateBmi,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Hitung IMT'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _weightCtl.clear();
                              _heightCtl.clear();
                              setState(() {
                                _bmi = null;
                                _bmiCategory = null;
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_bmi != null) ...[
                Card(
                  color: _resultColor(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IMT: ${_bmi!.toStringAsFixed(1)}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('Status: ${_bmiCategory ?? '-'}',
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(_categoryAdvice(),
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text('Klasifikasi IMT (WHO):',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          _legendChip('Kurus', '< 18.5', Colors.blue),
                          _legendChip('Normal', '18.5 - 22.9', Colors.green),
                          _legendChip('Overweight', '23.0 - 24.9', Colors.amber),
                          _legendChip('Obesitas I', '25.0 - 29.9', Colors.orange),
                          _legendChip('Obesitas II', '>= 30.0', Colors.red),
                        ])
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Dapatkan Meal Planner'),
                onPressed: _gotoMealPlanner,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('Sudah punya akun? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
