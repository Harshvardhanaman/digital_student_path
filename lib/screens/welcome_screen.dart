import 'package:digital_student_path/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Import package

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  
  @override
  void initState() {
    super.initState();
    // Request permissions as soon as the screen loads
    _requestAllPermissions();
  }

  Future<void> _requestAllPermissions() async {
    // Request all permissions you listed
    // Note: 'phone' covers call access.
    // 'contacts' is very sensitive, be sure you need it!
    await [
      Permission.location,
      Permission.notification,
      Permission.camera,
      Permission.phone,
      Permission.contacts, // Added Contacts
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.school_outlined, 
                  size: 100, 
                  color: Theme.of(context).primaryColor
                ),
                const SizedBox(height: 20),
                const Text(
                  'Welcome to\nDigital Student Path',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 50),
                const Text(
                  'Please select your role to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 30),

                // "Student" Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(isOwner: false),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: const Text("I'm a Student"),
                ),
                const SizedBox(height: 20),

                // "Owner" Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(isOwner: true),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.blueGrey[700],
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: const Text("I'm an Owner"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}