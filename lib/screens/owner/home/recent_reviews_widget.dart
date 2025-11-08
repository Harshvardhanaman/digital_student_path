import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';

class RecentReviewsWidget extends StatelessWidget {
  final String ownerId;
  const RecentReviewsWidget({super.key, required this.ownerId});

  @override
  Widget build(BuildContext context) {
    // This stream gets the 5 most recent reviews for this owner
    final Stream<QuerySnapshot> reviewStream = FirebaseFirestore.instance
        .collection('reviews')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Reviews',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shadowColor: Colors.black.withAlpha(26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: StreamBuilder<QuerySnapshot>(
            stream: reviewStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(heightFactor: 3, child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  heightFactor: 3,
                  child: Text('No reviews found yet.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                );
              }
              
              final reviews = snapshot.data!.docs;

              // Use ListView.separated for nice dividers
              return ListView.separated(
                itemCount: reviews.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final reviewData = reviews[index].data() as Map<String, dynamic>;
                  final double rating = (reviewData['rating'] ?? 0.0).toDouble();
                  final Timestamp t = reviewData['createdAt'] ?? Timestamp.now();
                  final String date = DateFormat.yMMMd().format(t.toDate());
                  
                  return ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(reviewData['studentName'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RatingBarIndicator(
                          rating: rating,
                          itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                          itemSize: 18.0,
                        ),
                        if (reviewData['reviewText'] != null && reviewData['reviewText'].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              reviewData['reviewText'], 
                              maxLines: 2, 
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
              );
            },
          ),
        ),
      ],
    );
  }
}