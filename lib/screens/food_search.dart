import 'package:flutter/material.dart';
import '../services/firestore_service.dart'; // Sesuaikan path import

class FoodSearch extends SearchDelegate {
  final List<FoodItem> foodList;
  final Function(FoodItem) onItemTap;

  // Variabel kategori
  String selectedCategory = 'Semua';

  FoodSearch({required this.foodList, required this.onItemTap});

  // Logika Getter untuk Kategori Unik
  List<String> get uniqueCategories {
    final categories = foodList.map((food) => food.kategori).toSet().toList();
    categories.sort();
    return ['Semua', ...categories];
  }

  @override
  String get searchFieldLabel => 'Cari nama makanan...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // Saat tekan enter
    return _buildStatefulBody(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Saat mengetik (atau saat baru buka)
    return _buildStatefulBody(context);
  }

  // --- PEMBUNGKUS AGAR BISA REFRESH OTOMATIS ---
  Widget _buildStatefulBody(BuildContext context) {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return _buildListContent(context, setState);
      },
    );
  }

  // --- KONTEN UTAMA ---
  Widget _buildListContent(BuildContext context, StateSetter setState) {
    // 1. Logika Filter
    final results = foodList.where((food) {
      final matchesQuery = food.name.toLowerCase().contains(query.toLowerCase());
      final matchesCategory = selectedCategory == 'Semua' || food.kategori == selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    return Column(
      children: [
        // FILTER CHIPS (Kategori)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: uniqueCategories.map((cat) {
                final bool isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: Colors.green.withOpacity(0.2),
                    checkmarkColor: Colors.green,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.green[800] : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.grey[100],
                    onSelected: (bool selected) {
                      // MAGIC HAPPENS HERE: 
                      // setState ini memaksa tampilan refresh SEKETIKA saat diklik
                      setState(() {
                        selectedCategory = cat;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // LIST HASIL
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak ada makanan "$query"\ndi kategori "$selectedCategory"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final item = results[index];
                    bool isMentah = item.kondisi.toLowerCase() == 'mentah';

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 50, height: 50,
                          child: item.imageUrl != null
                              ? Image.network(
                                  item.imageUrl!, 
                                  fit: BoxFit.cover,
                                  errorBuilder: (_,__,___) => const Icon(Icons.fastfood, color: Colors.grey),
                                )
                              : const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                      ),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        "${item.calories} kal | ${item.kategori} • ${isMentah ? 'Mentah' : 'Siap Makan'}",
                        style: TextStyle(color: isMentah ? Colors.orange : Colors.grey),
                      ),
                      trailing: isMentah 
                          ? const Tooltip(
                              message: "Bahan Mentah", 
                              child: Icon(Icons.info_outline, color: Colors.orange, size: 20))
                          : const Icon(Icons.chevron_right),
                      onTap: () => onItemTap(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}