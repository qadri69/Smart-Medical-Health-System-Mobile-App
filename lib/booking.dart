import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'profile.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isBookingButtonEnabled = false;
  bool _isProfileComplete = false;
  bool _isCheckingProfile = true;
  String? _selectedTimeSlot;

  // New variables for doctor selection
  String? _selectedDoctorId;
  String? _selectedDoctorName;
  List<Map<String, dynamic>> _doctors = [];
  bool _loadingDoctors = true;

  // Define our theme colors
  final Color primaryColor = const Color(0xFF0277BD);
  final Color accentColor = const Color(0xFF26A69A);
  final Color backgroundColor = const Color(0xFFF5F7FA);

  // Available time slots
  final List<String> _morningSlots = ['09:00 AM', '10:00 AM', '11:00 AM'];
  final List<String> _afternoonSlots = [
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM'
  ];
  final List<String> _eveningSlots = ['05:00 PM', '06:00 PM', '07:00 PM'];

  final AuthService _authService = AuthService();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _checkProfileCompletion();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    setState(() {
      _loadingDoctors = true;
    });

    try {
      // Changed 'doctors' to 'doctor' to match your database structure
      final DatabaseReference doctorsRef = _database.ref('doctor');
      print('Fetching doctors from database path: doctor');
      final DatabaseEvent event = await doctorsRef.once();

      final List<Map<String, dynamic>> doctorsList = [];

      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> doctors =
            event.snapshot.value as Map<dynamic, dynamic>;

        doctors.forEach((key, value) {
          if (value is Map) {
            doctorsList.add({
              'id': key,
              'fname': value['fname'] ?? 'Unknown',
            });
          }
        });
      }

      setState(() {
        _doctors = doctorsList;
        _loadingDoctors = false;
      });
      print('Loaded ${doctorsList.length} doctors');
    } catch (e) {
      print('Error fetching doctors: $e');
      setState(() {
        _loadingDoctors = false;
      });
    }
  }

  Future<void> _checkProfileCompletion() async {
    if (_auth.currentUser == null) {
      setState(() {
        _isCheckingProfile = false;
      });
      return;
    }

    try {
      final uid = _auth.currentUser!.uid;
      final DatabaseReference ref = _database.ref('users/$uid');
      final DatabaseEvent event = await ref.once();

      if (event.snapshot.exists && event.snapshot.value is Map) {
        Map<dynamic, dynamic> userData =
            event.snapshot.value as Map<dynamic, dynamic>;

        // List of fields required for booking
        final requiredFields = [
          'name',
          'phone',
          'address',
          'gender',
          'dateOfBirth',
          'nationality',
          'age',
          'race'
        ];

        bool isComplete = true;
        for (String field in requiredFields) {
          if (!userData.containsKey(field) ||
              userData[field] == null ||
              userData[field].toString().trim().isEmpty) {
            isComplete = false;
            break;
          }
        }

        setState(() {
          _isProfileComplete = isComplete;
          _isCheckingProfile = false;
        });
      } else {
        setState(() {
          _isProfileComplete = false;
          _isCheckingProfile = false;
        });
      }
    } catch (e) {
      print('Error checking profile: $e');
      setState(() {
        _isProfileComplete = false;
        _isCheckingProfile = false;
      });
    }
  }

  void _onProfileCompleted() {
    setState(() {
      _isProfileComplete = true;
    });
  }

  // Function to check if a time slot is in the past
  bool _isTimeSlotInPast(String timeSlot) {
    // Only check if selected day is today
    if (_selectedDay == null || !isSameDay(_selectedDay!, DateTime.now())) {
      return false;
    }

    // Parse the time slot
    final DateFormat format = DateFormat("h:mm a");
    final DateTime timeSlotDateTime = format.parse(timeSlot);

    // Create a DateTime with today's date and the time slot time
    final DateTime now = DateTime.now();
    final DateTime timeSlotToday = DateTime(
      now.year,
      now.month,
      now.day,
      timeSlotDateTime.hour,
      timeSlotDateTime.minute,
    );

    // Check if the time slot is in the past
    return timeSlotToday.isBefore(now);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingProfile) {
      return Center(
        child: CircularProgressIndicator(
          color: primaryColor,
        ),
      );
    }

    if (!_isProfileComplete) {
      return ProfilePage(
        isRequiredBeforeBooking: true,
        onProfileCompleted: _onProfileCompleted,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundColor,
            const Color(0xFFE4F1F9),
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.event_available,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Schedule Appointment',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Information card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: accentColor,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Make sure make a booking 24 hour before appointment to give time for hospital to accept the request.',
                        style: TextStyle(
                          color: const Color.fromARGB(255, 255, 0, 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Calendar section
              Text(
                'Select Date',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: TableCalendar(
                  firstDay: DateTime.now(),
                  lastDay: DateTime.now().add(const Duration(days: 90)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                      _isBookingButtonEnabled = true;
                      _selectedTimeSlot = null; // Reset time selection
                    });
                  },
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: accentColor.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    weekendTextStyle: TextStyle(color: Colors.red[300]),
                    outsideDaysVisible: false,
                  ),
                ),
              ),

              // Doctor selection section
              if (_selectedDay != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Select Doctor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: _loadingDoctors
                      ? const Center(child: CircularProgressIndicator())
                      : _doctors.isEmpty
                          ? Center(
                              child: Text(
                                'No doctors available',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : Column(
                              children: [
                                const Text(
                                    'Choose a doctor for your appointment:'),
                                const SizedBox(height: 16),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 1.2,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: _doctors.length,
                                  itemBuilder: (context, index) {
                                    final doctor = _doctors[index];
                                    final bool isSelected =
                                        _selectedDoctorId == doctor['id'];

                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedDoctorId = doctor['id'];
                                          _selectedDoctorName = doctor['fname'];
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? primaryColor.withOpacity(0.1)
                                              : Colors.grey[50],
                                          border: Border.all(
                                            color: isSelected
                                                ? primaryColor
                                                : Colors.grey[300]!,
                                            width: 2,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Using a simple icon instead of profile image
                                            Icon(
                                              Icons.person_rounded,
                                              size: 48,
                                              color: isSelected
                                                  ? primaryColor
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              doctor['fname'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isSelected
                                                    ? primaryColor
                                                    : Colors.black87,
                                              ),
                                            ),
                                            if (isSelected)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    top: 8),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: primaryColor,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  'Selected',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                ),
              ],

              // Time slot section (existing code)
              if (_selectedDay != null && _selectedDoctorId != null) ...[
                Text(
                  'Select Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selected date display
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy')
                                  .format(_selectedDay!),
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Morning slots
                      Text(
                        'Morning',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _morningSlots.map((time) {
                          final bool isSelected = _selectedTimeSlot == time;
                          final bool isPast = _isTimeSlotInPast(time);

                          return ChoiceChip(
                            label: Text(time),
                            selected: isSelected,
                            selectedColor: primaryColor,
                            backgroundColor:
                                isPast ? Colors.grey[300] : Colors.grey[100],
                            labelStyle: TextStyle(
                              color: isPast
                                  ? Colors.grey[500]
                                  : (isSelected
                                      ? Colors.white
                                      : Colors.black87),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: isPast
                                ? null
                                : (selected) {
                                    setState(() {
                                      _selectedTimeSlot =
                                          selected ? time : null;
                                    });
                                  },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Afternoon slots
                      Text(
                        'Afternoon',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _afternoonSlots.map((time) {
                          final bool isSelected = _selectedTimeSlot == time;
                          final bool isPast = _isTimeSlotInPast(time);

                          return ChoiceChip(
                            label: Text(time),
                            selected: isSelected,
                            selectedColor: primaryColor,
                            backgroundColor:
                                isPast ? Colors.grey[300] : Colors.grey[100],
                            labelStyle: TextStyle(
                              color: isPast
                                  ? Colors.grey[500]
                                  : (isSelected
                                      ? Colors.white
                                      : Colors.black87),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: isPast
                                ? null
                                : (selected) {
                                    setState(() {
                                      _selectedTimeSlot =
                                          selected ? time : null;
                                    });
                                  },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Evening slots
                      Text(
                        'Evening',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _eveningSlots.map((time) {
                          final bool isSelected = _selectedTimeSlot == time;
                          final bool isPast = _isTimeSlotInPast(time);

                          return ChoiceChip(
                            label: Text(time),
                            selected: isSelected,
                            selectedColor: primaryColor,
                            backgroundColor:
                                isPast ? Colors.grey[300] : Colors.grey[100],
                            labelStyle: TextStyle(
                              color: isPast
                                  ? Colors.grey[500]
                                  : (isSelected
                                      ? Colors.white
                                      : Colors.black87),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: isPast
                                ? null
                                : (selected) {
                                    setState(() {
                                      _selectedTimeSlot =
                                          selected ? time : null;
                                    });
                                  },
                          );
                        }).toList(),
                      ),

                      // Add this right after the morning/afternoon/evening time slot sections

                      if (isSameDay(_selectedDay!, DateTime.now())) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Gray time slots have already passed and cannot be selected',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Booking button
              if (_selectedDay != null && _selectedTimeSlot != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appointment Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 18,
                            color: accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Date: ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!)}',
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color: accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Time: $_selectedTimeSlot',
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.pending_actions,
                            size: 18,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Status: Pending approval',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              // Check if the user is authenticated
                              final String? userId = _auth.currentUser?.uid;

                              if (userId == null) {
                                throw Exception(
                                    'User is not authenticated. Please log in.');
                              }

                              // Check if doctor is selected
                              if (_selectedDoctorId == null) {
                                throw Exception(
                                    'Please select a doctor for your appointment.');
                              }

                              // Convert the selected time slot from string to TimeOfDay
                              final DateFormat format = DateFormat("h:mm a");
                              final DateTime dateTime =
                                  format.parse(_selectedTimeSlot!);
                              final String formattedTime =
                                  DateFormat('HH:mm').format(dateTime);

                              // Prepare date for the booking
                              final String formattedDate =
                                  DateFormat('yyyy-MM-dd')
                                      .format(_selectedDay!);

                              // Call the AuthService to add the appointment with pending status
                              await _authService.addAppointment(
                                date: formattedDate,
                                time: formattedTime,
                                doctorId: _selectedDoctorId,
                                doctorName: _selectedDoctorName,
                                status: 'pending', // Add status parameter
                              );

                              // Show success message with a nicer designed SnackBar
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Appointment request submitted with Dr. $_selectedDoctorName for $formattedDate at $_selectedTimeSlot. Status: Pending approval.',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors
                                      .orange, // Use orange for pending status
                                  duration: const Duration(seconds: 4),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );

                              // Reset selections after successful booking
                              setState(() {
                                _selectedDay = null;
                                _selectedDoctorId = null;
                                _selectedDoctorName = null;
                                _selectedTimeSlot = null;
                                _isBookingButtonEnabled = false;
                              });
                            } catch (e) {
                              // Show error message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                            'Failed to book appointment: ${e.toString()}'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 4),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: accentColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'CONFIRM APPOINTMENT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Link to edit profile
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfilePage(
                          isRequiredBeforeBooking: false,
                        ),
                      ),
                    ).then((_) => _checkProfileCompletion());
                  },
                  icon: Icon(
                    Icons.person,
                    color: primaryColor,
                    size: 18,
                  ),
                  label: Text(
                    'View or Edit My Medical Profile',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
