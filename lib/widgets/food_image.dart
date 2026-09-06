import 'package:flutter/material.dart';

// Handle gambar makanan: asset lokal (prefix 'asset:'), base64 (prefix
// 'data:'), atau URL network. Dulu ke-copas di 3 file, disatuin di sini.
Widget buildFoodImage(String imageUrl, {BoxFit fit = BoxFit.cover}) {
  if (imageUrl.startsWith('asset:')) {
    final assetPath = imageUrl.substring(6); // strip prefix 'asset:'
    return Image.asset(
      assetPath,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  if (imageUrl.startsWith('data:')) {
    try {
      return Image.memory(
        Uri.parse(imageUrl).data!.contentAsBytes(),
        fit: fit,
      );
    } catch (e) {
      return const Center(
          child: Icon(Icons.broken_image, color: Colors.grey));
    }
  }

  // URL internet (http/https)
  return Image.network(
    imageUrl,
    fit: fit,
    errorBuilder: (context, error, stackTrace) =>
        const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
  );
}