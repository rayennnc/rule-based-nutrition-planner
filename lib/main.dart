import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'screens/input_form_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/main_shell.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firestore_service.dart';
import 'services/calculator_service.dart';
import 'package:provider/provider.dart';
import 'models/profile_notifier.dart';
import 'services/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const NutriSeeApp());
}

class NutriSeeApp extends StatelessWidget {
  const NutriSeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => ProfileNotifier(LocalStorageService())..loadFromLocal(),
        child: MaterialApp(
          title: 'NutriSee',
          theme: ThemeData(
            primarySwatch: Colors.green,
            scaffoldBackgroundColor: Colors.white,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
          routes: {
            '/input': (context) => const InputFormScreen(),
            '/login': (context) => const LoginScreen(),
            '/welcome': (context) => const WelcomeScreen(),
          },
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasData) {
                // User sudah login → cek profil dulu
                return const AuthRedirectScreen();
              }
              // Belum login
              return const WelcomeScreen();
            },
          ),
        ));
  }
}

/// Screen perantara: load profil dari Firebase lalu arahkan ke ResultsScreen
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
      if (mounted)
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
      return;
    }

    // Load profil user dari Firebase
    final profile = await _firestoreService.loadUserProfile(uid);

    if (profile == null || profile.isEmpty) {
      // Belum ada profil → ke InputFormScreen
      if (mounted)
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const InputFormScreen()));
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

      if (mounted)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainShell(calculator: calculator)),
          (route) => false, // hapus semua route sebelumnya
        );
    } catch (e) {
      // Error parsing profil → ke InputFormScreen
      if (mounted)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const InputFormScreen()),
          (route) => false,
        );
    }
  }

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