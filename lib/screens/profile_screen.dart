import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/local_storage_service.dart';
import '../services/calculator_service.dart';
import 'input_form_screen.dart';

/// Screen untuk menampilkan dan mengedit profil user
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final LocalStorageService _localStorage = LocalStorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = true;
  Map<String, String> _userData = {};
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _localStorage.loadDataUser();
      setState(() {
        _userData = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _editProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const InputFormScreen(asEdit: true)),
    );

    if (result == true) {
      _loadProfile();
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Umur dihitung langsung dari tanggal lahir yang tersimpan, supaya
    // selalu akurat (bukan angka statis yang bisa basi).
    final tanggalLahirStr = _userData['tanggalLahir'] ?? '';
    String usiaDisplay = '-';
    if (tanggalLahirStr.isNotEmpty) {
      try {
        final tgl = DateTime.parse(tanggalLahirStr);
        usiaDisplay = CalculatorService.hitungUmurDariTanggalLahir(tgl).toString();
      } catch (_) {
        usiaDisplay = '-';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar & Email & Nama
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.green,
                          child: Builder(builder: (context) {
                            String avatarInitial = 'U';
                            final name = _userData['nama']?.trim();
                            final email = _currentUser?.email?.trim();
                            if (name != null && name.isNotEmpty) {
                              avatarInitial = name[0];
                            } else if (email != null && email.isNotEmpty) {
                              avatarInitial = email[0];
                            }
                            return Text(
                              avatarInitial.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _userData['nama'] ?? 'User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUser?.email ?? 'email@example.com',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Data Pribadi Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Data Pribadi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            'Nama Lengkap',
                            _userData['nama'] ?? '-',
                            Icons.person,
                          ),
                          const Divider(),
                          _buildInfoRow(
                            'Berat Badan',
                            '${_userData['berat'] ?? '-'} kg',
                            Icons.monitor_weight,
                          ),
                          const Divider(),
                          _buildInfoRow(
                            'Tinggi Badan',
                            '${_userData['tinggi'] ?? '-'} cm',
                            Icons.height,
                          ),
                          const Divider(),
                          _buildInfoRow(
                            'Usia',
                            '$usiaDisplay tahun',
                            Icons.cake,
                          ),
                          const Divider(),
                          _buildInfoRow(
                            'Jenis Kelamin',
                            _userData['gender'] ?? '-',
                            Icons.wc,
                          ),
                          const Divider(),
                          _buildInfoRow(
                            'Level Aktivitas',
                            _userData['aktivitas'] ?? '-',
                            Icons.fitness_center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  ElevatedButton.icon(
                    onPressed: _editProfile,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}