import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingManagementScreen extends StatefulWidget {
  // NEW: Add this to control which tab opens first
  final int initialTabIndex;

  const BookingManagementScreen({
    super.key, 
    this.initialTabIndex = 0 // Default to 'Pending'
  });

  @override
  State<BookingManagementScreen> createState() => _BookingManagementScreenState();
}

class _BookingManagementScreenState extends State<BookingManagementScreen> with SingleTickerProviderStateMixin {
  final User? _user = FirebaseAuth.instance.currentUser;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // NEW: Set length to 4 and use the initialTabIndex
    _tabController = TabController(
      length: 4, 
      vsync: this, 
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Accept Booking Logic (Unchanged) ---
  Future<void> _acceptBooking(DocumentSnapshot bookingDoc) async {
    final String bookingId = bookingDoc.id;
    final String hostelId = bookingDoc['hostelId'];
    final String roomId = bookingDoc['roomId'];

    final FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      await db.runTransaction((transaction) async {
        final DocumentReference roomRef = db.collection('hostels').doc(hostelId).collection('rooms').doc(roomId);
        final DocumentSnapshot roomSnapshot = await transaction.get(roomRef);

        if (!roomSnapshot.exists) {
          throw Exception("Room no longer exists!");
        }

        final int availableBeds = roomSnapshot.get('availableBeds') ?? 0;
        if (availableBeds <= 0) {
          throw Exception("No available beds left in this room!");
        }

        transaction.update(roomRef, {
          'availableBeds': availableBeds - 1
        });
        
        final DocumentReference bookingRef = db.collection('bookings').doc(bookingId);
        transaction.update(bookingRef, {
          'status': 'approved'
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking Approved! Bed count updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $e')),
        );
      }
    }
  }

  // --- Reject Booking Logic (Unchanged) ---
  Future<void> _rejectBooking(String bookingId) async {
    try {
      await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
        'status': 'rejected'
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking Rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Allow tabs to scroll if needed
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
            Tab(text: 'All Bookings'), // NEW TAB
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList(
            ownerId: _user.uid,
            status: 'pending',
            showActions: true, 
          ),
          _buildBookingsList(
            ownerId: _user.uid,
            status: 'approved',
            showActions: false,
          ),
          _buildBookingsList(
            ownerId: _user.uid,
            status: 'rejected',
            showActions: false,
          ),
          // NEW TAB VIEW
          _buildBookingsList(
            ownerId: _user.uid,
            status: null, // Pass null to show all
            showActions: false,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList({
    required String ownerId,
    required String? status, // Can be null
    required bool showActions,
  }) {
    // --- UPDATED: Create a dynamic query ---
    Query query = FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerId', isEqualTo: ownerId);

    // If a status is provided, filter by it
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    
    // Always order by date
    final Stream<QuerySnapshot> stream = query
        .orderBy('requestedAt', descending: true) 
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No ${status ?? 'total'} bookings.',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final Timestamp t = data['requestedAt'] ?? Timestamp.now();
            final String formattedDate = DateFormat.yMMMd().add_jm().format(t.toDate());
            
            // NEW: Get student details from the booking
            final String studentName = data['studentName'] ?? 'Student';
            final String studentPhone = data['studentPhone'] ?? 'No phone';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    title: Text(data['roomType'] ?? 'No Room Type', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Hostel: ${data['hostelName']}\nPrice: ₹${data['price']}\nRequested: $formattedDate',
                    ),
                    isThreeLine: true,
                    // NEW: Show student details on tap
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Student Details'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(studentName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Phone: $studentPhone'),
                              const SizedBox(height: 8),
                              Text('Query: ${data['query'] ?? 'No query'}'),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
                          ],
                        ),
                      );
                    },
                  ),
                  if (showActions)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _rejectBooking(doc.id),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _acceptBooking(doc),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
                    )
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}