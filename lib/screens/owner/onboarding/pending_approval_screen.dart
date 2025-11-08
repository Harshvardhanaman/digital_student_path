import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings_outlined, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Thank You for Submitting!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Your profile is under review by our admin team. This usually takes 24-48 hours.\n\nYou will be able to add hostels once approved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 30),
            OutlinedButton.icon(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            )
          ],
        ),
      ),
    );
  }
}