import 'dart:async';
import 'package:async/async.dart'; // Needed for StreamZip
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_student_path/screens/owner/booking_management_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:digital_student_path/widgets/banner_carousel.dart';
import 'package:flutter/material.dart';
import 'package:digital_student_path/screens/owner/home/recent_reviews_widget.dart';
import 'package:fl_chart/fl_chart.dart'; // Chart package
import 'package:rxdart/rxdart.dart'; // For switchMap

class OwnerHomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToHostels;
  
  const OwnerHomeScreen({super.key, required this.onNavigateToHostels});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  final String? ownerId = FirebaseAuth.instance.currentUser?.uid;

  // --- STREAMS ---
  late final Stream<QuerySnapshot> pendingBookingsStream;
  late final Stream<QuerySnapshot> approvedBookingsStream;
  late final Stream<QuerySnapshot> totalBookingsStream;
  late final Stream<QuerySnapshot> totalHostelsStream;
  late final Stream<Map<String, int>> roomAnalyticsStream;

  @override
  void initState() {
    super.initState();
    if (ownerId != null) {
      pendingBookingsStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'pending')
          .snapshots();

      approvedBookingsStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'approved')
          .snapshots();
      
      totalBookingsStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('ownerId', isEqualTo: ownerId)
          .snapshots();
          
      totalHostelsStream = FirebaseFirestore.instance
          .collection('hostels')
          .where('ownerUid', isEqualTo: ownerId)
          .snapshots();

      roomAnalyticsStream = _createRoomAnalyticsStream(ownerId!);
    } else {
      pendingBookingsStream = const Stream.empty();
      approvedBookingsStream = const Stream.empty();
      totalBookingsStream = const Stream.empty();
      totalHostelsStream = const Stream.empty();
      roomAnalyticsStream = Stream.value({'rooms': 0, 'totalBeds': 0, 'availableBeds': 0});
    }
  }

  // --- Real-time function to get all room counts ---
  Stream<Map<String, int>> _createRoomAnalyticsStream(String ownerId) {
    final hostelStream = FirebaseFirestore.instance
        .collection('hostels')
        .where('ownerUid', isEqualTo: ownerId)
        .snapshots();

    return hostelStream.switchMap((hostelSnapshot) {
      final int totalRooms = hostelSnapshot.docs.length;

      if (hostelSnapshot.docs.isEmpty) {
        return Stream.value({
          'rooms': 0,
          'totalBeds': 0, 
          'availableBeds': 0,
        });
      }

      List<Stream<QuerySnapshot>> roomStreams = [];
      for (final hostelDoc in hostelSnapshot.docs) {
        roomStreams.add(hostelDoc.reference.collection('rooms').snapshots());
      }

      return StreamZip(roomStreams).map((listOfRoomSnapshots) {
        int totalBeds = 0;
        int availableBeds = 0;

        for (final roomSnapshot in listOfRoomSnapshots) {
          for (final roomDoc in roomSnapshot.docs) {
            totalBeds += (roomDoc.get('totalBeds') ?? 0) as int;
            availableBeds += (roomDoc.get('availableBeds') ?? 0) as int;
          }
        }

        return {
          'rooms': totalRooms,
          'totalBeds': totalBeds, 
          'availableBeds': availableBeds,
        };
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    if (ownerId == null) {
      return const Center(child: Text('Error: Not logged in.'));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const BannerCarousel(),
          const Text(
            'CONTROL PANEL',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,),
          ),
          const SizedBox(height: 16),

          // --- STAT CARDS ---
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12, 
            mainAxisSpacing: 12, 
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.3,
            children: [
              _buildStreamStatCard(
                icon: Icons.access_alarm_rounded,
                color: Colors.orange,
                label: 'Booking Requests',
                stream: pendingBookingsStream,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const BookingManagementScreen(initialTabIndex: 0),
                  ));
                },
              ),
              _buildStreamStatCard(
                icon: Icons.check_circle_outline,
                color: Colors.green,
                label: 'Approved Bookings',
                stream: approvedBookingsStream,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const BookingManagementScreen(initialTabIndex: 1),
                  ));
                },
              ),
              // This card now shows 'Total Hostels'
              _buildStreamStatCard(
                icon: Icons.apartment_outlined,
                color: Colors.blue,
                label: 'Total Hostels',
                stream: totalHostelsStream,
                onTap: widget.onNavigateToHostels, 
              ),
              _buildStreamStatCard(
                icon: Icons.calendar_today_outlined,
                color: Colors.purple,
                label: 'Total Bookings',
                stream: totalBookingsStream,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const BookingManagementScreen(initialTabIndex: 3),
                  ));
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- BOOKING ANALYTICS ---
          const Text(
            'Booking Analytics',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: Card(
              elevation: 2,
              shadowColor: Colors.black.withAlpha(26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: StreamBuilder<List<QuerySnapshot>>(
                  stream: StreamZip([ 
                    pendingBookingsStream,
                    approvedBookingsStream,
                  ]),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Error loading chart'));
                    }
                    final int pendingCount = snapshot.data![0].docs.length;
                    final int approvedCount = snapshot.data![1].docs.length;
                    return BarChart(_buildBookingChart(pendingCount, approvedCount));
                  },
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // --- ROOM ANALYTICS (NOW REAL-TIME) ---
          const Text(
            'Room Analytics',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          StreamBuilder<Map<String, int>>(
            stream: roomAnalyticsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final int totalBeds = snapshot.data!['totalBeds'] ?? 0;
              final int availableBeds = snapshot.data!['availableBeds'] ?? 0;
              final int occupiedBeds = totalBeds - availableBeds;
              final int totalRooms = snapshot.data!['rooms'] ?? 0;
              
              return Column(
                children: [
                  // This card shows Total Beds
                  _buildSimpleStatCard(
                    icon: Icons.king_bed_outlined,
                    color: Colors.teal,
                    label: 'Total Beds',
                    count: totalBeds,
                    onTap: widget.onNavigateToHostels,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: Card(
                      elevation: 2,
                      shadowColor: Colors.black.withAlpha(26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: PieChart(_buildRoomChart(availableBeds, occupiedBeds)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'You have $totalRooms rooms',
                                    style: const TextStyle(fontSize: 14, color: Colors.black54, fontStyle: FontStyle.italic),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPieLegend(Colors.teal, 'Vacant', availableBeds),
                                  const SizedBox(height: 12),
                                  _buildPieLegend(Colors.red[400]!, 'Occupied', occupiedBeds),
                                  const SizedBox(height: 12),
                                  _buildPieLegend(Colors.grey[400]!, 'Total', totalBeds),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          RecentReviewsWidget(ownerId: ownerId!),
          
          const SizedBox(height: 24),

        ],
      ),
    );
  }

  // --- Helper for Pie Chart Legend ---
  Widget _buildPieLegend(Color color, String label, int value) {
    return Row(
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54), overflow: TextOverflow.ellipsis),
              Text(value.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        )
      ],
    );
  }

  // --- Builder for cards that listen to QuerySnapshot STREAMS ---
  Widget _buildStreamStatCard({
    required IconData icon,
    required Color color,
    required String label,
    required Stream<QuerySnapshot> stream,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withAlpha(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell( 
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 28, color: color),
              StreamBuilder<QuerySnapshot>(
                stream: stream,
                builder: (context, snapshot) {
                  final int count = snapshot.data?.docs.length ?? 0;
                  return Text(
                    count.toString(),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  );
                },
              ),
              Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- THIS FUNCTION IS NO LONGER USED, SO IT IS REMOVED ---
  // --- (This fixes your error) ---
  // Widget _buildRoomStatCard({ ... }) { ... }
  
  // --- Helper for building a stat card from a simple number ---
  Widget _buildSimpleStatCard({
    required IconData icon,
    required Color color,
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withAlpha(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell( 
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 28, color: color),
              Text(
                count.toString(),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }


  // --- This builds the Bar Chart ---
  BarChartData _buildBookingChart(int pending, int approved) {
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(enabled: false),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (double value, TitleMeta meta) {
              String text = '';
              if (value.toInt() == 0) text = 'Pending';
              if (value.toInt() == 1) text = 'Approved';
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              );
            },
            reservedSize: 32,
          ),
        ),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(show: false),
      barGroups: [
        BarChartGroupData(
          x: 0,
          barRods: [
            BarChartRodData(
              toY: pending.toDouble(),
              color: Colors.orange,
              width: 30,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
        BarChartGroupData(
          x: 1,
          barRods: [
            BarChartRodData(
              toY: approved.toDouble(),
              color: Colors.green,
              width: 30,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ],
    );
  }

  // --- This builds the Pie Chart ---
  PieChartData _buildRoomChart(int available, int occupied) {
    final double total = (available + occupied).toDouble();
    if (total == 0) {
      return PieChartData(
        sections: [
          PieChartSectionData(
            color: Colors.grey[300],
            value: 1,
            title: 'No Beds',
            radius: 40,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
        ],
        centerSpaceRadius: 30,
      );
    }
    
    return PieChartData(
      sections: [
        PieChartSectionData(
          color: Colors.teal,
          value: available.toDouble(),
          title: '$available\nVacant',
          radius: 40,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        PieChartSectionData(
          color: Colors.red[400],
          value: occupied.toDouble(),
          title: '$occupied\nOccupied',
          radius: 40,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
      sectionsSpace: 4,
      centerSpaceRadius: 30,
    );
  }
}