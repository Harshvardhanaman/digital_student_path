import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';

class HostelReviewsScreen extends StatelessWidget {
  final String hostelId;
  final String hostelName;

  const HostelReviewsScreen({
    super.key, 
    required this.hostelId, 
    required this.hostelName
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reviews for $hostelName'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('hostelId', isEqualTo: hostelId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('This hostel has no reviews yet.'));
          }
          
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final reviewData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final double rating = (reviewData['rating'] ?? 0.0).toDouble();
              final Timestamp t = reviewData['createdAt'] ?? Timestamp.now();
              final String date = DateFormat.yMMMd().format(t.toDate());
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(reviewData['studentName'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      RatingBarIndicator(
                        rating: rating,
                        itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                        itemSize: 20.0,
                      ),
                      if (reviewData['reviewText'] != null && reviewData['reviewText'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(reviewData['reviewText']),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}