import 'package:flutter/foundation.dart';
import '../services/local_storage_service.dart';
import '../services/calculator_service.dart';

class ProfileNotifier extends ChangeNotifier {
  final LocalStorageService _localStorage;

  Map<String, String> _data = {};
  CalculatorService? _calculator;

  ProfileNotifier(this._localStorage);

  Map<String, String> get data => _data;
  CalculatorService? get calculator => _calculator;

  Future<void> loadFromLocal() async {
    final d = await _localStorage.loadDataUser();
    _data = d;
    _rebuildCalculator();
    notifyListeners();
  }

  void _rebuildCalculator() {
    try {
      final berat =
          double.tryParse((_data['berat'] ?? '').replaceAll(',', '.')) ?? 0.0;
      final tinggi =
          double.tryParse((_data['tinggi'] ?? '').replaceAll(',', '.')) ?? 0.0;

      int usia = 0;
      final tanggalLahirStr = _data['tanggalLahir'] ?? '';
      if (tanggalLahirStr.isNotEmpty) {
        try {
          final tgl = DateTime.parse(tanggalLahirStr);
          usia = CalculatorService.hitungUmurDariTanggalLahir(tgl);
        } catch (_) {
          usia = 0;
        }
      }

      final gender = GenderParsing.tryFromLabel(_data['gender']);
      final activity = ActivityLevelParsing.tryFromLabel(_data['aktivitas']);

      // gender null = data belum lengkap, samain kayak berat/tinggi/usia kosong
      if (berat > 0 && tinggi > 0 && usia > 0 && gender != null) {
        _calculator = CalculatorService(
          gender: gender,
          weight: berat,
          height: tinggi,
          age: usia,
          activityLevel: activity,
        );
      } else {
        _calculator = null;
      }
    } catch (e) {
      _calculator = null;
    }
  }

  /// Called after InputFormScreen saves data to local storage.
  Future<void> refresh() async {
    await loadFromLocal();
  }

  /// Optional: allow updating a specific field and persist via LocalStorageService
  Future<void> updateAndSave({
    String? nama,
    String? berat,
    String? tinggi,
    String? tanggalLahir,
    String? gender,
    String? aktivitas,
  }) async {
    final merged = Map<String, String>.from(_data);
    if (nama != null) merged['nama'] = nama;
    if (berat != null) merged['berat'] = berat;
    if (tinggi != null) merged['tinggi'] = tinggi;
    if (tanggalLahir != null) merged['tanggalLahir'] = tanggalLahir;
    if (gender != null) merged['gender'] = gender;
    if (aktivitas != null) merged['aktivitas'] = aktivitas;

    await _localStorage.simpanDataUser(
      nama: merged['nama'] ?? '',
      berat: merged['berat'] ?? '',
      tinggi: merged['tinggi'] ?? '',
      tanggalLahir: merged['tanggalLahir'] ?? '',
      gender: merged['gender'] ?? '',
      aktivitas: merged['aktivitas'] ?? '',
    );

    _data = merged;
    _rebuildCalculator();
    notifyListeners();
  }
}