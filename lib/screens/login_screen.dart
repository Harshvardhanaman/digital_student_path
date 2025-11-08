import 'package:digital_student_path/screens/otp_screen.dart';
// NEW: Import our new service
import 'package:digital_student_path/services/firestore_service.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  final bool isOwner;
  const LoginScreen({super.key, required this.isOwner});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  // NEW: Create an instance of our service
  final FirestoreService _firestoreService = FirestoreService(); 

  // 🔹 PHONE AUTH LOGIC
  Future<void> _verifyPhoneNumber() async {
    if (_phoneController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }
    final String phoneNumber = '+91${_phoneController.text.trim()}';
    setState(() => _isLoading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        
        // NEW: Check if we have a user and create their profile
        if (userCredential.user != null) {
          await _firestoreService.createUserProfile(
            user: userCredential.user!,
            role: widget.isOwner ? 'owner' : 'student',
          );
        }
        
        if (!mounted) return;
        setState(() => _isLoading = false);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification Failed: ${e.message}')),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            // NEW: We need to pass the role to the OTP screen
            builder: (context) => OtpScreen(
              verificationId: verificationId,
              role: widget.isOwner ? 'owner' : 'student',
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // 🔹 GOOGLE AUTH LOGIC (2025 FIXED)
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

     try {
    final GoogleSignIn googleSignIn = GoogleSignIn.standard(
      scopes: ['email', 'profile'],
    );
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    // NEW: Get the UserCredential from the sign-in
    final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

    // NEW: Check if we have a user and create their profile
    if (userCredential.user != null) {
      await _firestoreService.createUserProfile(
        user: userCredential.user!,
        role: 'owner', // Google sign-in is only for owners
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google Sign-In Successful')),
    );
    Navigator.pop(context);
    
  } catch (e) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Google Sign-In Failed: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    // ... your build method (no changes needed) ...
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOwner ? 'Owner Login' : 'Student Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Enter 10-digit Phone Number',
                  hintText: '12345 67890',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: 20),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _verifyPhoneNumber,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('Send OTP', style: TextStyle(fontSize: 18)),
                    ),

              const SizedBox(height: 40),

              if (widget.isOwner)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('OR'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _isLoading
                        ? const SizedBox()
                        : ElevatedButton.icon(
                            onPressed: _signInWithGoogle,
                            icon: Image.asset('assets/google_logo.png', height: 24),
                            label: const Text(
                              'Continue with Google',
                              style: TextStyle(fontSize: 18),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                          ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}