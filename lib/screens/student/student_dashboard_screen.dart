import 'package:digital_student_path/screens/student/browse_hostels_screen.dart';
import 'package:digital_student_path/widgets/banner_carousel.dart'; // NEW IMPORT
import 'package:flutter/material.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BannerCarousel(), // <-- NEW BANNER
          const Text(
            'Welcome, Student!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BrowseHostelsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.search),
            label: const Text('Find a Hostel / PG'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }
}