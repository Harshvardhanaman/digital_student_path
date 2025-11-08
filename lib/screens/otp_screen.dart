import 'package:digital_student_path/services/firestore_service.dart'; // NEW
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String role; // NEW: Accept the role

  const OtpScreen({
    super.key, 
    required this.verificationId,
    required this.role, // NEW
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // NEW: Create instance of FirestoreService
  final FirestoreService _firestoreService = FirestoreService(); 
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOtp(String smsCode) async {
    setState(() {
      _isLoading = true;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: smsCode,
      );

      // Sign the user in
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      // NEW: Check if we have a user and create their profile
      if (userCredential.user != null) {
        await _firestoreService.createUserProfile(
          user: userCredential.user!,
          role: widget.role, // Pass the role
        );
      }

      if (mounted) {
        Navigator.pop(context); // Pop the OTP screen
        Navigator.pop(context); // Pop the Login screen
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign in: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... your build method (no changes needed) ...
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter OTP'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'We sent a 6-digit code to your phone. Please enter it below.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 30),

              // The Pinput widget
              Pinput(
                controller: _pinController,
                length: 6,
                autofocus: true,
                onCompleted: (pin) {
                  // When 6 digits are entered, automatically try to verify
                  _verifyOtp(pin);
                },
              ),
              const SizedBox(height: 30),

              // Show loading circle or Verify button
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        if (_pinController.text.length == 6) {
                          _verifyOtp(_pinController.text);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter 6-digit code')),
                          );
                        }
                      },
                      child: const Text('Verify OTP'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}