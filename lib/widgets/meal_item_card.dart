import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../screens/food_search.dart';

class MealItemCard extends StatefulWidget {
  final FoodItem foodItem; // Data makanan awal
  final String category; // Kategori untuk filter swap (misal: "Serealia")

  const MealItemCard({
    Key? key,
    required this.foodItem,
    required this.category,
  }) : super(key: key);

  @override
  State<MealItemCard> createState() => _MealItemCardState();
}

class _MealItemCardState extends State<MealItemCard> {
  late FoodItem currentFood; // Makanan yang sedang tampil
  late int currentWeight; // Berat porsi (gram)
  bool isSwapping = false; // Loading indicator

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    currentFood = widget.foodItem;
    // Default berat 100g (karena data DB per 100g), atau sesuaikan logika kamu
    currentWeight = 100;
  }

  // LOGIKA SWAP & HITUNG ULANG
  Future<void> _swapMenu() async {
    setState(() => isSwapping = true);

    // 1. Ambil Kandidat Pengganti (Aman Kuota karena pakai Cache)
    List<FoodItem> candidates =
        await _firestoreService.getFoodCandidates(widget.category);

    // Filter: Buang makanan yang sedang tampil sekarang
    var filtered = candidates.where((f) => f.id != currentFood.id).toList();

    if (filtered.isNotEmpty) {
      // 2. Pilih Random
      var newFood = (filtered..shuffle()).first;

      // 3. HITUNG MATEMATIKA (Target Kalori Tetap Sama)
      // Rumus: (KaloriLama / KaloriBaruPer100g) * BeratLama
      double targetCalories = (currentFood.calories * currentWeight / 100);
      double newWeightDouble = (targetCalories / newFood.calories) * 100;

      setState(() {
        currentFood = newFood;
        currentWeight = newWeightDouble.round(); // Update berat baru
        isSwapping = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Diganti ke ${newFood.name} (${currentWeight}g)")),
      );
    } else {
      setState(() => isSwapping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak ada opsi pengganti lain.")),
      );
    }
  }

  // OPEN SEARCH DIALOG & SWAP MANUAL
  Future<void> _openSearchAndSwap() async {
    setState(() => isSwapping = true);

    // Ambil kandidat (menggunakan cache di FirestoreService)
    List<FoodItem> candidates =
        await _firestoreService.getFoodCandidates(widget.category);

    // Jika tidak ada kandidat selain item yang sedang tampil
    var filtered = candidates.where((f) => f.id != currentFood.id).toList();

    if (filtered.isEmpty) {
      setState(() => isSwapping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak ada opsi pengganti lain.")),
      );
      return;
    }

    // Tampilkan SearchDelegate
    await showSearch(
      context: context,
      delegate: FoodSearch(
        foodList: filtered,
        onItemTap: (FoodItem item) {
          // Validasi kalori
          if (item.calories <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text("Data kalori tidak tersedia untuk pilihan ini.")),
            );
            // tutup search
            Navigator.pop(context);
            setState(() => isSwapping = false);
            return;
          }

          double targetCalories = (currentFood.calories * currentWeight / 100);
          double newWeightDouble = (targetCalories / item.calories) * 100;
          int newWeight = newWeightDouble.isFinite
              ? newWeightDouble.round().clamp(10, 2000)
              : 100;

          setState(() {
            currentFood = item;
            currentWeight = newWeight;
            isSwapping = false;
          });

          Navigator.pop(context); // tutup search

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Diganti menjadi ${item.name} — ${currentWeight}g')),
          );
        },
      ),
    );

    // Jika user menutup search tanpa memilih
    if (mounted) setState(() => isSwapping = false);
  }

  @override
  Widget build(BuildContext context) {
    // Hitung nutrisi Real-time berdasarkan berat baru
    double ratio = currentWeight / 100;
    int realCal = (currentFood.calories * ratio).round();
    double realP = currentFood.protein * ratio;
    double realC = currentFood.carbs * ratio;
    double realF = currentFood.fat * ratio;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showFoodDetail(context, currentFood),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Gambar (tampilkan kalau ada imageUrl, pakai placeholder jika tidak)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (currentFood.imageUrl != null &&
                          currentFood.imageUrl!.trim().isNotEmpty)
                      ? _buildImageWidget(currentFood.imageUrl!)
                      : const Icon(Icons.fastfood, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),

              // Info Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currentFood.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("$currentWeight gram",
                        style: const TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold)),
                    Text(
                      "P: ${realP.toStringAsFixed(1)} | K: ${realC.toStringAsFixed(1)} | L: ${realF.toStringAsFixed(1)}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // Tombol Swap & Kalori
              Column(
                children: [
                  Text("$realCal kkal",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  isSwapping
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.search, color: Colors.green),
                              onPressed: _openSearchAndSwap,
                              tooltip: "Cari Pengganti",
                            ),
                            IconButton(
                              icon: const Icon(Icons.autorenew,
                                  color: Colors.blue),
                              onPressed: _swapMenu,
                              tooltip: "Ganti Acak",
                            ),
                          ],
                        )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER UI ---
  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl.startsWith('data:')) {
      try {
        return Image.memory(Uri.parse(imageUrl).data!.contentAsBytes(),
            fit: BoxFit.cover);
      } catch (e) {
        return const Icon(Icons.broken_image, color: Colors.grey);
      }
    } else {
      return Image.network(imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => const Icon(Icons.broken_image));
    }
  }

  void _showFoodDetail(BuildContext context, FoodItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.grey[100]),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: item.imageUrl != null
                              ? _buildImageWidget(item.imageUrl!)
                              : const Icon(Icons.fastfood,
                                  size: 80, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(item.name,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  const Text("Informasi Nilai Gizi (per 100g)",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNutrientBox(
                            "Kalori", "${item.calories}", Colors.redAccent),
                        _buildNutrientBox(
                            "Protein", "${item.protein}", Colors.blueAccent),
                        _buildNutrientBox(
                            "Karbo", "${item.carbs}", Colors.orange),
                        _buildNutrientBox(
                            "Lemak", "${item.fat}", Colors.amber[700]!),
                      ]),
                  const SizedBox(height: 30),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Tutup"))
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNutrientBox(String label, String value, Color color) {
    return Column(children: [
      Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 16))),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ]);
  }
}
