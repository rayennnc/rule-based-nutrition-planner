import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/calculator_service.dart';
import '../services/local_storage_service.dart';
import '../auth/auth_service.dart';
import 'results_screen.dart';

class InputFormScreen extends StatefulWidget {
  const InputFormScreen({super.key});

  @override
  State<InputFormScreen> createState() => _InputFormScreenState();
}

class _InputFormScreenState extends State<InputFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  final LocalStorageService _localStorageService =  LocalStorageService(); // service penyimpanan Local Storage
  final AuthService _authService = AuthService();

  Gender? _selectedGender;
  ActivityLevel? _selectedActivityLevel;

  @override
  void initState() {
    super.initState();
    // 1. Panggil fungsi load saat layar dibuka
    _loadUserData();
  }

  // Fungsi untuk memuat data dari memori HP ke Form
  Future<void> _loadUserData() async {
    final data = await _localStorageService.loadDataUser();
    
    if (mounted) {
      setState(() {
        // Isi Text Controllers
        _weightController.text = data['berat'] ?? '';
        _heightController.text = data['tinggi'] ?? '';
        _ageController.text = data['usia'] ?? '';

        // Isi Dropdown Gender (Konversi String -> Enum)
        if (data['gender'] == 'Laki - Laki') {
          _selectedGender = Gender.male;
        } else if (data['gender'] == 'Perempuan') {
          _selectedGender = Gender.female;
        }

        // Isi Dropdown Aktivitas (Konversi String -> Enum)
        String activityStr = data['aktivitas'] ?? 'Sedang';
        switch (activityStr) {
          case 'Tidak Bergerak Banyak':
            _selectedActivityLevel = ActivityLevel.sedentary;
            break;
          case 'Ringan':
            _selectedActivityLevel = ActivityLevel.light;
            break;
          case 'Sedang':
            _selectedActivityLevel = ActivityLevel.moderate;
            break;
          case 'Aktif':
            _selectedActivityLevel = ActivityLevel.active;
            break;
          case 'Sangat Aktif':
            _selectedActivityLevel = ActivityLevel.veryActive;
            break;
          default:
            _selectedActivityLevel = ActivityLevel.moderate;
        }
      });
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (_formKey.currentState!.validate()) {

      // 2. Simpan Data ke HP sebelum pindah halaman
      // Kita harus ubah Enum kembali ke String biar bisa disimpan
      String genderStr = _selectedGender == Gender.male ? 'Laki - Laki' : 'Perempuan';

      String activityStr = 'Ringan';
      switch (_selectedActivityLevel!) {
        case ActivityLevel.sedentary: activityStr = 'Tidak Bergerak Banyak'; break;
        case ActivityLevel.light: activityStr = 'Ringan'; break;
        case ActivityLevel.moderate: activityStr = 'Sedang'; break;
        case ActivityLevel.active: activityStr = 'Aktif'; break;
        case ActivityLevel.veryActive: activityStr = 'Sangat Aktif'; break;
      }

      // Eksekusi Simpan
      _localStorageService.simpanDataUser(
        berat: _weightController.text,
        tinggi: _heightController.text,
        usia: _ageController.text,
        gender: genderStr,
        aktivitas: activityStr,
      );

      // Logika Perhitungan
      final calculator = CalculatorService(
        gender: _selectedGender!,
        weight: double.parse(_weightController.text),
        height: double.parse(_heightController.text),
        age: int.parse(_ageController.text),
        activityLevel: _selectedActivityLevel!,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(calculator: calculator),
        ),
      );
    }
  }

  Future<void> _logout() async {
    try {
      await _localStorageService.hapusDataUser();
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout error: $e')));
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
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
        title: const Text('Menghitung IMT dan TDEE'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Berat (kg)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                value!.isEmpty ? 'Mohon masukkan berat badan' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(
                  labelText: 'Tinggi (cm)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                value!.isEmpty ? 'Mohon masukkan tinggi badan' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: 'Umur',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                value!.isEmpty ? 'Mohon masukkan umur' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Gender>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Jenis Kelamin',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: Gender.male, child: Text('Laki-Laki')),
                  DropdownMenuItem(value: Gender.female, child: Text('Perempuan')),
                ],
                onChanged: (value) => setState(() => _selectedGender = value),
                validator: (value) =>
                value == null ? 'Mohon pilih jenis kelamin' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ActivityLevel>(
                value: _selectedActivityLevel,
                decoration: const InputDecoration(
                  labelText: 'Level Aktivitas',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: ActivityLevel.sedentary, child: Text('Tidak Bergerak Banyak')),
                  DropdownMenuItem(value: ActivityLevel.light, child: Text('Ringan')),
                  DropdownMenuItem(value: ActivityLevel.moderate, child: Text('Sedang')),
                  DropdownMenuItem(value: ActivityLevel.active, child: Text('Aktif')),
                  DropdownMenuItem(value: ActivityLevel.veryActive, child: Text('Sangat Aktif')),
                ],
                onChanged: (value) => setState(() => _selectedActivityLevel = value),
                validator: (value) =>
                value == null ? 'Mohon pilih level aktivitas' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.calculate),
                label: const Text('Hitung IMT dan TDEE'),
                onPressed: _calculate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}