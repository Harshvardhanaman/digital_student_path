import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_student_path/screens/owner/add_hostel_screen.dart';
import 'package:digital_student_path/screens/owner/hostels/hostel_reviews_screen.dart';
import 'package:digital_student_path/screens/owner/room_manager_screen.dart';
import 'package:digital_student_path/widgets/managed_hostel_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class OwnerHostelsScreen extends StatefulWidget {
  const OwnerHostelsScreen({super.key});

  @override
  State<OwnerHostelsScreen> createState() => _OwnerHostelsScreenState();
}

class _OwnerHostelsScreenState extends State<OwnerHostelsScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  late final Stream<QuerySnapshot> _hostelsStream;

  @override
  void initState() {
    super.initState();
    if (_user == null) {
      _hostelsStream = const Stream.empty();
    } else {
      _hostelsStream = FirebaseFirestore.instance
          .collection('hostels')
          .where('ownerUid', isEqualTo: _user.uid)
          .snapshots();
    }
  }

  // Publish/Unpublish Logic (Unchanged)
  Future<void> _togglePublish(String docId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('hostels')
          .doc(docId)
          .update({'isPublished': !currentStatus});
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(currentStatus ? 'Hostel unpublished' : 'Hostel published')),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  // Delete Hostel Logic (Unchanged)
  Future<void> _deleteHostel(String docId, List<String> imageUrls) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: const Text('This will permanently delete your hostel listing and all its rooms.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              // ignore: sort_child_properties_last
              child: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
    if (confirm == null || !confirm) return;
    try {
      for (String url in imageUrls) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (e) {
          debugPrint('Failed to delete image $url: $e');
        }
      }
      await FirebaseFirestore.instance.collection('hostels').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hostel deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete hostel: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: Text('Error: You are not logged in.')));
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddHostelScreen(hostelDoc: null),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _hostelsStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No hostels found.\nTap the "+" button to add one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final DocumentSnapshot document = snapshot.data!.docs[index];
              final Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
              final List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);
              final String firstImage = imageUrls.isNotEmpty ? imageUrls[0] : '';
              final String hostelName = data['hostelName'] ?? 'No Name';
              final bool isPublished = data['isPublished'] ?? true; 
              final bool isVerified = data['isVerified'] ?? false;

              return ManagedHostelCard(
                hostelName: hostelName,
                address: data['address'] ?? 'No Address',
                imageUrl: firstImage,
                isVerified: isVerified,
                isPublished: isPublished,
                onDelete: () => _deleteHostel(document.id, imageUrls),
                onManageRooms: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoomManagerScreen(hostelId: document.id),
                    ),
                  );
                },
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddHostelScreen(hostelDoc: document),
                    ),
                  );
                },
                onTogglePublish: () => _togglePublish(document.id, isPublished),
                // --- NEW: Wire up the reviews button ---
                onViewReviews: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HostelReviewsScreen(
                        hostelId: document.id,
                        hostelName: hostelName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}