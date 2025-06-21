import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  final bool isRequiredBeforeBooking;
  final VoidCallback? onProfileCompleted;

  const ProfilePage(
      {this.isRequiredBeforeBooking = false, this.onProfileCompleted, Key? key})
      : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<dynamic, dynamic> userData = {};
  bool isLoading = true;
  String errorMessage = '';

  // Text controllers for editable fields
  Map<String, TextEditingController> controllers = {};

  // Date picker controller for date of birth
  DateTime? selectedDate;
  final TextEditingController dobController = TextEditingController();

  // Form validation
  final _formKey = GlobalKey<FormState>();
  bool _hasEmptyFields = false;
  List<String> _emptyFields = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    controllers.values.forEach((controller) => controller.dispose());
    dobController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      // Check if user is logged in
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'You must be signed in to view your profile';
        });
        return;
      }

      // Changed from 'users' to 'register_patient'
      final DatabaseReference ref =
          _database.ref('register_patient/${currentUser.uid}');
      final DatabaseEvent event = await ref.once();

      setState(() {
        isLoading = false;

        if (event.snapshot.exists && event.snapshot.value is Map) {
          Map<dynamic, dynamic> data =
              event.snapshot.value as Map<dynamic, dynamic>;
          userData = data;

          // Create controllers for editable fields
          userData.forEach((key, value) {
            if (key == 'dob') {
              dobController.text = value?.toString() ?? '';
            } else {
              controllers[key.toString()] =
                  TextEditingController(text: value?.toString() ?? '');
            }
          });

          // Add any missing fields
          _ensureAllFieldsExist(currentUser.uid);
        } else {
          // Create empty user profile if none exists
          _createEmptyUserProfile(currentUser.uid);
        }
      });

      // After loading data, check for empty fields if coming from booking flow
      if (widget.isRequiredBeforeBooking) {
        _checkRequiredFields();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading your profile: ${e.toString()}';
      });
    }
  }

  void _createEmptyUserProfile(String uid) {
    // Create basic profile structure with additional fields
    userData = {
      'name': '',
      'email': _auth.currentUser?.email ?? '',
      'phone': '',
      'city': '',
      'gender': '',
      'location': '', // Address
      'apartment': '', // New field for apartment/suite
      'country': 'Malaysia', // Default to Malaysia
      'province': '', // Province/State
      'postalCode': '', // Postal/Zip code
      'dob': '',
      'nationality': '',
      'age': '',
      'race': '',
      'allergies': '',
      'medicalAlert': '',
      'id_no': '',
    };

    // Create controllers
    userData.forEach((key, value) {
      if (key == 'dob') {
        dobController.text = value.toString();
      } else {
        controllers[key.toString()] =
            TextEditingController(text: value.toString());
      }
    });

    // Changed from 'users' to 'register_patient'
    _database.ref('register_patient/$uid').set(userData);

    // Check required fields after creating an empty profile
    if (widget.isRequiredBeforeBooking) {
      _checkRequiredFields();
    }
  }

  Future<void> _saveUserData() async {
    if (_auth.currentUser == null) return;

    // Validate all required fields if this is required before booking
    if (widget.isRequiredBeforeBooking) {
      _checkRequiredFields();
      if (_hasEmptyFields) {
        _showRequiredFieldsDialog();
        return;
      }
    }

    try {
      setState(() => isLoading = true);

      // Update userData from controllers
      controllers.forEach((key, controller) {
        userData[key] = controller.text.trim();
      });

      // Update date of birth separately if it exists
      if (userData.containsKey('dob')) {
        userData['dob'] = dobController.text;
      }

      // Changed from 'users' to 'register_patient'
      await _database
          .ref('register_patient/${_auth.currentUser!.uid}')
          .update(userData.cast<String, Object?>());

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')));

      // If all required fields are filled and we're booking, call the callback
      if (widget.isRequiredBeforeBooking && widget.onProfileCompleted != null) {
        widget.onProfileCompleted!();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to save profile: ${e.toString()}';
      });
    }
  }

  void _ensureAllFieldsExist(String uid) {
    // List of all required fields
    final requiredFields = [
      'name',
      'email',
      'phone',
      'city',
      'gender',
      'location',
      'apartment',
      'country',
      'province',
      'postalCode',
      'dob',
      'nationality',
      'age',
      'race',
      'allergies',
      'medicalAlert',
      'id_no',
    ];

    bool needsUpdate = false;

    // Check for missing fields and add them if needed
    for (String field in requiredFields) {
      if (!userData.containsKey(field)) {
        userData[field] = '';
        controllers[field] = TextEditingController();
        needsUpdate = true;
      }
    }

    // Update database if fields were added
    if (needsUpdate) {
      // Changed from 'users' to 'register_patient'
      _database
          .ref('register_patient/$uid')
          .update(userData.cast<String, Object?>());
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = selectedDate ??
        now.subtract(Duration(days: 365 * 18)); // Default to 18 years ago

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        dobController.text = DateFormat('yyyy-MM-dd').format(picked);

        // Calculate age automatically
        int age = now.year - picked.year;
        if (now.month < picked.month ||
            (now.month == picked.month && now.day < picked.day)) {
          age--;
        }
        controllers['age']?.text = age.toString();
      });
    }
  }

  // Check for required fields
  void _checkRequiredFields() {
    _emptyFields = [];

    // List of fields required for booking
    final requiredFields = [
      'name',
      'phone',
      'city', // Changed from 'location'
      'gender',
      'dob', // Already correct
      'nationality',
      'age',
      'race',
      'location', // Changed from 'address'
      'id_no', // Added new required field
    ];

    for (String field in requiredFields) {
      String value = '';
      if (field == 'dob') {
        value = dobController.text.trim();
      } else if (userData.containsKey(field) &&
          controllers.containsKey(field)) {
        value = controllers[field]!.text.trim();
      }

      if (value.isEmpty) {
        _emptyFields.add(field);
      }
    }

    setState(() {
      _hasEmptyFields = _emptyFields.isNotEmpty;
    });
  }

  void _showRequiredFieldsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Required Fields'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text('Please fill in the following required fields:'),
              SizedBox(height: 10),
              ...List.generate(_emptyFields.length, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text(_formatKey(_emptyFields[index])),
                    ],
                  ),
                );
              })
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removed AppBar
      body: SafeArea(
        child: _buildBody(),
      ),
      floatingActionButton: userData.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _saveUserData,
              icon: Icon(Icons.save),
              label: Text(
                  widget.isRequiredBeforeBooking ? 'Save & Continue' : 'Save'),
              tooltip: 'Save Profile',
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 60),
              SizedBox(height: 16),
              Text(
                'Profile Access Error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700]),
              ),
              // ...existing code...
            ],
          ),
        ),
      );
    }

    if (userData.isEmpty) {
      return const Center(child: Text('No profile data available'));
    }

    // Display editable user profile with custom header replacing AppBar
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Custom header section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isRequiredBeforeBooking
                      ? 'Complete Your Profile'
                      : 'My Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      isLoading = true;
                      errorMessage = '';
                    });
                    _loadUserData();
                  },
                ),
              ],
            ),
          ),

          // Main content in scrollable area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  if (widget.isRequiredBeforeBooking)
                    _buildRequiredFieldsNotice(),

                  _buildSectionHeader('Personal Information'),
                  _buildTextField('name', 'Name', isRequired: true),
                  _buildTextField('email', 'Email'),
                  _buildTextField('phone', 'Phone', isRequired: true),
                  _buildTextField('id_no', 'IC Number',
                      isRequired: true), // Added this line
                  _buildGenderDropdown(),
                  _buildTextField('age', 'Age', isRequired: true),

                  // Date picker field
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      side: _emptyFields.contains('dob')
                          ? BorderSide(color: Colors.red, width: 1)
                          : BorderSide.none,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: TextField(
                        controller: dobController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Date of Birth *',
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _emptyFields.contains('dob')
                                ? Colors.red
                                : Colors.blueAccent,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.calendar_today),
                            onPressed: () => _selectDate(context),
                          ),
                        ),
                        onTap: () => _selectDate(context),
                      ),
                    ),
                  ),

                  _buildSectionHeader('Location Information'),
                  _buildTextField('apartment', 'Apartment, suite, etc.',
                      isRequired: true),
                  _buildTextField('location', 'Address', isRequired: true),
                  _buildTextField('city', 'City', isRequired: true),
                  _buildTextField('postalCode', 'Postal/Zip Code',
                      isRequired: true),
                  _buildCountryDropdown(),
                  _buildProvinceDropdown(),

                  _buildSectionHeader('Background Information'),
                  _buildTextField('nationality', 'Nationality',
                      isRequired: true),
                  _buildRaceDropdown(),

                  _buildSectionHeader('Medical Information'),
                  _buildTextField('allergies', 'Allergies'),
                  _buildTextField('medicalAlert', 'Medical Alert'),

                  SizedBox(height: 80), // Extra space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          Divider(thickness: 1.5),
        ],
      ),
    );
  }

  Widget _buildTextField(String key, String label, {bool isRequired = false}) {
    final controller = controllers[key];
    if (controller == null) return SizedBox.shrink();

    final isFieldEmpty = _emptyFields.contains(key);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        side: isFieldEmpty
            ? BorderSide(color: Colors.red, width: 1)
            : BorderSide.none,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: isFieldEmpty ? Colors.red : Colors.blueAccent,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onChanged: (_) {
            if (widget.isRequiredBeforeBooking && isRequired) {
              _checkRequiredFields();
            }
          },
        ),
      ),
    );
  }

  Widget _buildFirebaseRulesHelp() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended Firebase Rules:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            color: Colors.black87,
            child: Text(
              '''
{
  "rules": {
    "users": {
      "\$userId": {
        ".read": "\$userId === auth.uid",
        ".write": "\$userId === auth.uid"
      }
    },
    "appointments": {
      "\$userId": {
        ".read": "\$userId === auth.uid",
        ".write": "\$userId === auth.uid"
      }
    },
    "profiles": {
      "\$userId": {
        ".read": "\$userId === auth.uid",
        ".write": "\$userId === auth.uid"
      }
    },
    "user": {
      "\$userId": {
        ".read": "\$userId === auth.uid",
        ".write": "\$userId === auth.uid"
      }
    }
  }
}''',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Colors.greenAccent,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    if (key.isEmpty) return '';

    final RegExp regExp = RegExp(r'(?<=[a-z])[A-Z]');
    String result =
        key.replaceAllMapped(regExp, (Match m) => ' ${m.group(0)!}');
    result = result[0].toUpperCase() + result.substring(1);

    return result;
  }

  Widget _buildRequiredFieldsNotice() {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade800),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Required Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.amber.shade800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Please complete all required fields (marked with *) before booking your appointment.',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderDropdown() {
    final key = 'gender';
    final isFieldEmpty = _emptyFields.contains(key);
    final currentValue = controllers[key]?.text;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        side: isFieldEmpty
            ? BorderSide(color: Colors.red, width: 1)
            : BorderSide.none,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: DropdownButtonFormField<String>(
          value: (currentValue != null &&
                  currentValue.isNotEmpty &&
                  (currentValue == 'Male' || currentValue == 'Female'))
              ? currentValue
              : null,
          decoration: InputDecoration(
            labelText: 'Gender *',
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: isFieldEmpty ? Colors.red : Colors.blueAccent,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          items: ['Male', 'Female'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              controllers[key]?.text = newValue ?? '';

              if (widget.isRequiredBeforeBooking) {
                _checkRequiredFields();
              }
            });
          },
          validator: (value) => value == null ? 'Please select a gender' : null,
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildRaceDropdown() {
    final key = 'race';
    final isFieldEmpty = _emptyFields.contains(key);
    final currentValue = controllers[key]?.text;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        side: isFieldEmpty
            ? BorderSide(color: Colors.red, width: 1)
            : BorderSide.none,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: DropdownButtonFormField<String>(
          value: (currentValue != null &&
                  currentValue.isNotEmpty &&
                  ['Malay', 'Chinese', 'Indian'].contains(currentValue))
              ? currentValue
              : null,
          decoration: InputDecoration(
            labelText: 'Race *',
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: isFieldEmpty ? Colors.red : Colors.blueAccent,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          items: ['Malay', 'Chinese', 'Indian'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              controllers[key]?.text = newValue ?? '';

              if (widget.isRequiredBeforeBooking) {
                _checkRequiredFields();
              }
            });
          },
          validator: (value) => value == null ? 'Please select a race' : null,
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildCountryDropdown() {
    final key = 'country';
    final isFieldEmpty = _emptyFields.contains(key);
    final currentValue = controllers[key]?.text;

    // List of countries (you can expand this)
    final countries = ['Malaysia', 'Singapore', 'Indonesia', 'Thailand'];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        side: isFieldEmpty
            ? BorderSide(color: Colors.red, width: 1)
            : BorderSide.none,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: DropdownButtonFormField<String>(
          value: (currentValue != null &&
                  currentValue.isNotEmpty &&
                  countries.contains(currentValue))
              ? currentValue
              : 'Malaysia', // Default to Malaysia
          decoration: InputDecoration(
            labelText: 'Country/Region',
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: isFieldEmpty ? Colors.red : Colors.blueAccent,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          items: countries.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              controllers[key]?.text = newValue ?? 'Malaysia';

              // If country changes, reset province
              if (newValue != currentValue) {
                controllers['province']?.text = '';
              }

              if (widget.isRequiredBeforeBooking) {
                _checkRequiredFields();
              }
            });
          },
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildProvinceDropdown() {
    final key = 'province';
    final isFieldEmpty = _emptyFields.contains(key);
    final currentValue = controllers[key]?.text;
    final country = controllers['country']?.text ?? 'Malaysia';

    // Malaysia states
    final malaysiaStates = [
      'Johor',
      'Kedah',
      'Kelantan',
      'Melaka',
      'Negeri Sembilan',
      'Pahang',
      'Perak',
      'Perlis',
      'Pulau Pinang',
      'Sabah',
      'Sarawak',
      'Selangor',
      'Terengganu',
      'Kuala Lumpur',
      'Labuan',
      'Putrajaya'
    ];

    // You can add more countries and their states/provinces as needed
    final List<String> provinces = country == 'Malaysia' ? malaysiaStates : [];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        side: isFieldEmpty
            ? BorderSide(color: Colors.red, width: 1)
            : BorderSide.none,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: country == 'Malaysia'
            ? DropdownButtonFormField<String>(
                value: (currentValue != null &&
                        currentValue.isNotEmpty &&
                        provinces.contains(currentValue))
                    ? currentValue
                    : null,
                decoration: InputDecoration(
                  labelText: 'Province',
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isFieldEmpty ? Colors.red : Colors.blueAccent,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: provinces.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    controllers[key]?.text = newValue ?? '';

                    if (widget.isRequiredBeforeBooking) {
                      _checkRequiredFields();
                    }
                  });
                },
                isExpanded: true,
              )
            : TextField(
                controller: controllers[key],
                decoration: InputDecoration(
                  labelText: 'Province/State',
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isFieldEmpty ? Colors.red : Colors.blueAccent,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) {
                  if (widget.isRequiredBeforeBooking) {
                    _checkRequiredFields();
                  }
                },
              ),
      ),
    );
  }
}
