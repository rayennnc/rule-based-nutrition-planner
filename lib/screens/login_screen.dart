import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import 'register_screen.dart';
import 'auth_redirect_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final AuthService _auth = AuthService();
  bool _loading = false; // flag untuk menonaktifkan tombol saat login berlangsung

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    // tampilkan loading saat permintaan login dikirim
    setState(() => _loading = true);
    try {
      final cred = await _auth.signInWithEmail(
          _emailCtl.text.trim(), _passCtl.text.trim());
      debugPrint('SignIn success uid=${cred.user?.uid}');

      // Cek profil dulu (sama kayak alur relaunch app di main.dart) —
      // kalau profil udah lengkap, langsung ke MainShell, bukan form input lagi.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthRedirectScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login gagal: ${e.code} — ${e.message}')),
      );
      debugPrint('FirebaseAuthException: ${e.code} ${e.message}');
    } catch (e, st) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login error: $e')));
      debugPrint('Other exception: $e\n$st');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(children: [
            // input email pengguna, pakai validator sederhana
            TextFormField(
              controller: _emailCtl,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Masukkan email' : null,
            ),
            const SizedBox(height: 12),
            // input password pengguna, ditutup agar tidak tampil teks
            TextFormField(
              controller: _passCtl,
              decoration: const InputDecoration(
                  labelText: 'Password', border: OutlineInputBorder()),
              obscureText: true,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Masukkan password' : null,
            ),
            const SizedBox(height: 16),
            // tombol login, nonaktif saat proses login berjalan
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Login'),
            ),
            // buka layar pendaftaran jika pengguna belum punya akun
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: const Text('Belum punya akun? Daftar'),
            )
          ]),
        ),
      ),
    );
  }
}