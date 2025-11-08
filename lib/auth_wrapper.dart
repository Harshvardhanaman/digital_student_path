import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_student_path/screens/owner/onboarding/owner_onboarding_screen.dart';
import 'package:digital_student_path/screens/owner/onboarding/pending_approval_screen.dart';
// NEW: Import the main owner hub
import 'package:digital_student_path/screens/owner/owner_main_screen.dart'; 
import 'package:digital_student_path/screens/student/student_dashboard_screen.dart';
import 'package:digital_student_path/screens/welcome_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const WelcomeScreen();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(authSnapshot.data!.uid)
              .snapshots(),
          builder: (context, userDocSnapshot) {
            
            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
              FirebaseAuth.instance.signOut();
              return const WelcomeScreen();
            }

            final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
            final String role = userData['role'];

            // --- ROUTING LOGIC ---

            if (role == 'student') {
              // For students, we still show the simple dashboard
              return Scaffold(
                appBar: AppBar(title: const Text('Student Dashboard'), actions: [
                  IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())
                ]),
                body: const StudentDashboardScreen(),
              );
            } 
            
            if (role == 'owner') {
              final bool hasCompletedOnboarding = userData['hasCompletedOnboarding'] ?? false;
              final bool isAdminApproved = userData['isAdminApproved'] ?? false;
              
              if (!hasCompletedOnboarding) {
                // Show onboarding form with its own Scaffold
                return Scaffold(
                  appBar: AppBar(title: const Text('Owner Verification')),
                  body: const OwnerOnboardingScreen(),
                );
              } else if (!isAdminApproved) {
                // Show pending screen with its own Scaffold
                return Scaffold(
                  appBar: AppBar(title: const Text('Pending Approval')),
                  body: const PendingApprovalScreen(),
                );
              } else {
                // --- NEW: User is approved, show the 3-tab main screen ---
                return const OwnerMainScreen();
              }
            }

            // Fallback
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Unknown user role. Logging out.'),
                    ElevatedButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Logout'),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}