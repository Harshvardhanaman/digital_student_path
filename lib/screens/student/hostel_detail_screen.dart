// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; // Import for ratings
import 'package:intl/intl.dart'; // Import for date formatting

class HostelDetailScreen extends StatefulWidget {
  final String hostelId;
  const HostelDetailScreen({super.key, required this.hostelId});

  @override
  State<HostelDetailScreen> createState() => _HostelDetailScreenState();
}

// Add 'SingleTickerProviderStateMixin' for the TabBar
class _HostelDetailScreenState extends State<HostelDetailScreen> with SingleTickerProviderStateMixin {
  late final Future<DocumentSnapshot> _hostelFuture;
  late final Stream<QuerySnapshot> _roomsStream;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  late final TabController _tabController; // Tab controller

  @override
  void initState() {
    super.initState();
    _hostelFuture = FirebaseFirestore.instance
        .collection('hostels')
        .doc(widget.hostelId)
        .get();
        
    _roomsStream = FirebaseFirestore.instance
        .collection('hostels')
        .doc(widget.hostelId)
        .collection('rooms')
        .snapshots();
        
    _tabController = TabController(length: 2, vsync: this); // Initialize tabs
  }

  @override
  void dispose() {
    _tabController.dispose(); // Dispose controller
    super.dispose();
  }

  // --- THIS IS THE BOOKING LOGIC (UPDATED) ---
  Future<void> _createBooking(
    DocumentSnapshot roomDoc, 
    Map<String, dynamic> hostelData
  ) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to book.')),
      );
      return;
    }

    final roomData = roomDoc.data() as Map<String, dynamic>;
    
    // Get student info & query
    final studentDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
    final studentData = studentDoc.data();
    final String studentName = studentData?['fullName'] ?? 'N/A';
    final String studentPhone = studentData?['phone'] ?? 'N/A';
    final TextEditingController queryController = TextEditingController();
    
    // 1. Show a confirmation dialog
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Booking: ${roomData['roomType']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Book this room for ₹${roomData['price']} per month?'),
            const SizedBox(height: 16),
            TextField(
              controller: queryController,
              decoration: const InputDecoration(
                labelText: 'Add a query (optional)',
                hintText: 'e.g., "Can I check in early?"',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirm == null || !confirm) return;

    // 2. Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 3. Create the booking document
      await FirebaseFirestore.instance.collection('bookings').add({
        'studentId': _currentUser.uid,
        'ownerId': hostelData['ownerUid'],
        'hostelId': widget.hostelId,
        'roomId': roomDoc.id,
        'hostelName': hostelData['hostelName'],
        'roomType': roomData['roomType'],
        'price': roomData['price'],
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        
        // Add student details
        'studentName': studentName,
        'studentPhone': studentPhone,
        'query': queryController.text,
      });

      // 4. Close loading dialog
      Navigator.pop(context); 

      // 5. Show success and pop back to browse screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking request sent successfully!')),
      );
      Navigator.pop(context); // Go back to browse screen

    } catch (e) {
      // Close loading dialog and show error
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send booking: $e')),
      );
    }
  }
  
  // --- Write a Review Pop-up Sheet ---
  void _showWriteReviewSheet(String studentName, String ownerId) {
    final reviewController = TextEditingController();
    double rating = 3; // Default rating
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to grow
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20, left: 20, right: 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Write a Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              RatingBar.builder(
                initialRating: rating,
                minRating: 1,
                allowHalfRating: true,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (rating) {
                  rating = rating;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reviewController,
                decoration: const InputDecoration(
                  labelText: 'Your review (optional)',
                  hintText: 'Share your experience...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await _submitReview(studentName, rating, reviewController.text, ownerId);
                  Navigator.pop(ctx);
                },
                child: const Text('Submit Review'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
  
  // --- Submit Review Logic (UPDATED) ---
  Future<void> _submitReview(String studentName, double rating, String reviewText, String ownerId) async {
    if (_currentUser == null) return;
    
    try {
      await FirebaseFirestore.instance.collection('reviews').add({
        'hostelId': widget.hostelId,
        'ownerId': ownerId, // This is the new, critical line
        'studentId': _currentUser.uid,
        'studentName': studentName,
        'rating': rating,
        'reviewText': reviewText,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted! Thank you.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit review: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hostel Details'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _hostelFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Hostel not found.'));
          }

          final hostelData = snapshot.data!.data() as Map<String, dynamic>;
          final List<String> imageUrls = List<String>.from(hostelData['imageUrls'] ?? []);

          return Column(
            children: [
              // 1. Image Carousel
              if (imageUrls.isNotEmpty)
                SizedBox(
                  height: 250,
                  child: PageView.builder(
                    itemCount: imageUrls.length,
                    itemBuilder: (context, index) {
                      return Image.network(
                        imageUrls[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          return progress == null ? child : const Center(child: CircularProgressIndicator());
                        },
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: const Icon(Icons.apartment, size: 120, color: Colors.grey),
                ),
              
              // 2. Tab Bar
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Details & Rooms'),
                  Tab(text: 'Reviews'),
                ],
              ),
              
              // 3. Tab Bar View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // --- Tab 1: Details & Rooms ---
                    _buildDetailsTab(hostelData),
                    // --- Tab 2: Reviews ---
                    _buildReviewsTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Widget for Tab 1 ---
  Widget _buildDetailsTab(Map<String, dynamic> hostelData) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hostelData['hostelName'] ?? 'No Name',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    hostelData['address'] ?? 'No Address',
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              hostelData['description'] ?? 'No description available.',
              style: const TextStyle(fontSize: 16),
            ),
            const Divider(height: 32),
            const Text(
              'Available Rooms',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: _roomsStream,
              builder: (context, roomSnapshot) {
                if (roomSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!roomSnapshot.hasData || roomSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No rooms listed for this hostel.'));
                }
                return ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: roomSnapshot.data!.docs.map((roomDoc) {
                    final roomData = roomDoc.data() as Map<String, dynamic>;
                    final int available = roomData['availableBeds'] ?? 0;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(roomData['roomType'] ?? 'No Type', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Price: ₹${roomData['price']}\nAvailable Beds: $available'),
                        isThreeLine: true,
                        trailing: ElevatedButton(
                          onPressed: available > 0 ? () => _createBooking(roomDoc, hostelData) : null,
                          child: const Text('Book Now'),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // --- Widget for Tab 2 (UPDATED) ---
  Widget _buildReviewsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Write Your Review'),
            onPressed: () async {
              // Get student's name to auto-fill
              final studentDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
              final String studentName = studentDoc.data()?['fullName'] ?? 'Anonymous Student';
              
              // Get the ownerId from the hostel document
              final hostelData = (await _hostelFuture).data() as Map<String, dynamic>;
              final String ownerId = hostelData['ownerUid'];
              
              _showWriteReviewSheet(studentName, ownerId); // Pass both
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40) // Full width
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reviews')
                .where('hostelId', isEqualTo: widget.hostelId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Be the first to leave a review!'));
              }
              
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final reviewData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
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
                          itemSize: 20.0,
                        ),
                        const SizedBox(height: 4),
                        if (reviewData['reviewText'] != null && reviewData['reviewText'].isNotEmpty)
                          Text(reviewData['reviewText']),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}