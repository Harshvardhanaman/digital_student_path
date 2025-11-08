import 'package:digital_student_path/screens/owner/home/owner_home_screen.dart';
import 'package:digital_student_path/screens/owner/hostels/owner_hostels_screen.dart';
import 'package:digital_student_path/screens/owner/profile/owner_profile_screen.dart';
import 'package:flutter/material.dart';

class OwnerMainScreen extends StatefulWidget {
  const OwnerMainScreen({super.key});

  @override
  State<OwnerMainScreen> createState() => _OwnerMainScreenState();
}

class _OwnerMainScreenState extends State<OwnerMainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      OwnerHomeScreen(onNavigateToHostels: () => _onItemTapped(1)), 
      const OwnerHostelsScreen(),
      const OwnerProfileScreen(),
    ];
  }

  static const List<String> _titles = <String>[
    'Owner Dashboard',
    'My Hostels',
    'My Profile',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        // --- THE ACTIONS BUTTON IS NOW REMOVED FROM HERE ---
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_work_outlined),
            activeIcon: Icon(Icons.home_work),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment_outlined),
            activeIcon: Icon(Icons.apartment),
            label: 'Hostels',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}