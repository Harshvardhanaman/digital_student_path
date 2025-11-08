import 'package:flutter/material.dart';

class HostelCard extends StatelessWidget {
  final String hostelName;
  final String address;
  final String imageUrl; // We'll show the first image as a preview

  const HostelCard({
    super.key,
    required this.hostelName,
    required this.address,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      clipBehavior: Clip.antiAlias, // Clips the image to the card's rounded corners
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. The Image
          // We check if the imageUrl is valid, otherwise show a placeholder
          imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  height: 180,
                  fit: BoxFit.cover,
                  // Show a loading circle while the image is loading
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      heightFactor: 4,
                      child: CircularProgressIndicator(),
                    );
                  },
                  // Show an error icon if the image fails to load
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.broken_image, size: 180, color: Colors.grey);
                  },
                )
              : Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Icon(Icons.apartment, size: 100, color: Colors.grey),
                ),
          
          // 2. The Details
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hostelName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 18, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(fontSize: 16, color: Colors.black54),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}