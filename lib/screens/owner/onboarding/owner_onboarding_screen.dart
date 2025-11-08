import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart'; // This was unused
import 'package:digital_student_path/services/firestore_service.dart';

import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:intl/intl.dart';

class OwnerOnboardingScreen extends StatefulWidget {
  const OwnerOnboardingScreen({super.key});

  @override
  State<OwnerOnboardingScreen> createState() => _OwnerOnboardingScreenState();
}

class _OwnerOnboardingScreenState extends State<OwnerOnboardingScreen> {
  // Stepper state
  int _currentStep = 0;

  // Services and User
  final User? _user = FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();

  // Step 1: Form Details
  final _step1FormKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _hostelAddressController = TextEditingController();

  DateTime? _selectedDateOfBirth;
  String? _selectedCountry = "India";
  String? _selectedState;
  String? _selectedDistrict;
  bool _sameAsAddress = false;

  // --- Mock data for dropdowns ---
  final List<String> _countries = ["India"];
  final List<String> _states = [
    "Bihar",
    "Jharkhand",
    "Uttar Pradesh",
    "West Bengal"
  ];
  final Map<String, List<String>> _districts = {
    "Bihar": ["Patna", "Begusarai", "Muzaffarpur", "Gaya"],
    "Jharkhand": ["Ranchi", "Dhanbad"],
    "Uttar Pradesh": ["Lucknow", "Varanasi"],
    "West Bengal": ["Kolkata", "Howrah"],
  };

  // Step 2: Document Uploads
  final ImagePicker _picker = ImagePicker();
  File? _aadhaarFile;
  File? _hostelProofFile;
  File? _electricityBillFile;

  // Loading State
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (_user != null) {
      if (_user.email != null && _user.email!.isNotEmpty) {
        _emailController.text = _user.email!;
      }
      if (_user.phoneNumber != null && _user.phoneNumber!.isNotEmpty) {
        String phone = _user.phoneNumber!;
        if (phone.startsWith('+91')) {
          phone = phone.substring(3);
        }
        _phoneController.text = phone;
      }
    }
    _requestPermissions();
  }

  // --- 1. PERMISSION LOGIC (Unchanged) ---
  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.camera,
      Permission.notification,
      Permission.contacts,
    ].request();
  }

  // --- 2. STEPPER LOGIC (Unchanged) ---
  void _onStepContinue() {
    if (_currentStep == 0) {
      if (_step1FormKey.currentState!.validate()) {
        if (_selectedDateOfBirth == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select your Date of Birth.')),
          );
          return;
        }
        setState(() => _currentStep += 1);
      }
    } else if (_currentStep == 1) {
      if (_aadhaarFile == null || _hostelProofFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aadhaar and Hostel Proof are required.')),
        );
      } else {
        setState(() => _currentStep += 1);
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  // --- 3. IMAGE PICKER LOGIC (Unchanged) ---
  Future<File?> _pickImage(ImageSource source) async {
    final XFile? pickedFile =
        await _picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  void _showImagePicker(Function(File) onFilePicked) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pick from Gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await _pickImage(ImageSource.gallery);
                  if (file != null) onFilePicked(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Picture'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await _pickImage(ImageSource.camera);
                  if (file != null) onFilePicked(file);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Date Picker Function (Unchanged) ---
  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      helpText: 'Select Your Date of Birth',
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dobController.text = DateFormat.yMMMMd().format(picked);
      });
    }
  }

  // --- 4. SUBMISSION LOGIC (Unchanged) ---
  Future<void> _submitOnboarding() async {
    if (!_step1FormKey.currentState!.validate() ||
        _aadhaarFile == null ||
        _hostelProofFile == null ||
        _selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      if (!_step1FormKey.currentState!.validate() ||
          _selectedDateOfBirth == null) {
        setState(() => _currentStep = 0);
      } else {
        setState(() => _currentStep = 1);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String aadhaarUrl = await _uploadFile(_aadhaarFile!, 'aadhaar');
      final String hostelProofUrl =
          await _uploadFile(_hostelProofFile!, 'hostel_proof');
      String? electricityBillUrl;
      if (_electricityBillFile != null) {
        electricityBillUrl =
            await _uploadFile(_electricityBillFile!, 'electricity_bill');
      }

      final Map<String, dynamic> data = {
        'fullName': _fullNameController.text,
        'dateOfBirth': _selectedDateOfBirth,
        'email': _emailController.text,
        'phone': '+91${_phoneController.text}',
        'country': _selectedCountry,
        'state': _selectedState,
        'district': _selectedDistrict,
        'pincode': _pincodeController.text,
        'address': _addressController.text,
        'hostelAddress': _hostelAddressController.text,
        'aadhaarUrl': aadhaarUrl,
        'hostelProofUrl': hostelProofUrl,
        'electricityBillUrl': electricityBillUrl,
      };

      await _firestoreService.submitOwnerOnboarding(_user!.uid, data);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission Failed: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<String> _uploadFile(File file, String type) async {
    final String fileName =
        '${_user!.uid}_${type}_${DateTime.now().millisecondsSinceEpoch}';
    final Reference ref = FirebaseStorage.instance
        .ref()
        .child('owner_documents')
        .child(fileName);

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  // --- NEW: Helper Widget for building styled section headers ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Submitting your details...', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    // --- NEW: Define modern form theme ---
    final primaryColor = Theme.of(context).primaryColor;
    final backgroundColor = Colors.grey[50];
    final inputTheme = InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[100], // Light fill for fields
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none, // No border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: primaryColor, width: 2), // Highlight
      ),
      labelStyle: TextStyle(color: Colors.grey[700]),
      prefixIconColor: Colors.grey[600],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: inputTheme,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor, // Set background
        body: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          // FIXED: Removed the invalid 'backgroundColor' property
          elevation: 0,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                children: [
                  if (_currentStep == 2)
                    ElevatedButton.icon(
                      onPressed: _submitOnboarding,
                      icon: const Icon(Icons.check),
                      label: const Text('SUBMIT FOR APPROVAL'),
                    )
                  else
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: const Text('NEXT'),
                    ),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('BACK'),
                    ),
                ],
              ),
            );
          },
          steps: [
            // --- STEP 1: OWNER DETAILS ---
            Step(
              title: const Text('Details'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _buildStep1Form(),
            ),
            // --- STEP 2: DOCUMENT UPLOAD ---
            Step(
              title: const Text('Documents'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _buildStep2Upload(),
            ),
            // --- STEP 3: REVIEW & SUBMIT ---
            Step(
              title: const Text('Submit'),
              isActive: _currentStep >= 2,
              content: _buildStep3Review(),
            ),
          ],
        ),
      ),
    );
  }

  // --- BUILDER for STEP 1 FORM (COMPLETELY REBUILT) ---
  Widget _buildStep1Form() {
    return Form(
      key: _step1FormKey,
      child: Column(
        children: [
          // --- Personal Details Card ---
          _buildFormSection(
            title: 'Personal Details',
            icon: Icons.person_pin_circle_outlined,
            // NEW: Using Wrap for horizontal layout
            child: Wrap(
              spacing: 16, // Horizontal spacing
              runSpacing: 16, // Vertical spacing
              children: [
                _buildFormField(
                  controller: _fullNameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  validator: (val) => val!.isEmpty ? 'Enter your full name' : null,
                ),
                _buildFormField(
                  controller: _dobController,
                  label: 'Date of Birth',
                  icon: Icons.calendar_today_outlined,
                  readOnly: true,
                  onTap: () => _selectDateOfBirth(context),
                  validator: (val) => val!.isEmpty ? 'Select DOB' : null,
                ),
                _buildFormField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  enabled: _user?.email == null || _user!.email!.isEmpty,
                  validator: (val) => val!.isEmpty ? 'Enter email' : null,
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildFormField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  prefixText: '+91 ',
                  enabled: _user?.phoneNumber == null || _user!.phoneNumber!.isEmpty,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10)
                  ],
                  keyboardType: TextInputType.phone,
                  validator: (val) => val!.length != 10 ? 'Enter a 10-digit number' : null,
                ),
              ],
            ),
          ),

          // --- Location Details Card ---
          _buildFormSection(
            title: 'Location Details',
            icon: Icons.map_outlined,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildDropdownField(
                  items: _countries,
                  label: 'Country',
                  icon: Icons.public_outlined,
                  selectedItem: _selectedCountry,
                  onChanged: (val) => setState(() => _selectedCountry = val),
                  validator: (val) => val == null ? 'Select country' : null,
                ),
                _buildDropdownField(
                  items: _states,
                  label: 'State',
                  icon: Icons.maps_home_work_outlined,
                  selectedItem: _selectedState,
                  onChanged: (val) {
                    setState(() {
                      _selectedState = val;
                      _selectedDistrict = null;
                    });
                  },
                  validator: (val) => val == null ? 'Select state' : null,
                ),
                _buildDropdownField(
                  items: _districts[_selectedState] ?? [],
                  label: 'District',
                  icon: Icons.location_city_outlined,
                  selectedItem: _selectedDistrict,
                  onChanged: (val) => setState(() => _selectedDistrict = val),
                  validator: (val) => val == null ? 'Select district' : null,
                  enabled: _selectedState != null,
                ),
                _buildFormField(
                  controller: _pincodeController,
                  label: 'Pincode',
                  icon: Icons.pin_drop_outlined,
                  keyboardType: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6)
                  ],
                  validator: (val) => val!.length != 6 ? 'Enter 6-digit pincode' : null,
                ),
              ],
            ),
          ),

          // --- Address Details Card ---
          _buildFormSection(
            title: 'Address Details',
            icon: Icons.home_work_outlined,
            child: Column( // Address fields are wide, so Column is fine here
              children: [
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                      labelText: 'Your Full Address',
                      prefixIcon: Icon(Icons.home_work_outlined)),
                  validator: (val) => val!.isEmpty ? 'Enter your address' : null,
                  onChanged: (val) {
                    if (_sameAsAddress) {
                      _hostelAddressController.text = val;
                    }
                  },
                  maxLines: 2,
                ),
                CheckboxListTile(
                  title: const Text('Hostel address is same as above'),
                  value: _sameAsAddress,
                  onChanged: (val) {
                    setState(() {
                      _sameAsAddress = val!;
                      if (_sameAsAddress) {
                        _hostelAddressController.text = _addressController.text;
                      } else {
                        _hostelAddressController.text = '';
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hostelAddressController,
                  decoration: const InputDecoration(
                      labelText: 'Hostel Full Address',
                      prefixIcon: Icon(Icons.apartment_outlined)),
                  enabled: !_sameAsAddress,
                  validator: (val) =>
                      val!.isEmpty ? 'Enter hostel address' : null,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW: Helper for horizontal text fields ---
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    bool readOnly = false,
    VoidCallback? onTap,
    List<TextInputFormatter>? formatters,
    TextInputType? keyboardType,
    String? prefixText,
    bool enabled = true,
  }) {
    // This box controls the size of the fields in the Wrap
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 200, // Minimum width for a field
        maxWidth: 300,  // Maximum width
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          prefixText: prefixText,
        ),
        readOnly: readOnly,
        onTap: onTap,
        validator: validator,
        inputFormatters: formatters,
        keyboardType: keyboardType,
        enabled: enabled,
      ),
    );
  }

  // --- NEW: Helper for horizontal dropdown fields ---
  Widget _buildDropdownField({
    required List<String> items,
    required String label,
    required IconData icon,
    required String? selectedItem,
    required void Function(String?) onChanged,
    required String? Function(String?) validator,
    bool enabled = true,
  }) {
    // This box controls the size of the fields in the Wrap
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 200, // Minimum width
        maxWidth: 300,  // Maximum width
      ),
      child: DropdownSearch<String>(
        items: items, // FIXED: Use 'items' for simple lists
        selectedItem: selectedItem,
        popupProps: const PopupProps.menu(showSearchBox: true),
        // FIXED: Use 'dropdownDecoratorProps' for styling
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
          ),
        ),
        onChanged: onChanged,
        validator: validator,
        enabled: enabled,
      ),
    );
  }

  // --- BUILDER for STEP 2 UPLOAD (UPDATED) ---
  Widget _buildStep2Upload() {
    return _buildFormSection(
      title: 'Upload Documents',
      icon: Icons.file_upload_outlined,
      // NEW: Use a Wrap for horizontal/responsive layout
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: [
          _buildUploadBox(
            label: 'Aadhaar Card (Required)',
            file: _aadhaarFile,
            onTap: () {
              _showImagePicker((file) => setState(() => _aadhaarFile = file));
            },
          ),
          _buildUploadBox(
            label: 'Hostel Proof (Required)',
            subtitle: '(e.g., Rent agreement)',
            file: _hostelProofFile,
            onTap: () {
              _showImagePicker(
                  (file) => setState(() => _hostelProofFile = file));
            },
          ),
          _buildUploadBox(
            label: 'Electricity Bill (Optional)',
            file: _electricityBillFile,
            onTap: () {
              _showImagePicker(
                  (file) => setState(() => _electricityBillFile = file));
            },
          ),
        ],
      ),
    );
  }

  // --- BUILDER for UPLOAD BOX (UPDATED) ---
  Widget _buildUploadBox({
    required String label,
    String? subtitle,
    required File? file, 
    required VoidCallback onTap
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    return SizedBox(
      width: 250, // Give the upload box a fixed width
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (subtitle != null)
            Text(subtitle, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTap,
            child: DottedBorder(
              color: primaryColor.withAlpha(128), // FIXED: withOpacity
              strokeWidth: 2,
              dashPattern: const [6, 4],
              borderType: BorderType.RRect,
              radius: const Radius.circular(12),
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(13), // FIXED: withOpacity
                  borderRadius: BorderRadius.circular(12),
                ),
                child: file != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(file, fit: BoxFit.cover),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(77) // FIXED: withOpacity
                                  ),
                              child: const Icon(Icons.check_circle,
                                  color: Colors.white, size: 40),
                            )
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined,
                                size: 40, color: primaryColor),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to select',
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
          ),
        ],
      ),
    );
  }

  // --- BUILDER for STEP 3 REVIEW (UPDATED) ---
  Widget _buildStep3Review() {
    return _buildFormSection(
      title: 'Review & Submit',
      icon: Icons.check_circle_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Please review all your details before submitting.',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          _buildReviewRow('Full Name:', _fullNameController.text),
          _buildReviewRow('Date of Birth:', _dobController.text),
          _buildReviewRow('Email:', _emailController.text),
          _buildReviewRow('Phone:', '+91${_phoneController.text}'),
          _buildReviewRow('Address:', _addressController.text),
          _buildReviewRow('Hostel Address:', _hostelAddressController.text),
          const Divider(height: 20),
          _buildReviewRow(
              'Aadhaar File:', _aadhaarFile != null ? 'Uploaded ✅' : 'Missing ❌'),
          _buildReviewRow('Hostel Proof File:',
              _hostelProofFile != null ? 'Uploaded ✅' : 'Missing ❌'),
          _buildReviewRow('Electricity Bill:',
              _electricityBillFile != null ? 'Uploaded ✅' : 'Not Uploaded'),
          const SizedBox(height: 20),
          const Text(
            'By submitting, you agree to our terms and confirm that this information is accurate.',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  // --- NEW: Helper for section card ---
  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required Widget child, // Child is now a single widget (like a Wrap or Column)
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withAlpha(26), // FIXED: withOpacity
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16.0), // Space between cards
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colorful Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            width: double.infinity,
            decoration: BoxDecoration(
              color: primaryColor.withAlpha(26), // FIXED: withOpacity
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
          // Form fields
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ],
      ),
    );
  }
}