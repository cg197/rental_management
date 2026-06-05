import 'dart:io';
import 'package:flutter/material.dart';
import '../models/property.dart';
import '../routes/app_routes.dart';

class PropertyCard extends StatelessWidget {
  final Property property;

  const PropertyCard({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    // 1. Split the image paths string into a list
    final List<String> images = property.imagePaths.isNotEmpty
        ? property.imagePaths.split(',')
        : [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Carousel Section
          Container(
            height: 160,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              color: Colors.grey,
            ),
            child: images.isNotEmpty
                ? PageView.builder(
              itemCount: images.length,
              itemBuilder: (context, index) {
                final file = File(images[index]);
                return file.existsSync()
                    ? Image.file(file, fit: BoxFit.cover, width: double.infinity)
                    : const Center(child: Icon(Icons.broken_image, color: Colors.white));
              },
            )
                : const Center(
              child: Icon(Icons.home_work_outlined, size: 48, color: Colors.white),
            ),
          ),

          // Info Section
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ZK ${property.price.toStringAsFixed(0)}/mo',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.king_bed, size: 18, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${property.bedrooms} Bed'),
                        const SizedBox(width: 12),
                        const Icon(Icons.bathtub, size: 18, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${property.bathrooms} Bath'),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Text(property.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(property.location, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.propertyDetail,
                        arguments: property,
                      );
                    },
                    child: const Text('View Details & Book Visit', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}