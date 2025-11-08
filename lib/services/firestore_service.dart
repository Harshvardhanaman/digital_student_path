import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // This function will create the user profile
  Future<void> createUserProfile({
    required User user,
    required String role, // This will be "student" or "owner"
  }) async {
    
    final userDoc = _db.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      // Document doesn't exist, so this is a NEW user.
      try {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'phone': user.phoneNumber,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
          
          // --- NEW FIELDS FOR ONBOARDING ---
          'isAdminApproved': false, // Admin must approve this
          'hasCompletedOnboarding': false, // User must fill out the form
          'fullName': null,
          'age': null,
          'state': null,
          'district': null,
          'pincode': null,
          'address': null,
          'hostelAddress': null,
          'aadhaarUrl': null,
          'hostelProofUrl': null,
          'electricityBillUrl': null,
          'profilePhotoUrl': null,
        });
      } catch (e) {
        debugPrint('Error creating user profile: $e');
      }
    } else {
      debugPrint('User profile already exists.');
    }
  }

  // --- NEW FUNCTION TO SUBMIT ONBOARDING DATA ---
  Future<void> submitOwnerOnboarding(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update({
        ...data,
        'hasCompletedOnboarding': true,
      });
    } catch (e) {
      debugPrint('Error submitting onboarding data: $e');
      rethrow; // Rethrow the error to show it on the UI
    }
  }
}