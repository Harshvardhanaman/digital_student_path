import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_student_path/widgets/hostel_card.dart';
import 'package:flutter/material.dart';
import 'package:digital_student_path/screens/student/hostel_detail_screen.dart';

class BrowseHostelsScreen extends StatelessWidget {
  const BrowseHostelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // --- UPDATED QUERY ---
    // Now filters for BOTH verification AND publishing
    final Stream<QuerySnapshot> hostelsStream = FirebaseFirestore.instance
        .collection('hostels')
        .where('isVerified', isEqualTo: true)
        .where('isPublished', isEqualTo: true) // NEW FILTER
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Hostels & PGs'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: hostelsStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          
          // --- NEW: Check for Firestore Index Error ---
          if (snapshot.hasError) {
            if (snapshot.error.toString().contains('permission-denied') || snapshot.error.toString().contains('requires an index')) {
              return _buildIndexErrorWidget(context);
            }
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No hostels available right now.\nCheck back later!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView(
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data =
                  document.data()! as Map<String, dynamic>;
              List<String> imageUrls =
                  List<String>.from(data['imageUrls'] ?? []);
              String firstImage = imageUrls.isNotEmpty ? imageUrls[0] : '';

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HostelDetailScreen(
                        hostelId: document.id,
                      ),
                    ),
                  );
                },
                child: HostelCard(
                  hostelName: data['hostelName'] ?? 'No Name',
                  address: data['address'] ?? 'No Address',
                  imageUrl: firstImage,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // --- NEW: Helper widget to show the Firestore Index error ---
  Widget _buildIndexErrorWidget(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Action Required',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'A database index is required for this feature. Please go to your Firebase Console to create it.\n\n(This message is only visible in development. Your app will crash if this is not fixed.)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            SelectableText(
              'Go to the Firebase Console link in the error log (in your VS Code "Debug Console") and click it to auto-create the index.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}