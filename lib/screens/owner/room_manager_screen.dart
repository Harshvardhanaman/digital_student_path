// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_student_path/screens/owner/add_room_screen.dart';
import 'package:digital_student_path/widgets/managed_room_card.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class RoomManagerScreen extends StatefulWidget {
  final String hostelId;

  const RoomManagerScreen({super.key, required this.hostelId});

  @override
  State<RoomManagerScreen> createState() => _RoomManagerScreenState();
}

class _RoomManagerScreenState extends State<RoomManagerScreen> {
  late final Stream<QuerySnapshot> _roomsStream;

  @override
  void initState() {
    super.initState();
    _roomsStream = FirebaseFirestore.instance
        .collection('hostels')
        .doc(widget.hostelId)
        .collection('rooms')
        .snapshots();
  }

  // --- NEW: Logic for Manual Bed Adjustment ---
  Future<void> _adjustBedCount(String roomId, int adjustment) async {
    final DocumentReference roomRef = FirebaseFirestore.instance
        .collection('hostels')
        .doc(widget.hostelId)
        .collection('rooms')
        .doc(roomId);

    // Use a transaction for safety
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final DocumentSnapshot roomSnapshot = await transaction.get(roomRef);
        if (!roomSnapshot.exists) {
          throw Exception("Room does not exist!");
        }

        final int currentBeds = roomSnapshot.get('availableBeds') ?? 0;
        final int totalBeds = roomSnapshot.get('totalBeds') ?? 0;
        final int newBeds = currentBeds + adjustment;

        // Add safety checks
        if (newBeds < 0) {
          throw Exception("Cannot have less than 0 available beds.");
        }
        if (newBeds > totalBeds) {
          throw Exception("Cannot have more available beds than total beds.");
        }

        // Perform the update
        transaction.update(roomRef, {'availableBeds': newBeds});
      });
      // Success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bed count updated!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // --- Delete Room Function (Unchanged) ---
  Future<void> _deleteRoom(DocumentSnapshot roomDoc) async {
    // ... (Your existing delete logic is good, no changes here)
    final data = roomDoc.data() as Map<String, dynamic>;
    final List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to delete this room type? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red), 
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
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
      await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .collection('rooms')
          .doc(roomDoc.id)
          .delete();
      
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room deleted successfully')),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete room: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Room Manager'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddRoomScreen(
                hostelId: widget.hostelId,
                roomDoc: null,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Room Type'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _roomsStream,
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
                'No rooms added yet.\nClick the "+" button to add your first room.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          // --- UPDATED ListView ---
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final DocumentSnapshot document = snapshot.data!.docs[index];
              final Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
              
              final List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);
              final String firstImage = imageUrls.isNotEmpty ? imageUrls[0] : '';
              final int availableBeds = data['availableBeds'] ?? 0;
              final int totalBeds = data['totalBeds'] ?? 0;

              return ManagedRoomCard(
                roomType: data['roomType'] ?? 'No Type',
                price: data['price'] ?? 0,
                availableBeds: availableBeds,
                totalBeds: totalBeds,
                imageUrl: firstImage,
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddRoomScreen(
                        hostelId: widget.hostelId,
                        roomDoc: document,
                      ),
                    ),
                  );
                },
                onDelete: () => _deleteRoom(document),
                // --- NEW: Pass the functions to the card ---
                onDecreaseBed: () => _adjustBedCount(document.id, -1),
                onIncreaseBed: () => _adjustBedCount(document.id, 1),
              );
            },
          );
        },
      ),
    );
  }
}