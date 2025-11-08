import 'package:flutter/material.dart';

class ManagedRoomCard extends StatelessWidget {
  final String roomType;
  final int price;
  final int availableBeds;
  final int totalBeds;
  final String imageUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  // NEW: Callbacks for manual bed adjustment
  final VoidCallback onDecreaseBed;
  final VoidCallback onIncreaseBed;

  const ManagedRoomCard({
    super.key,
    required this.roomType,
    required this.price,
    required this.availableBeds,
    required this.totalBeds,
    required this.imageUrl,
    required this.onEdit,
    required this.onDelete,
    required this.onDecreaseBed,
    required this.onIncreaseBed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      // ignore: deprecated_member_use
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          // Image (Unchanged)
          imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  height: 120, // Adjusted height
                  width: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      width: 100,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
                )
              : Container(
                  height: 120,
                  width: 100,
                  color: Colors.grey[200],
                  child: const Icon(Icons.king_bed_outlined, size: 50, color: Colors.grey),
                ),
          
          // Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomType,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹$price / month',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),

                  // --- NEW: Interactive Availability Section ---
                  Text(
                    'Availability:',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  Row(
                    children: [
                      // Decrease Button
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Colors.red,
                        onPressed: onDecreaseBed,
                        iconSize: 20,
                      ),
                      Text(
                        '$availableBeds / $totalBeds',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      // Increase Button
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: Colors.green,
                        onPressed: onIncreaseBed,
                        iconSize: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                color: Colors.blue,
                tooltip: 'Edit Room',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
                tooltip: 'Delete Room',
                onPressed: onDelete,
              ),
            ],
          )
        ],
      ),
    );
  }
}