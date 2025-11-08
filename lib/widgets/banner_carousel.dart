import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  
  @override
  Widget build(BuildContext context) {
    // This stream listens to the 'banners' collection
    // The Admin Panel will write to this collection
    final Stream<QuerySnapshot> bannerStream = FirebaseFirestore.instance
        .collection('banners')
        .where('isActive', isEqualTo: true) // Only show active banners
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: bannerStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // If no banners, show an empty box
          return const SizedBox.shrink();
        }

        final banners = snapshot.data!.docs;

        return Container(
          height: 150, // Fixed height for the banner
          margin: const EdgeInsets.only(bottom: 16.0),
          child: PageView.builder(
            controller: _pageController,
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final bannerData = banners[index].data() as Map<String, dynamic>;
              final String imageUrl = bannerData['imageUrl'] ?? '';
              
              // Use a Card for a modern look
              return Card(
                elevation: 2,
                shadowColor: Colors.black.withAlpha(26),
                clipBehavior: Clip.antiAlias, // Clips the image
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        // Show loading
                        loadingBuilder: (context, child, progress) {
                          return progress == null ? child : const Center(child: CircularProgressIndicator());
                        },
                        // Show error
                        errorBuilder: (context, error, stack) {
                          return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
                        },
                      )
                    : const Center(child: Icon(Icons.image, color: Colors.grey)),
              );
            },
          ),
        );
      },
    );
  }
}