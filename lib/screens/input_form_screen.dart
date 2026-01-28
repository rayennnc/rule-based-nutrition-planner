import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/calculator_service.dart';
import 'results_screen.dart';

class InputFormScreen extends StatefulWidget {
  const InputFormScreen({super.key});

  @override
  State<InputFormScreen> createState() => _InputFormScreenState();
}

class _InputFormScreenState extends State<InputFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();

  Gender? _selectedGender;
  ActivityLevel? _selectedActivityLevel;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (_formKey.currentState!.validate()) {
      final calculator = CalculatorService(
        gender: _selectedGender!,
        weight: double.parse(_weightController.text),
        height: double.parse(_heightController.text),
        age: int.parse(_ageController.text),
        activityLevel: _selectedActivityLevel!,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(calculator: calculator),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menghitung IMT dan TDEE'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Berat (kg)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                value!.isEmpty ? 'Mohon masukkan berat badan' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(
                  labelText: 'Tinggi (cm)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                value!.isEmpty ? 'Mohon masukkan tinggi badan' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: 'Umur',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                value!.isEmpty ? 'Mohon masukkan umur' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Gender>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Jenis Kelamin',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: Gender.male, child: Text('Laki-Laki')),
                  DropdownMenuItem(value: Gender.female, child: Text('Perempuan')),
                ],
                onChanged: (value) => setState(() => _selectedGender = value),
                validator: (value) =>
                value == null ? 'Mohon pilih jenis kelamin' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ActivityLevel>(
                value: _selectedActivityLevel,
                decoration: const InputDecoration(
                  labelText: 'Level Aktivitas',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: ActivityLevel.sedentary, child: Text('Tidak Bergerak Banyak')),
                  DropdownMenuItem(value: ActivityLevel.light, child: Text('Ringan')),
                  DropdownMenuItem(value: ActivityLevel.moderate, child: Text('Sedang')),
                  DropdownMenuItem(value: ActivityLevel.active, child: Text('Aktif')),
                  DropdownMenuItem(value: ActivityLevel.veryActive, child: Text('Sangat Aktif')),
                ],
                onChanged: (value) => setState(() => _selectedActivityLevel = value),
                validator: (value) =>
                value == null ? 'Mohon pilih level aktivitas' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.calculate),
                label: const Text('Hitung IMT dan TDEE'),
                onPressed: _calculate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}