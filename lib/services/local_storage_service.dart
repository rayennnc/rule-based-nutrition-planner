import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  // --- DAFTAR KUNCI RAHASIA (KEY) ---
  // Ini seperti label pada laci penyimpanan agar tidak tertukar
  static const String _keyBerat = 'berat_badan';
  static const String _keyTinggi = 'tinggi_badan';
  static const String _keyUsia = 'usia';
  static const String _keyGender = 'jenis_kelamin';
  static const String _keyAktivitas = 'level_aktivitas';

  // 1. FUNGSI SIMPAN (Save)
  // Dipanggil saat user menekan tombol "Hitung"
  Future<void> simpanDataUser({
    required String berat,
    required String tinggi,
    required String usia,
    required String gender,
    required String aktivitas,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Simpan data ke memori HP
    await prefs.setString(_keyBerat, berat);
    await prefs.setString(_keyTinggi, tinggi);
    await prefs.setString(_keyUsia, usia);
    await prefs.setString(_keyGender, gender);
    await prefs.setString(_keyAktivitas, aktivitas);
    
    print("Data user berhasil disimpan di HP! ✅");
  }

  // 2. FUNGSI AMBIL (Load)
  // Dipanggil saat halaman Input pertama kali dibuka (initState)
  Future<Map<String, String>> loadDataUser() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Ambil data, kalau kosong (null) kita kasih nilai default string kosong ''
    // Agar text controller tidak error
    return {
      'berat': prefs.getString(_keyBerat) ?? '',
      'tinggi': prefs.getString(_keyTinggi) ?? '',
      'usia': prefs.getString(_keyUsia) ?? '',
      'gender': prefs.getString(_keyGender) ?? 'Laki - Laki', // Default dropdown
      'aktivitas': prefs.getString(_keyAktivitas) ?? 'Ringan', // Default dropdown
    };
  }

  // 3. FUNGSI HAPUS (Clear)
  // Dipanggil saat user Logout, supaya data tidak diintip orang lain
  Future<void> hapusDataUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Menghapus SEMUA data yang disimpan aplikasi ini
    print("Data lokal berhasil dibersihkan! 🧹");
  }
}