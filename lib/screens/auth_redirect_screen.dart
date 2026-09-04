import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/calculator_service.dart';
import '../widgets/main_shell.dart';
import 'welcome_screen.dart';
import 'input_form_screen.dart';

/// Screen perantara: load profil dari Firebase lalu arahkan ke ResultsScreen
/// (lewat MainShell) kalau profil sudah lengkap, atau ke InputFormScreen
/// kalau belum. Dipakai dari dua tempat: main.dart (saat app dibuka dalam
/// keadaan sudah login) dan login_screen.dart (setelah login manual berhasil)
/// — supaya kedua alur itu konsisten dan gak ada yang bypass pengecekan ini.
class AuthRedirectScreen extends StatefulWidget {
  const AuthRedirectScreen({super.key});

  @override
  State<AuthRedirectScreen> createState() => _AuthRedirectScreenState();
}

class _AuthRedirectScreenState extends State<AuthRedirectScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
      }
      return;
    }

    // Load profil user dari Firebase
    final profile = await _firestoreService.loadUserProfile(uid);

    if (profile == null || profile.isEmpty) {
      // Belum ada profil → ke InputFormScreen
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const InputFormScreen()));
      }
      return;
    }

    try {
      final calculator = CalculatorService(
        gender: _parseGender(profile['gender'] as String?),
        height: (profile['heightCm'] as num).toDouble(),
        weight: (profile['weightKg'] as num).toDouble(),
        age: CalculatorService.hitungUmurDariTanggalLahir(
            profile['tanggalLahir'] as DateTime),
        activityLevel: _parseActivity(profile['activityLevel'] as String?),
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainShell(calculator: calculator)),
          (route) => false, // hapus semua route sebelumnya
        );
      }
    } catch (e) {
      // Error parsing profil → ke InputFormScreen
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const InputFormScreen()),
          (route) => false,
        );
      }
    }
  }

  // TODO(konsolidasi): parsing Gender/ActivityLevel string<->enum ini juga
  // diimplementasi ulang di profile_notifier.dart & input_form_screen.dart,
  // dengan default fallback yang beda-beda. Belum disatukan di batch ini —
  // lihat catatan "known issues #2" di Project Instructions.
  Gender _parseGender(String? gender) {
    final g = gender?.toLowerCase() ?? '';
    if (g == 'laki-laki' || g == 'laki - laki' || g == 'male') {
      return Gender.male;
    }
    return Gender.female;
  }

  ActivityLevel _parseActivity(String? activity) {
    switch (activity?.toLowerCase()) {
      case 'ringan':
        return ActivityLevel.light;
      case 'sedang':
        return ActivityLevel.moderate;
      case 'aktif':
        return ActivityLevel.active;
      case 'sangat aktif':
        return ActivityLevel.veryActive;
      default:
        return ActivityLevel.sedentary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}