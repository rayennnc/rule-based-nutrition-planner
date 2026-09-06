import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/calculator_service.dart';
import '../widgets/main_shell.dart';
import 'welcome_screen.dart';
import 'input_form_screen.dart';

/// Screen perantara: cek profil di Firebase, lempar ke ResultsScreen kalau
/// udah lengkap, atau ke InputFormScreen kalau belum. Dipake dari main.dart
/// dan login_screen.dart biar dua-duanya konsisten.
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

    // gender nentuin rumus BMR - kalau ga kebaca, jangan ditebak
    final gender = GenderParsing.tryFromLabel(profile['gender'] as String?);
    if (gender == null) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const InputFormScreen()),
          (route) => false,
        );
      }
      return;
    }

    try {
      final calculator = CalculatorService(
        gender: gender,
        height: (profile['heightCm'] as num).toDouble(),
        weight: (profile['weightKg'] as num).toDouble(),
        age: CalculatorService.hitungUmurDariTanggalLahir(
            profile['tanggalLahir'] as DateTime),
        activityLevel:
            ActivityLevelParsing.tryFromLabel(profile['activityLevel'] as String?),
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainShell(calculator: calculator)),
          (route) => false, // hapus semua route sebelumnya
        );
      }
    } catch (e) {
      // Error parsing profil (heightCm/weightKg/tanggalLahir corrupt, dll) →
      // ke InputFormScreen
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const InputFormScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}