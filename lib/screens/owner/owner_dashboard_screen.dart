import 'package:digital_student_path/screens/owner/add_hostel_screen.dart';
import 'package:digital_student_path/screens/owner/booking_management_screen.dart';
// FIXED: Import the new hostels screen
import 'package:digital_student_path/screens/owner/hostels/owner_hostels_screen.dart'; 
import 'package:flutter/material.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome, Owner!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BookingManagementScreen(),
                ),
              );
            },
            icon: const Icon(Icons.calendar_today),
            label: const Text('Manage Bookings'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddHostelScreen(hostelDoc: null),
                ),
              );
            },
            icon: const Icon(Icons.add_home_work),
            label: const Text('Add a New Hostel / PG'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  // FIXED: Call the new screen
                  builder: (context) => const OwnerHostelsScreen(), 
                ),
              );
            },
            icon: const Icon(Icons.apartment),
            label: const Text('Manage My Hostels'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }
}