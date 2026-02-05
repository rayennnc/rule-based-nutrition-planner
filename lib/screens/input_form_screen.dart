import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/calculator_service.dart';
import '../services/local_storage_service.dart';
import '../services/firestore_service.dart';
import '../auth/auth_service.dart';
import 'results_screen.dart';
import '../widgets/profile_summary.dart';

class InputFormScreen extends StatefulWidget {
  const InputFormScreen({super.key});

  @override
  State<InputFormScreen> createState() => _InputFormScreenState();
}

class _InputFormScreenState extends State<InputFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  final LocalStorageService _localStorageService =
      LocalStorageService(); // service penyimpanan Local Storage
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

    bool hasLocal = (data['berat'] ?? '').isNotEmpty;

    // If local exists, use it. Otherwise try Firestore fallback once.
    Map<String, String> finalData = Map<String, String>.from(data);

    if (!hasLocal) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final fs = FirestoreService();
        final profile = await fs.loadUserProfile(user.uid);
        if (profile != null) {
          // Map firestore numeric values to string for controllers/local save
          finalData['berat'] = (profile['weightKg'] != null)
              ? profile['weightKg'].toString()
              : '';
          finalData['tinggi'] = (profile['heightCm'] != null)
              ? profile['heightCm'].toString()
              : '';
          finalData['usia'] =
              (profile['age'] != null) ? profile['age'].toString() : '';
          finalData['gender'] = (profile['gender'] != null)
              ? profile['gender'].toString()
              : 'Laki - Laki';
          finalData['aktivitas'] = (profile['activityLevel'] != null)
              ? profile['activityLevel'].toString()
              : 'Ringan';

          // Cache to local so subsequent launches won't hit Firestore
          await _localStorageService.simpanDataUser(
            berat: finalData['berat']!,
            tinggi: finalData['tinggi']!,
            usia: finalData['usia']!,
            gender: finalData['gender']!,
            aktivitas: finalData['aktivitas']!,
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        // Isi Text Controllers
        _weightController.text = finalData['berat'] ?? '';
        _heightController.text = finalData['tinggi'] ?? '';
        _ageController.text = finalData['usia'] ?? '';

        // Isi Dropdown Gender (Konversi String -> Enum)
        if (finalData['gender'] == 'Laki - Laki') {
          _selectedGender = Gender.male;
        } else if (finalData['gender'] == 'Perempuan') {
          _selectedGender = Gender.female;
        }

        // Isi Dropdown Aktivitas (Konversi String -> Enum)
        String activityStr = finalData['aktivitas'] ?? 'Sedang';
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
    _weightFocusNode.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (_formKey.currentState!.validate()) {
      // 2. Simpan Data ke HP sebelum pindah halaman
      // Kita harus ubah Enum kembali ke String biar bisa disimpan
      String genderStr =
          _selectedGender == Gender.male ? 'Laki - Laki' : 'Perempuan';

      String activityStr = 'Ringan';
      switch (_selectedActivityLevel!) {
        case ActivityLevel.sedentary:
          activityStr = 'Tidak Bergerak Banyak';
          break;
        case ActivityLevel.light:
          activityStr = 'Ringan';
          break;
        case ActivityLevel.moderate:
          activityStr = 'Sedang';
          break;
        case ActivityLevel.active:
          activityStr = 'Aktif';
          break;
        case ActivityLevel.veryActive:
          activityStr = 'Sangat Aktif';
          break;
      }

      // Eksekusi Simpan ke Local Storage
      _localStorageService.simpanDataUser(
        berat: _weightController.text,
        tinggi: _heightController.text,
        usia: _ageController.text,
        gender: genderStr,
        aktivitas: activityStr,
      );

      // Simpan Profile ke Firestore (async, tidak blocking)
      _saveProfileToFirestore(
        berat: double.parse(_weightController.text),
        tinggi: double.parse(_heightController.text),
        usia: int.parse(_ageController.text),
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

  // Fungsi untuk menyimpan profile ke Firestore
  Future<void> _saveProfileToFirestore({
    required double berat,
    required double tinggi,
    required int usia,
    required String gender,
    required String aktivitas,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ User tidak terautentikasi');
        return;
      }

      final uid = user.uid;
      final now = Timestamp.now();

      // Simpan ke /users/{uid}
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': user.email,
        'nama': user.displayName ?? 'User',
        'heightCm': tinggi, // number type
        'weightKg': berat, // number type
        'age': usia, // number type
        'gender': gender,
        'activityLevel': aktivitas,
        'updatedAt': now,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge: true = update existing fields

      debugPrint('✅ Profile disimpan ke Firestore (UID: $uid)');
    } catch (e) {
      debugPrint('❌ Error simpan ke Firestore: $e');
    }
  }

  Future<void> _logout() async {
    try {
      await _localStorageService.hapusDataUser();
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/welcome', (route) => false);
      }
    } catch (e) {
      if (mounted)
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
              child: const Text('Batal')),
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
              ProfileSummary(onEdit: () => _weightFocusNode.requestFocus()),
              const SizedBox(height: 8),
              TextFormField(
                controller: _weightController,
                focusNode: _weightFocusNode,
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
                  DropdownMenuItem(
                      value: Gender.male, child: Text('Laki-Laki')),
                  DropdownMenuItem(
                      value: Gender.female, child: Text('Perempuan')),
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
                  DropdownMenuItem(
                      value: ActivityLevel.sedentary,
                      child: Text('Tidak Bergerak Banyak')),
                  DropdownMenuItem(
                      value: ActivityLevel.light, child: Text('Ringan')),
                  DropdownMenuItem(
                      value: ActivityLevel.moderate, child: Text('Sedang')),
                  DropdownMenuItem(
                      value: ActivityLevel.active, child: Text('Aktif')),
                  DropdownMenuItem(
                      value: ActivityLevel.veryActive,
                      child: Text('Sangat Aktif')),
                ],
                onChanged: (value) =>
                    setState(() => _selectedActivityLevel = value),
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
