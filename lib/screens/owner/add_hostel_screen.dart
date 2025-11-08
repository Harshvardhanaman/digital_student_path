// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dotted_border/dotted_border.dart';
// We need this for the time formatter

class AddHostelScreen extends StatefulWidget {
  final DocumentSnapshot? hostelDoc;

  const AddHostelScreen({super.key, this.hostelDoc});

  @override
  State<AddHostelScreen> createState() => _AddHostelScreenState();
}

class _AddHostelScreenState extends State<AddHostelScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- Controllers for all our new fields ---
  final _hostelNameController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _gateCloseTimeController = TextEditingController(); // NEW: For time

  // --- State for new UI elements ---
  String? _hostelType; // 'Boys', 'Girls', 'Co-ed'
  bool _hasCCTV = false; // NEW: For security
  TimeOfDay? _gateCloseTime; // NEW: For time
  
  final Map<String, bool> _features = {
    'WiFi': false,
    'AC': false,
    'Non-AC': false,
    'Mess': false,
    'RO Water': false,
    'Laundry': false,
    'Parking': false,
    'Furnished': false,
    'Semi-Furnished': false,
  };

  final List<XFile> _pickedImages = [];
  final List<String> _existingImageUrls = [];
  
  bool _isLoading = false;
  bool get _isEditMode => widget.hostelDoc != null;

  @override
  void initState() {
    super.initState();
    // If we are in Edit Mode, pre-fill all the fields
    if (_isEditMode) {
      final data = widget.hostelDoc!.data() as Map<String, dynamic>;
      _hostelNameController.text = data['hostelName'] ?? '';
      _addressController.text = data['address'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      
      _hostelType = data['type'];
      _minPriceController.text = (data['minPrice'] ?? '').toString();
      _maxPriceController.text = (data['maxPrice'] ?? '').toString();
      _capacityController.text = (data['capacity'] ?? '').toString();

      // Load existing features
      if (data['features'] != null) {
        final Map<String, dynamic> featuresFromDb = Map<String, dynamic>.from(data['features']);
        _features.forEach((key, value) {
          if (featuresFromDb.containsKey(key)) {
            _features[key] = featuresFromDb[key] as bool;
          }
        });
      }
      
      // --- NEW: Load Security Fields ---
      _hasCCTV = data['hasCCTV'] ?? false;
      if (data['gateCloseTime'] != null) {
        final Timestamp timestamp = data['gateCloseTime'] as Timestamp;
        final DateTime time = timestamp.toDate();
        _gateCloseTime = TimeOfDay.fromDateTime(time);
        // We can't use context here, so we format manually
        final String period = _gateCloseTime!.period == DayPeriod.am ? "AM" : "PM";
        _gateCloseTimeController.text = '${_gateCloseTime!.hourOfPeriod}:${_gateCloseTime!.minute.toString().padLeft(2, '0')} $period';
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

  // --- Image Picker (Unchanged) ---
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
  
  // --- NEW: Time Picker Function ---
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _gateCloseTime ?? const TimeOfDay(hour: 22, minute: 0), // Default to 10 PM
    );
    if (picked != null && picked != _gateCloseTime) {
      setState(() {
        _gateCloseTime = picked;
        _gateCloseTimeController.text = picked.format(context); // e.g., "10:00 PM"
      });
    }
  }

  // --- Submit Form (UPDATED) ---
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors in the form.')),
      );
      return;
    }
    
    if (_hostelType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a hostel type (Boys, Girls, or Co-ed).')),
      );
      return;
    }

    if (_pickedImages.isEmpty && !_isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('You are not logged in!');

      List<String> imageUrls = List.from(_existingImageUrls);

      for (XFile imageFile in _pickedImages) {
        String fileName = 'hostel_${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
        Reference storageRef = FirebaseStorage.instance.ref().child('hostel_images').child(fileName);
        await storageRef.putFile(File(imageFile.path));
        String downloadUrl = await storageRef.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      // --- Prepare the full dataset ---
      final Map<String, dynamic> hostelData = {
        'ownerUid': user.uid,
        'hostelName': _hostelNameController.text,
        'address': _addressController.text,
        'description': _descriptionController.text,
        'imageUrls': imageUrls,
        
        'type': _hostelType,
        'minPrice': int.tryParse(_minPriceController.text) ?? 0,
        'maxPrice': int.tryParse(_maxPriceController.text) ?? 0,
        'capacity': int.tryParse(_capacityController.text) ?? 0,
        'features': _features,
        
        // --- NEW FIELDS ---
        'hasCCTV': _hasCCTV,
        'gateCloseTime': _gateCloseTime != null 
            ? Timestamp.fromDate(DateTime(2000, 1, 1, _gateCloseTime!.hour, _gateCloseTime!.minute)) 
            : null,
        
        'isVerified': false,
        'isPublished': true,
        'createdAt': _isEditMode 
            ? widget.hostelDoc!['createdAt']
            : FieldValue.serverTimestamp(),
      };

      if (_isEditMode) {
        await FirebaseFirestore.instance
            .collection('hostels')
            .doc(widget.hostelDoc!.id)
            .update(hostelData);
      } else {
        await FirebaseFirestore.instance
            .collection('hostels')
            .add(hostelData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditMode ? 'Hostel updated successfully!' : 'Hostel added successfully!')),
        );
        Navigator.pop(context); // Go back
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save hostel: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Define modern form theme ---
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
        title: Text(_isEditMode ? 'Edit Hostel' : 'Add New Hostel'),
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
                
                // --- Card 1: Basic Details ---
                _buildFormSection(
                  title: 'Basic Details',
                  icon: Icons.notes_outlined,
                  children: [
                    TextFormField(
                      controller: _hostelNameController,
                      decoration: const InputDecoration(labelText: 'Hostel Name', prefixIcon: Icon(Icons.apartment)),
                      validator: (value) => (value == null || value.isEmpty) ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    Text('Hostel Type*', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    
                    // --- THIS IS THE FIX ---
                    SegmentedButton<String>(
                      emptySelectionAllowed: true, // Allow user to deselect
                      segments: const [
                        ButtonSegment(value: 'Boys', label: Text('Boys'), icon: Icon(Icons.male)),
                        ButtonSegment(value: 'Girls', label: Text('Girls'), icon: Icon(Icons.female)),
                        ButtonSegment(value: 'Co-ed', label: Text('Co-ed'), icon: Icon(Icons.people)),
                      ],
                      selected: _hostelType != null ? {_hostelType!} : {},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          if (newSelection.isEmpty) {
                            _hostelType = null; // Explicitly set to null
                          } else {
                            _hostelType = newSelection.first;
                          }
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        selectedBackgroundColor: primaryColor.withOpacity(0.2),
                        selectedForegroundColor: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minPriceController,
                            decoration: const InputDecoration(labelText: 'Min Price (₹)', prefixIcon: Icon(Icons.currency_rupee)),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) => (value == null || value.isEmpty) ? 'Enter min price' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _maxPriceController,
                            decoration: const InputDecoration(labelText: 'Max Price (₹)', prefixIcon: Icon(Icons.currency_rupee)),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) => (value == null || value.isEmpty) ? 'Enter max price' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _capacityController,
                      decoration: const InputDecoration(labelText: 'Total Capacity (Beds)', prefixIcon: Icon(Icons.king_bed_outlined)),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) => (value == null || value.isEmpty) ? 'Enter capacity' : null,
                    ),
                  ],
                ),

                // --- Card 2: Features & Amenities ---
                _buildFormSection(
                  title: 'Features & Amenities',
                  icon: Icons.wifi_outlined,
                  children: [
                    ..._features.keys.map((String key) {
                      return CheckboxListTile(
                        title: Text(key),
                        value: _features[key],
                        onChanged: (bool? value) {
                          setState(() {
                            _features[key] = value!;
                          });
                        },
                        activeColor: primaryColor,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
                
                // --- NEW: Card 3: Security & Rules ---
                _buildFormSection(
                  title: 'Security & Rules',
                  icon: Icons.security_outlined,
                  children: [
                    CheckboxListTile(
                      title: const Text('CCTV Surveillance'),
                      value: _hasCCTV,
                      onChanged: (bool? value) {
                        setState(() {
                          _hasCCTV = value!;
                        });
                      },
                      activeColor: primaryColor,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _gateCloseTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Gate Close Time',
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                      readOnly: true,
                      onTap: () => _selectTime(context),
                      // This field is optional, so no validator
                    ),
                  ],
                ),

                // --- Card 4: Location & Photos ---
                _buildFormSection(
                  title: 'Location & Photos',
                  icon: Icons.location_on_outlined,
                  children: [
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Full Address', prefixIcon: Icon(Icons.map_outlined)),
                      validator: (value) => (value == null || value.isEmpty) ? 'Please enter an address' : null,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description & Nearby Places',
                        hintText: 'e.g., "5 min walk from PW Coaching", "Near Patna Hospital", etc.',
                        prefixIcon: Icon(Icons.description_outlined)
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 20),
                    const Text('Hostel Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                        child: Text(_isEditMode ? 'Save Changes' : 'Submit for Approval'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- BUILDER for UPLOAD BOX (Unchanged) ---
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