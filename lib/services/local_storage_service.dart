import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  // --- DAFTAR KUNCI RAHASIA (KEY) ---
  // Ini seperti label pada laci penyimpanan agar tidak tertukar
  static const String _keyNama = 'nama_user';
  static const String _keyBerat = 'berat_badan';
  static const String _keyTinggi = 'tinggi_badan';
  static const String _keyTanggalLahir = 'tanggal_lahir';
  static const String _keyGender = 'jenis_kelamin';
  static const String _keyAktivitas = 'level_aktivitas';
  static const String _keyAllergies = 'alergi_bahan';
  static const String _keyMacros = 'prefs_macros';

  // 1. FUNGSI SIMPAN (Save)
  // Dipanggil saat user menekan tombol "Hitung"
  Future<void> simpanDataUser({
    required String nama,
    required String berat,
    required String tinggi,
    required String tanggalLahir,
    required String gender,
    required String aktivitas,
    String alergi = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Simpan data ke memori HP
    await prefs.setString(_keyNama, nama);
    await prefs.setString(_keyBerat, berat);
    await prefs.setString(_keyTinggi, tinggi);
    await prefs.setString(_keyTanggalLahir, tanggalLahir);
    await prefs.setString(_keyGender, gender);
    await prefs.setString(_keyAktivitas, aktivitas);
    await prefs.setString(_keyAllergies, alergi);

    print("Data user berhasil disimpan di HP! ✅");
  }

  // 2. FUNGSI AMBIL (Load)
  // Dipanggil saat halaman Input pertama kali dibuka (initState)
  Future<Map<String, String>> loadDataUser() async {
    final prefs = await SharedPreferences.getInstance();

    // Ambil data, kalau kosong (null) kita kasih nilai default string kosong ''
    // Agar text controller tidak error
    return {
      'nama': prefs.getString(_keyNama) ?? '',
      'berat': prefs.getString(_keyBerat) ?? '',
      'tinggi': prefs.getString(_keyTinggi) ?? '',
      'tanggalLahir': prefs.getString(_keyTanggalLahir) ?? '',
      'gender':
          prefs.getString(_keyGender) ?? 'Laki - Laki', // Default dropdown
      'aktivitas':
          prefs.getString(_keyAktivitas) ?? 'Ringan', // Default dropdown
      'alergi': prefs.getString(_keyAllergies) ?? '',
    };
  }

  // 3. FUNGSI HAPUS (Clear)
  // Dipanggil saat user Logout, supaya data tidak diintip orang lain
  Future<void> hapusDataUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Menghapus SEMUA data yang disimpan aplikasi ini
    print("Data lokal berhasil dibersihkan! 🧹");
  }

  // --- MACRO PREFERENCES (Local Cache) ---
  Future<void> saveMacroPreferencesLocal({
    required double carbPercent,
    required double proteinPercent,
    required double fatPercent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {
      'carbPercent': carbPercent,
      'proteinPercent': proteinPercent,
      'fatPercent': fatPercent,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_keyMacros, data.toString());
  }

  Future<Map<String, double>?> loadMacroPreferencesLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyMacros);
    if (raw == null || raw.isEmpty) return null;

    // Stored as Map.toString(); try a simple parse using RegExp
    try {
      final Map<String, double> result = {};
      final entries = RegExp(r"(\w+): ([^,}]+)").allMatches(raw);
      for (final m in entries) {
        final key = m.group(1);
        final val = m.group(2)?.trim();
        if (key != null && val != null) {
          if (key == 'carbPercent' ||
              key == 'proteinPercent' ||
              key == 'fatPercent') {
            result[key] = double.tryParse(val) ?? 0.0;
          }
        }
      }
      if (result.isEmpty) return null;
      return result;
    } catch (e) {
      return null;
    }
  }
}