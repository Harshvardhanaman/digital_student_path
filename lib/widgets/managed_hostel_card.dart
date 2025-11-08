import 'package:flutter/material.dart';

class ManagedHostelCard extends StatelessWidget {
  final String hostelName;
  final String address;
  final String imageUrl;
  final bool isVerified;
  final bool isPublished;
  final VoidCallback onDelete;
  final VoidCallback onManageRooms;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublish;
  final VoidCallback onViewReviews; // NEW

  const ManagedHostelCard({
    super.key,
    required this.hostelName,
    required this.address,
    required this.imageUrl,
    required this.isVerified,
    required this.isPublished,
    required this.onDelete,
    required this.onManageRooms,
    required this.onEdit,
    required this.onTogglePublish,
    required this.onViewReviews, // NEW
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image (Unchanged)
          imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  height: 180,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                        heightFactor: 4, child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.broken_image, size: 180, color: Colors.grey);
                  },
                )
              : Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Icon(Icons.apartment, size: 100, color: Colors.grey),
                ),
          
          // Details (Unchanged)
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
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // --- MANAGEMENT ROW (UPDATED) ---
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status Badge
                Chip(
                  label: Text(
                    isVerified ? (isPublished ? 'Published' : 'Unpublished') : 'Pending',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: isVerified ? (isPublished ? Colors.green : Colors.grey) : Colors.orange,
                  padding: const EdgeInsets.all(4),
                ),
                
                // Use a flexible row for buttons
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // --- NEW: View Reviews Button ---
                        IconButton(
                          icon: const Icon(Icons.reviews_outlined, color: Colors.purple),
                          tooltip: 'View Reviews',
                          onPressed: onViewReviews,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                          tooltip: 'Edit Details',
                          onPressed: onEdit,
                        ),
                        IconButton(
                          icon: const Icon(Icons.king_bed_outlined, color: Colors.teal),
                          tooltip: 'Manage Rooms',
                          onPressed: onManageRooms,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete Hostel',
                          onPressed: onDelete,
                        ),
                        // Publish Toggle Button
                        IconButton(
                          icon: Icon(isPublished ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          color: isVerified ? Colors.black : Colors.grey[400],
                          tooltip: isVerified ? (isPublished ? 'Unpublish' : 'Publish') : 'Pending Admin Approval',
                          onPressed: isVerified ? onTogglePublish : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}