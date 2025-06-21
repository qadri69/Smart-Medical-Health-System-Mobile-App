import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'booking.dart';
import 'login.dart';
import 'profile.dart';
import 'scan.dart';
import 'chat.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  final String username;

  const HomePage({Key? key, required this.username}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _currentIndex = 0;

  // Hospital theme colors
  final Color primaryColor = const Color(0xFF0277BD); // Medical blue
  final Color accentColor = const Color(0xFF26A69A); // Medical teal
  final Color backgroundColor = const Color(0xFFF8F9FA); // Light background
  final Color cardColor = Colors.white;

  // Function to get the title dynamically
  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Patient Dashboard';
      case 1:
        return 'Schedule Appointment';
      case 2:
        return 'Medical Scan';
      case 3:
        return 'Consult';
      case 4:
        return 'Medical Profile';
      default:
        return 'HealthCare Portal';
    }
  }

  // Method to get status background color
  Color _getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'declined':
        return Colors.red[100]!;
      case 'rescheduled':
        return Colors.orange[100]!;
      default:
        return accentColor.withOpacity(0.2);
    }
  }

  // Method to get status text color
  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'declined':
        return Colors.red[800]!;
      case 'rescheduled':
        return Colors.orange[800]!;
      default:
        return accentColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading:
            false, // Add this line to remove the back arrow
        backgroundColor: primaryColor,
        title: Text(
          _getTitle(),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        elevation: 2,
        actions: [
          IconButton(
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _currentIndex == 0
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with greeting and medical icon
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 24,
                              child: Icon(
                                Icons.local_hospital,
                                color: Color(0xFF0277BD),
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome,',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                Text(
                                  widget.username,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.access_time,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                "Next Check-up",
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Upcoming Appointments Section with icon
                        Row(
                          children: [
                            Icon(Icons.event_available, color: accentColor),
                            const SizedBox(width: 6),
                            const Text(
                              'Upcoming Appointments',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: accentColor, width: 3),
                            ),
                          ),
                          padding: const EdgeInsets.only(left: 10),
                          child: FutureBuilder<List<dynamic>>(
                            future: _authService.getUpcomingAppointments(),
                            builder: (context, snapshot) {
                              // Basic error handling with debug prints
                              print(
                                  'Appointment Data Status: ${snapshot.connectionState}');
                              if (snapshot.hasError) {
                                print('Error: ${snapshot.error}');
                              }

                              // Loading state
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              // Error state
                              if (snapshot.hasError) {
                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                      'Could not load appointments: ${snapshot.error}'),
                                );
                              }

                              // Empty state
                              final data = snapshot.data;
                              if (data == null || data.isEmpty) {
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.info_outline,
                                          color: Colors.grey),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                            'No upcoming appointments scheduled.'),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // Data available state
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: data.length,
                                itemBuilder: (context, index) {
                                  try {
                                    final appointment = data[index];

                                    // Handle potential format issues
                                    DateTime date;
                                    try {
                                      date =
                                          DateTime.parse(appointment['date']);
                                    } catch (e) {
                                      date = DateTime.now();
                                      print('Date parse error: $e');
                                    }

                                    final time =
                                        appointment['time'] ?? 'Unknown time';
                                    final bool isToday = DateTime.now().day ==
                                            date.day &&
                                        DateTime.now().month == date.month &&
                                        DateTime.now().year == date.year;

                                    return Card(
                                      elevation: 2,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: primaryColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Icon(
                                                      Icons.calendar_month,
                                                      color: primaryColor),
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      DateFormat('EEE, MMM d')
                                                          .format(date),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(time),
                                                  ],
                                                ),
                                                const Spacer(),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        _getStatusBackgroundColor(
                                                            appointment[
                                                                    'status'] ??
                                                                'Scheduled'),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    appointment['status'] ??
                                                        'Scheduled',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: _getStatusTextColor(
                                                          appointment[
                                                                  'status'] ??
                                                              'Scheduled'),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                TextButton.icon(
                                                  icon: Icon(Icons.edit,
                                                      size: 18,
                                                      color: accentColor),
                                                  label: Text('Edit',
                                                      style: TextStyle(
                                                          color: accentColor)),
                                                  onPressed: () =>
                                                      _editAppointment(
                                                          appointment),
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12),
                                                  ),
                                                ),
                                                TextButton.icon(
                                                  icon: const Icon(
                                                      Icons.cancel_outlined,
                                                      size: 18,
                                                      color: Colors.redAccent),
                                                  label: const Text('Cancel',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .redAccent)),
                                                  onPressed: () =>
                                                      _showCancelConfirmation(
                                                          appointment),
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    print(
                                        'Error rendering appointment $index: $e');
                                    return const SizedBox.shrink();
                                  }
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Previous Appointments Section with updated styling
                        Row(
                          children: [
                            Icon(Icons.history, color: accentColor),
                            const SizedBox(width: 6),
                            const Text(
                              'Medical History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: accentColor, width: 3),
                            ),
                          ),
                          padding: const EdgeInsets.only(left: 10),
                          child: FutureBuilder<List<dynamic>>(
                            future: _authService.getPreviousAppointments(),
                            builder: (context, snapshot) {
                              // Loading state
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              // Error state
                              if (snapshot.hasError) {
                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                      'Could not load medical history: ${snapshot.error}'),
                                );
                              }

                              // Empty state
                              final data = snapshot.data;
                              if (data == null || data.isEmpty) {
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.info_outline,
                                          color: Colors.grey),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                            'No previous medical appointments found.'),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // Data available state
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: data.length,
                                itemBuilder: (context, index) {
                                  try {
                                    final appointment = data[index];

                                    // Parse date
                                    DateTime date;
                                    try {
                                      date =
                                          DateTime.parse(appointment['date']);
                                    } catch (e) {
                                      date = DateTime.now();
                                      print('Date parse error: $e');
                                    }

                                    final time =
                                        appointment['time'] ?? 'Unknown time';
                                    final doctorName =
                                        appointment['doctorName'] ??
                                            'Not specified';
                                    final status =
                                        appointment['status'] ?? 'Completed';

                                    return Card(
                                      elevation: 1,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[200],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Icon(
                                                    Icons.event_available,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      DateFormat(
                                                              'EEE, MMM d, yyyy')
                                                          .format(date),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(time),
                                                  ],
                                                ),
                                                const Spacer(),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[100],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    status,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.blue[800],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            const Divider(),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.person,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Doctor: $doctorName',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[800],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                icon: Icon(Icons.visibility,
                                                    size: 18,
                                                    color: accentColor),
                                                label: Text('View Details',
                                                    style: TextStyle(
                                                        color: accentColor)),
                                                onPressed: () =>
                                                    _showAppointmentDetails(
                                                        appointment),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    print(
                                        'Error rendering past appointment $index: $e');
                                    return const SizedBox.shrink();
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : _getSelectedScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: cardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner_rounded),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services_outlined),
            label: 'Consult',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // Function to get the selected screen based on index
  Widget _getSelectedScreen() {
    switch (_currentIndex) {
      case 0:
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Home Screen Content Here'),
          ),
        );
      case 1:
        return const BookingScreen();
      case 2:
        return QRScanScreen();
      case 3:
        return const NurseListPage();
      case 4:
        return ProfilePage();
      default:
        return Center(child: Text('Home Screen'));
    }
  }

  // Method to show edit appointment dialog
  void _editAppointment(Map<String, dynamic> appointment) {
    // Create controllers with the current values
    final TextEditingController dateController = TextEditingController(
      text: appointment['date'],
    );
    final TextEditingController timeController = TextEditingController(
      text: appointment['time'],
    );

    DateTime selectedDate = DateTime.parse(appointment['date']);
    String selectedTime = appointment['time'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.calendar_today, color: primaryColor),
                  title: const Text('Date'),
                  subtitle:
                      Text(DateFormat('EEE, MMM d, yyyy').format(selectedDate)),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null && picked != selectedDate) {
                      selectedDate = picked;
                      dateController.text =
                          selectedDate.toIso8601String().split('T')[0];
                      // Force dialog to rebuild with new date
                      Navigator.of(context).pop();
                      _editAppointment({
                        ...appointment,
                        'date': dateController.text,
                        'time': timeController.text,
                      });
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.access_time, color: primaryColor),
                  title: const Text('Time'),
                  subtitle: Text(selectedTime),
                  onTap: () async {
                    // Parse the current time
                    TimeOfDay initialTime;
                    try {
                      List<String> timeParts = selectedTime.split(':');
                      if (timeParts.length >= 2) {
                        int hour = int.parse(timeParts[0]);
                        int minute = int.parse(timeParts[1].split(' ')[0]);
                        initialTime = TimeOfDay(hour: hour, minute: minute);
                      } else {
                        initialTime = TimeOfDay.now();
                      }
                    } catch (e) {
                      initialTime = TimeOfDay.now();
                    }

                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: initialTime,
                    );
                    if (picked != null) {
                      // Format time as "HH:MM" (24-hour format)
                      selectedTime =
                          '${picked.hour}:${picked.minute.toString().padLeft(2, '0')}';
                      timeController.text = selectedTime;

                      // Force dialog to rebuild with new time
                      Navigator.of(context).pop();
                      _editAppointment({
                        ...appointment,
                        'date': dateController.text,
                        'time': timeController.text,
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                // Update appointment with new values
                final updatedAppointment = {
                  ...appointment,
                  'date': selectedDate.toIso8601String().split('T')[0],
                  'time': selectedTime,
                };

                try {
                  // Update appointment in database
                  await _authService.updateAppointment(updatedAppointment);

                  // Close dialog and refresh
                  Navigator.of(context).pop();
                  setState(() {
                    // This will trigger a rebuild and fetch updated data
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Appointment updated successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update appointment: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Method to show cancel confirmation dialog
  void _showCancelConfirmation(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Appointment'),
          content: const Text(
            'Are you sure you want to cancel this appointment? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              child: const Text('No, Keep It'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Yes, Cancel It'),
              onPressed: () async {
                try {
                  // Cancel appointment in database
                  await _authService.cancelAppointment(appointment);

                  // Close dialog and refresh
                  Navigator.of(context).pop();
                  setState(() {
                    // This will trigger a rebuild and fetch updated data
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Appointment cancelled successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to cancel appointment: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Method to show appointment details
  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Parse date
        DateTime date;
        try {
          date = DateTime.parse(appointment['date']);
        } catch (e) {
          date = DateTime.now();
        }

        return AlertDialog(
          title: const Text('Appointment Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.calendar_today, color: primaryColor),
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(date)),
                ),
                ListTile(
                  leading: Icon(Icons.access_time, color: primaryColor),
                  title: const Text('Time'),
                  subtitle: Text(appointment['time'] ?? 'Not specified'),
                ),
                ListTile(
                  leading: Icon(Icons.person, color: primaryColor),
                  title: const Text('Doctor'),
                  subtitle: Text(appointment['doctorName'] ?? 'Not specified'),
                ),
                if (appointment['status'] != null)
                  ListTile(
                    leading: Icon(Icons.info_outline, color: primaryColor),
                    title: const Text('Status'),
                    subtitle: Text(appointment['status']),
                  ),
                if (appointment['diagnosis'] != null)
                  ListTile(
                    leading: Icon(Icons.description, color: primaryColor),
                    title: const Text('Diagnosis'),
                    subtitle: Text(appointment['diagnosis']),
                  ),
                if (appointment['prescription'] != null)
                  ListTile(
                    leading: Icon(Icons.medication, color: primaryColor),
                    title: const Text('Prescription'),
                    subtitle: Text(appointment['prescription']),
                  ),
                if (appointment['notes'] != null)
                  ListTile(
                    leading: Icon(Icons.notes, color: primaryColor),
                    title: const Text('Additional Notes'),
                    subtitle: Text(appointment['notes']),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
