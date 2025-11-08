import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // Make sure this is imported

class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({super.key});

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _changeProfilePhoto() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final File imageFile = File(pickedFile.path);
      final String fileName = '${_user!.uid}_profile.jpg';
      final Reference ref = FirebaseStorage.instance.ref().child('profile_photos').child(fileName);

      await ref.putFile(imageFile);
      final String downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(_user.uid).update({
        'profilePhotoUrl': downloadUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated!')),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Center(child: Text('Error: Not logged in.'));
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(_user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.data!.exists) {
          return const Center(child: Text('Could not load profile.'));
        }

        final data = snapshot.data!.data()!;
        final String profilePhotoUrl = data['profilePhotoUrl'] ?? '';

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- Profile Header ---
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: profilePhotoUrl.isNotEmpty 
                          ? NetworkImage(profilePhotoUrl) 
                          : null,
                      child: profilePhotoUrl.isEmpty 
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                    if (_isUploading)
                      const Positioned.fill(
                        child: CircularProgressIndicator(),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Material(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: _changeProfilePhoto,
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Icon(Icons.edit, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  data['fullName'] ?? 'Owner',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),

              // --- Details Card ---
              Card(
                elevation: 2,
                // ignore: deprecated_member_use
                shadowColor: Colors.black.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _buildProfileTile(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      subtitle: data['email'] ?? 'Not provided',
                    ),
                    _buildProfileTile(
                      icon: Icons.phone_outlined,
                      title: 'Phone',
                      subtitle: data['phone'] ?? 'Not provided',
                    ),
                    _buildProfileTile(
                      icon: Icons.calendar_today_outlined,
                      title: 'Date of Birth',
                      subtitle: data['dateOfBirth'] != null 
                          ? DateFormat.yMMMMd().format((data['dateOfBirth'] as Timestamp).toDate())
                          : 'Not provided',
                    ),
                    _buildProfileTile(
                      icon: Icons.home_work_outlined,
                      title: 'Address',
                      subtitle: data['address'] ?? 'Not provided',
                    ),
                    _buildProfileTile(
                      icon: Icons.location_on_outlined,
                      title: 'District & State',
                      subtitle: '${data['district'] ?? ''}, ${data['state'] ?? ''}',
                      isLast: true,
                    ),
                  ],
                ),
              ),

              // --- NEW LOGOUT BUTTON ---
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)
                  )
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Reusable styled ListTile ---
  Widget _buildProfileTile({
    required IconData icon, 
    required String title, 
    required String subtitle, 
    bool isLast = false
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Theme.of(context).primaryColor),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 16)),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 72.0, right: 16.0),
            child: Divider(height: 1, color: Colors.grey[200]),
          )
      ],
    );
  }
}