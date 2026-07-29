import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/calculator_service.dart';
import '../services/local_storage_service.dart';
import '../services/firestore_service.dart';
import '../auth/auth_service.dart';
import '../widgets/main_shell.dart';
import '../widgets/profile_summary.dart';
import 'package:provider/provider.dart';
import '../models/profile_notifier.dart';

class InputFormScreen extends StatefulWidget {
  final bool asEdit;
  const InputFormScreen({super.key, this.asEdit = false});

  @override
  State<InputFormScreen> createState() => _InputFormScreenState();
}

class _InputFormScreenState extends State<InputFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _weightController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final _heightController = TextEditingController();
  final _tanggalLahirController = TextEditingController();
  final LocalStorageService _localStorageService =
      LocalStorageService(); // service penyimpanan local
  final AuthService _authService = AuthService();

  Gender? _selectedGender;
  ActivityLevel? _selectedActivityLevel;
  DateTime? _selectedTanggalLahir;

  static const List<String> _namaBulan = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  // Alergi options (demo simple): cukup 3 pilihan
  // bool _allergySusu = false;
  bool _allergyKerangUdang = false;
  bool _allergyKacang = false;
  bool _allergyTelur = false;

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
          // Jika tidak ada data lokal, ambil profil user dari Firestore
          // lalu simpan ke local cache.
          finalData['nama'] =
              (profile['nama'] != null) ? profile['nama'].toString() : '';
          finalData['berat'] = (profile['weightKg'] != null)
              ? profile['weightKg'].toString()
              : '';
          finalData['tinggi'] = (profile['heightCm'] != null)
              ? profile['heightCm'].toString()
              : '';
          final tglLahirProfile = profile['tanggalLahir'];
          finalData['tanggalLahir'] = (tglLahirProfile is DateTime)
              ? tglLahirProfile.toIso8601String()
              : '';
          finalData['gender'] = (profile['gender'] != null)
              ? profile['gender'].toString()
              : 'Laki - Laki';
          finalData['aktivitas'] = (profile['activityLevel'] != null)
              ? profile['activityLevel'].toString()
              : 'Ringan';

          // Cache ke local supaya tidak perlu fetch Firestore lagi.
          await _localStorageService.simpanDataUser(
            nama: finalData['nama']!,
            berat: finalData['berat']!,
            tinggi: finalData['tinggi']!,
            tanggalLahir: finalData['tanggalLahir']!,
            gender: finalData['gender']!,
            aktivitas: finalData['aktivitas']!,
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        // Isi form dengan nilai yang sudah tersedia.
        _namaController.text = finalData['nama'] ?? '';
        _weightController.text = finalData['berat'] ?? '';
        _heightController.text = finalData['tinggi'] ?? '';

        final tglLahirStr = finalData['tanggalLahir'] ?? '';
        if (tglLahirStr.isNotEmpty) {
          try {
            _selectedTanggalLahir = DateTime.parse(tglLahirStr);
            _tanggalLahirController.text =
                _formatTanggalLahir(_selectedTanggalLahir!);
          } catch (_) {
            _selectedTanggalLahir = null;
            _tanggalLahirController.text = '';
          }
        }

        // Parse alergi string menjadi checkbox state (demo simple)
        final allergiRaw = (finalData['alergi'] ?? '').toLowerCase();
        // _allergySusu = allergiRaw.contains('susu');
        _allergyKerangUdang =
            allergiRaw.contains('udang') || allergiRaw.contains('kerang');
        _allergyKacang = allergiRaw.contains('kacang');
        _allergyTelur = allergiRaw.contains('telur');

        // Konversi string Firestore/local menjadi enum Gender.
        if (finalData['gender'] == 'Laki - Laki') {
          _selectedGender = Gender.male;
        } else if (finalData['gender'] == 'Perempuan') {
          _selectedGender = Gender.female;
        }

        // Isi Dropdown Aktivitas (Konversi String -> Enum)
        String activityStr = finalData['aktivitas'] ?? 'Sedang';
        // Konversi string aktivitas menjadi enum ActivityLevel.
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
    _namaController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _tanggalLahirController.dispose();
    super.dispose();
  }

  /// Build comma-separated allergy string from checkbox selections
  String _buildAllergyString() {
    final selected = <String>[];
    // if (_allergySusu) selected.add('susu');
    if (_allergyKerangUdang) {
      selected.add('udang');
      selected.add('kerang');
    }
    if (_allergyKacang) selected.add('kacang');
    if (_allergyTelur) selected.add('telur');
    return selected.join(', ');
  }

  /// Format tanggal lahir untuk ditampilkan di form, misal "17 Agustus 2000".
  String _formatTanggalLahir(DateTime d) {
    return '${d.day} ${_namaBulan[d.month]} ${d.year}';
  }

  /// Buka date picker untuk memilih tanggal lahir. Rentang tanggal dibatasi
  /// agar umur yang dihasilkan otomatis berada di 18-75 tahun.
  Future<void> _pickTanggalLahir() async {
    final now = DateTime.now();
    final initialDate =
        _selectedTanggalLahir ?? DateTime(now.year - 25, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 75, now.month, now.day),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Pilih Tanggal Lahir',
    );

    if (picked != null) {
      setState(() {
        _selectedTanggalLahir = picked;
        _tanggalLahirController.text = _formatTanggalLahir(picked);
      });
    }
  }

  Future<void> _calculate() async {
    if (_formKey.currentState!.validate()) {
      // Simpan input ke lokal sebelum navigasi.
      String genderStr =
          _selectedGender == Gender.male ? 'Laki - Laki' : 'Perempuan';

      String activityStr = 'Ringan';
      // Convert enum aktivitas ke label yang bisa disimpan.
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

      final allergyStr = _buildAllergyString();

      // Tunggu simpan ke Local Storage agar UI konsisten saat kembali.
      await _localStorageService.simpanDataUser(
        nama: _namaController.text,
        berat: _weightController.text,
        tinggi: _heightController.text,
        tanggalLahir: _selectedTanggalLahir!.toIso8601String(),
        gender: genderStr,
        aktivitas: activityStr,
        alergi: allergyStr,
      );

      // Simpan profil user ke Firestore di background.
      _saveProfileToFirestore(
        nama: _namaController.text,
        berat: double.parse(_weightController.text),
        tinggi: double.parse(_heightController.text),
        tanggalLahir: _selectedTanggalLahir!,
        gender: genderStr,
        aktivitas: activityStr,
        alergi: allergyStr,
      );

      // Notify app-level profile state so ResultsScreen/others recalc.
      try {
        final notifier = Provider.of<ProfileNotifier>(context, listen: false);
        await notifier.refresh();
      } catch (_) {}

      // Jika dipanggil sebagai edit profile, cukup kembali dan kirim true.
      if (widget.asEdit) {
        if (mounted) Navigator.pop(context, true);
        return;
      }

      // Jika bukan edit (onboarding), lanjutkan ke MainShell dengan Calculator.
      final calculator = CalculatorService(
        gender: _selectedGender!,
        weight: double.parse(_weightController.text.replaceAll(',', '.')),
        height: double.parse(_heightController.text.replaceAll(',', '.')),
        age: CalculatorService.hitungUmurDariTanggalLahir(
            _selectedTanggalLahir!),
        activityLevel: _selectedActivityLevel!,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainShell(calculator: calculator),
        ),
      );
    }
  }

  // Simpan profil user ke koleksi users di Firestore.
  Future<void> _saveProfileToFirestore({
    required String nama,
    required double berat,
    required double tinggi,
    required DateTime tanggalLahir,
    required String gender,
    required String aktivitas,
    required String alergi,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ User tidak terautentikasi');
        return;
      }

      final uid = user.uid;
      final now = Timestamp.now();

      // Update atau buat dokumen profil user di Firestore.
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': user.email,
        'nama': nama,
        'heightCm': tinggi, // number type
        'weightKg': berat, // number type
        'tanggalLahir': Timestamp.fromDate(tanggalLahir),
        'gender': gender,
        'activityLevel': aktivitas,
        'allergies': alergi,
        'updatedAt': now,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge: true = update existing fields

      debugPrint('Profile disimpan ke Firestore (UID: $uid)');
    } catch (e) {
      debugPrint('Error simpan ke Firestore: $e');
    }
  }

  Future<void> _logout() async {
    try {
      await _localStorageService.hapusDataUser();
      await _authService.signOut();
      if (mounted) {
        // Kembali ke layar welcome dan hapus history navigasi.
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

  // Tabel penjelasan level aktivitas
  Widget _buildActivityLevelExplanation() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Penjelasan Level Aktivitas',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text('Level',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text('Penjelasan',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: Text('Faktor',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                // Rows
                _ActivityRow(
                    level: 'Tidak Bergerak',
                    desc: 'Jarang olahraga, duduk seharian',
                    factor: '1.2x'),
                _ActivityRow(
                    level: 'Ringan',
                    desc: 'Olahraga 1-3 hari/minggu',
                    factor: '1.375x'),
                _ActivityRow(
                    level: 'Sedang',
                    desc: 'Olahraga 3-5 hari/minggu',
                    factor: '1.55x'),
                _ActivityRow(
                    level: 'Aktif',
                    desc: 'Olahraga intensif 6-7 hari/minggu',
                    factor: '1.725x'),
                _ActivityRow(
                    level: 'Sangat Aktif',
                    desc: 'Atlet profesional, 2x latihan/hari',
                    factor: '1.9x'),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Catatan: Faktor × BMR = TDEE (kebutuhan kalori harian)',
              style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ActivityRow({
    required String level,
    required String desc,
    required String factor,
  }) {
    return Container(
      decoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(level,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(desc,
                style: const TextStyle(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(factor,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green)),
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
              // Input nama user
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  hintText: 'Contoh: John Doe',
                ),
                keyboardType: TextInputType.text,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Mohon masukkan nama';
                  }
                  if (value.length < 3) {
                    return 'Nama minimal 3 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Input berat badan user.
              TextFormField(
                controller: _weightController,
                focusNode: _weightFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Berat (kg)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Mohon masukkan berat badan';

                  String valStr =
                      value.replaceAll(',', '.'); // Ganti koma dengan titik
                  final weight = double.tryParse(valStr);
                  if (weight == null || weight <= 0 || weight > 300) {
                    return 'Berat badan tidak valid (1 - 300 kg)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Input tinggi badan user.
              TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(
                  labelText: 'Tinggi (cm)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Mohon masukkan tinggi badan';

                  String valStr = value.replaceAll(',', '.');
                  final height = double.tryParse(valStr); // Pakai double

                  if (height == null || height < 50 || height > 250) {
                    return 'Tinggi badan tidak valid (50–250 cm)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Input tanggal lahir user (umur dihitung otomatis dari sini).
              TextFormField(
                controller: _tanggalLahirController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Lahir',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: _pickTanggalLahir,
                validator: (value) {
                  if (_selectedTanggalLahir == null) {
                    return 'Mohon pilih tanggal lahir';
                  }
                  final umur = CalculatorService.hitungUmurDariTanggalLahir(
                      _selectedTanggalLahir!);
                  if (umur < 18 || umur > 75) {
                    return 'Umur tidak valid (18-75 tahun)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Pilihan jenis kelamin.
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
              // Pilihan level aktivitas harian.
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
              const SizedBox(height: 16),
              // Alergi checkboxes (3 opsi standar)
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alergi / Bahan yang Harus Dihindari',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      /* CheckboxListTile(
                        value: _allergySusu,
                        onChanged: (val) =>
                            setState(() => _allergySusu = val ?? false),
                        title: const Text('Susu'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ), */
                      CheckboxListTile(
                        value: _allergyKerangUdang,
                        onChanged: (val) =>
                            setState(() => _allergyKerangUdang = val ?? false),
                        title: const Text('Kerang / Udang'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      CheckboxListTile(
                        value: _allergyKacang,
                        onChanged: (val) =>
                            setState(() => _allergyKacang = val ?? false),
                        title: const Text('Kacang'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      CheckboxListTile(
                        value: _allergyTelur,
                        onChanged: (val) =>
                            setState(() => _allergyTelur = val ?? false),
                        title: const Text('Telur'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildActivityLevelExplanation(),
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