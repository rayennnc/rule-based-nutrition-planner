import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'screens/input_form_screen.dart';
import 'screens/login_screen.dart';
import 'screens/auth_redirect_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
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