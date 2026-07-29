import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final AuthService _auth = AuthService();
  bool _loading = false; // flag untuk menonaktifkan tombol saat registrasi berlangsung

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // batalkan jika form belum valid
    if (!_formKey.currentState!.validate()) return;
    // tampilkan loading saat permintaan registrasi dikirim
    setState(() => _loading = true);
    try {
      await _auth.registerWithEmail(
          _emailCtl.text.trim(), _passCtl.text.trim());
      Navigator.pop(context); // kembali ke login; stream akan masuk otomatis
    } on Exception catch (e) {
      // tampilkan pesan kesalahan dari Firebase ke pengguna
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
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
              validator: (v) => v == null || v.length < 6
                  ? 'Password minimal 6 karakter'
                  : null,
            ),
            const SizedBox(height: 16),
            // tombol daftar, nonaktif saat proses registrasi berjalan
            ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Daftar'),
            ),
          ]),
        ),
      ),
    );
  }
}
