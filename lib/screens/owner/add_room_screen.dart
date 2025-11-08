// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';

class AddRoomScreen extends StatefulWidget {
  final String hostelId;
  final DocumentSnapshot? roomDoc; // For "Edit Mode"

  const AddRoomScreen({super.key, required this.hostelId, this.roomDoc});

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- Controllers ---
  final _roomTypeController = TextEditingController();
  final _priceController = TextEditingController();
  final _totalBedsController = TextEditingController();

  // --- State for features ---
  final Map<String, bool> _features = {
    'WiFi': false,
    'AC': false,
    'Non-AC': false,
    'Attached Bathroom': false,
    'Fan': false,
    'Cooler': false,
    'Geyser': false,
    'Balcony': false,
    'Window': false,
    'Furnished': false,
    'Semi-Furnished': false,
  };

  // --- State for images ---
  final List<XFile> _pickedImages = [];
  final List<String> _existingImageUrls = [];
  
  bool _isLoading = false;
  bool get _isEditMode => widget.roomDoc != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final data = widget.roomDoc!.data() as Map<String, dynamic>;
      _roomTypeController.text = data['roomType'] ?? '';
      _priceController.text = (data['price'] ?? '').toString();
      _totalBedsController.text = (data['totalBeds'] ?? '').toString();

      // Load existing features
      if (data['features'] != null) {
        final Map<String, dynamic> featuresFromDb = Map<String, dynamic>.from(data['features']);
        _features.forEach((key, value) {
          if (featuresFromDb.containsKey(key)) {
            _features[key] = featuresFromDb[key] as bool;
          }
        });
      }

      // Load existing images
      if (data['imageUrls'] != null) {
        _existingImageUrls.addAll(List<String>.from(data['imageUrls']));
      }
    }
  }

  // --- Helper Widget for building styled sections ---
  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            width: double.infinity,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: primaryColor),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children
            ),
          ),
        ],
      ),
    );
  }

  // --- Image Picker ---
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile> images = await picker.pickMultiImage(imageQuality: 70);
      if (images.isNotEmpty) {
        setState(() {
          _pickedImages.addAll(images);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  // --- Submit Form ---
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors in the form.')),
      );
      return;
    }

    if (_pickedImages.isEmpty && !_isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo of the room.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> imageUrls = List.from(_existingImageUrls);

      // 1. Upload new images
      for (XFile imageFile in _pickedImages) {
        String fileName = 'room_${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('hostel_images') // You can use the same main folder
            .child(widget.hostelId) // Create a subfolder for this hostel
            .child(fileName);
        await storageRef.putFile(File(imageFile.path));
        String downloadUrl = await storageRef.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      // 2. Prepare room data
      final int totalBeds = int.tryParse(_totalBedsController.text) ?? 0;
      final Map<String, dynamic> roomData = {
        'roomType': _roomTypeController.text,
        'price': int.tryParse(_priceController.text) ?? 0,
        'totalBeds': totalBeds,
        'availableBeds': totalBeds, // This will be updated by bookings
        'features': _features,
        'imageUrls': imageUrls,
        'createdAt': _isEditMode 
            ? widget.roomDoc!['createdAt'] 
            : FieldValue.serverTimestamp(),
      };
      
      // 3. Get reference to the 'rooms' subcollection
      final roomCollectionRef = FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .collection('rooms');

      if (_isEditMode) {
        // Update existing room
        await roomCollectionRef.doc(widget.roomDoc!.id).update(roomData);
      } else {
        // Add new room
        await roomCollectionRef.add(roomData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditMode ? 'Room updated!' : 'New room added!')),
        );
        Navigator.pop(context); // Go back
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save room: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final inputTheme = InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      labelStyle: TextStyle(color: Colors.grey[700]),
      prefixIconColor: Colors.grey[600],
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Room' : 'Add New Room'),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(inputDecorationTheme: inputTheme),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView( 
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // --- Card 1: Room Details ---
                _buildFormSection(
                  title: 'Room Details',
                  icon: Icons.king_bed_outlined,
                  children: [
                    TextFormField(
                      controller: _roomTypeController,
                      decoration: const InputDecoration(labelText: 'Room Type (e.g., 2-Seater AC)', prefixIcon: Icon(Icons.meeting_room_outlined)),
                      validator: (value) => (value == null || value.isEmpty) ? 'Please enter a room type' : null,
                    ),
                    const SizedBox(height: 16),
                    // --- Horizontal row for Price and Beds ---
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(labelText: 'Price (₹)', prefixIcon: Icon(Icons.currency_rupee)),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) => (value == null || value.isEmpty) ? 'Enter price' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _totalBedsController,
                            decoration: const InputDecoration(labelText: 'Total Beds', prefixIcon: Icon(Icons.bed_outlined)),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) => (value == null || value.isEmpty) ? 'Enter beds' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // --- Card 2: Facilities ---
                _buildFormSection(
                  title: 'Room Facilities',
                  icon: Icons.check_box_outlined,
                  children: [
                    // A scrollable grid for all the checkboxes
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 4.0, // Make items wide
                      children: _features.keys.map((String key) {
                        return CheckboxListTile(
                          title: Text(key, style: const TextStyle(fontSize: 14)),
                          value: _features[key],
                          onChanged: (bool? value) {
                            setState(() {
                              _features[key] = value!;
                            });
                          },
                          activeColor: primaryColor,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      }).toList(),
                    ),
                  ],
                ),
                
                // --- Card 3: Room Photos ---
                _buildFormSection(
                  title: 'Room Photos',
                  icon: Icons.photo_camera_back_outlined,
                  children: [
                    const Text('Add clear photos of this room type.', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    _buildUploadBox(
                      onTap: _pickImages,
                      images: [..._existingImageUrls, ..._pickedImages],
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                        ),
                        child: Text(_isEditMode ? 'Save Changes' : 'Add Room'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- BUILDER for UPLOAD BOX (Re-used) ---
  Widget _buildUploadBox({required VoidCallback onTap, required List<dynamic> images}) {
    final primaryColor = Theme.of(context).primaryColor;
    return DottedBorder(
      color: primaryColor.withOpacity(0.5),
      strokeWidth: 2,
      dashPattern: const [6, 4],
      borderType: BorderType.RRect,
      radius: const Radius.circular(12),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: images.isNotEmpty
            ? Stack(
                children: [
                  ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      Widget imageWidget;
                      if (images[index] is String) {
                        imageWidget = Image.network(images[index], fit: BoxFit.cover, width: 130);
                      } else {
                        imageWidget = Image.file(File((images[index] as XFile).path), fit: BoxFit.cover, width: 130);
                      }
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageWidget,
                        ),
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FloatingActionButton.small(
                        onPressed: onTap,
                        child: const Icon(Icons.add_a_photo_outlined),
                      ),
                    ),
                  )
                ],
              )
            : InkWell(
                onTap: onTap,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined,
                          size: 40, color: primaryColor),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to select (Gallery or Camera)',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}