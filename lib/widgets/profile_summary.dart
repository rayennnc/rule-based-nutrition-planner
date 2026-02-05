import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

class ProfileSummary extends StatefulWidget {
  final VoidCallback? onEdit;
  const ProfileSummary({this.onEdit, super.key});

  @override
  State<ProfileSummary> createState() => _ProfileSummaryState();
}

class _ProfileSummaryState extends State<ProfileSummary> {
  final LocalStorageService _local = LocalStorageService();
  bool _loading = true;
  Map<String, String> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _local.loadDataUser();
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0),
        child: Center(child: CircularProgressIndicator()),
      );

    final berat = _data['berat'] ?? '';
    final tinggi = _data['tinggi'] ?? '';
    final usia = _data['usia'] ?? '';
    final gender = _data['gender'] ?? '';
    final aktivitas = _data['aktivitas'] ?? '';

    final hasAny = berat.isNotEmpty || tinggi.isNotEmpty || usia.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ringkasan Profil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (!hasAny)
              const Text('Belum ada data profil. Silakan isi form di bawah.',
                  style: TextStyle(color: Colors.grey)),
            if (hasAny) ...[
              Wrap(spacing: 12, runSpacing: 8, children: [
                if (berat.isNotEmpty) _infoChip('Berat', '$berat kg'),
                if (tinggi.isNotEmpty) _infoChip('Tinggi', '$tinggi cm'),
                if (usia.isNotEmpty) _infoChip('Umur', '$usia thn'),
                if (gender.isNotEmpty) _infoChip('Gender', gender),
                if (aktivitas.isNotEmpty) _infoChip('Aktivitas', aktivitas),
              ]),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _load, child: const Text('Refresh')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: widget.onEdit,
                  child: const Text('Edit'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Chip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.black54)),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
