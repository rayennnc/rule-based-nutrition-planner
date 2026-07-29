import 'package:flutter/material.dart';

/// Screen untuk pengaturan aplikasi
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tentang Aplikasi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'NutriSee',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Versi 1.0.0'),
              SizedBox(height: 12),
              Text(
                'NutriSee adalah aplikasi meal planner yang membantu Anda mencapai target nutrisi harian dengan rekomendasi makanan berbasis rule-based system.',
                textAlign: TextAlign.justify,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(0),
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.info_outline, color: Colors.blue),
                      title: const Text('Tentang Aplikasi'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showAboutDialog,
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading:
                          const Icon(Icons.help_outline, color: Colors.orange),
                      title: const Text('Bantuan & FAQ'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showHelpDialog,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'NutriSee v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bantuan & FAQ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Pertanyaan Umum:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                '❓ Bagaimana cara menghitung TDEE?\n'
                'TDEE dihitung dari BMR (Basal Metabolic Rate) dikalikan dengan faktor aktivitas Anda.',
              ),
              SizedBox(height: 12),
              Text(
                '❓ Apa itu macro nutrient?\n'
                'Makronutrien terdiri dari protein, karbohidrat, dan lemak yang merupakan nutrisi utama tubuh.',
              ),
              SizedBox(height: 12),
              Text(
                '❓ Bagaimana cara swap menu makanan?\n'
                'Tekan tombol "Swap" pada kartu makanan untuk mengganti dengan menu pilihan lain dari kategori yang sama.',
              ),
              SizedBox(height: 12),
              Text(
                '❓ Apakah data saya aman?\n'
                'Ya, data Anda disimpan aman di Firebase dengan enkripsi end-to-end.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
