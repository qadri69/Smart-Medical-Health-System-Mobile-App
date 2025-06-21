import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // Import the Realtime Database package
//import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database =
      FirebaseDatabase.instance; // Instance of Firebase Realtime Database

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // Register with email and password and save user info to Realtime Database
  Future<User?> registerWithEmailAndPassword({
    required String name,
    required String id_no,
    required String phone,
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      // Create user with email and password
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;

      if (user != null) {
        // Changed from 'users' to 'register_patient'
        DatabaseReference patientRef =
            _database.ref('register_patient/${user.uid}');
        await patientRef.set({
          'name': name,
          'id_no': id_no,
          'phone': phone,
          'email': email,
          'username': username,
          'created_at': ServerValue.timestamp,
        });

        return user;
      } else {
        throw Exception('User registration failed');
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // Sign out the current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print("User successfully signed out.");
    } catch (e) {
      throw Exception("Error during sign-out: $e");
    }
  }

  // Add a new appointment with date and time
  Future<void> addAppointment({
    required String date,
    required String time,
    String? doctorId,
    String? doctorName,
    String status = 'pending', // New parameter with default value
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated');
    }

    final DatabaseReference appointmentsRef =
        _database.ref('appointments').push();

    await appointmentsRef.set({
      'userId': user.uid,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'date': date,
      'time': time,
      'status': status, // Store the status in the database
      'createdAt': ServerValue.timestamp,
    });
  }

  // Fetch upcoming appointments for the current user from Realtime Database
  Future<List<dynamic>> getUpcomingAppointments() async {
    try {
      final user = _auth.currentUser;
      print('Current user: ${user?.uid}');

      if (user != null) {
        final String userId = user.uid;
        // Get today's date in YYYY-MM-DD format for comparison
        final String today = DateTime.now().toString().substring(0, 10);
        print('Filtering for dates >= $today');

        // Query the appointments from Realtime Database
        DatabaseReference appointmentsRef = _database.ref('appointments');
        DatabaseEvent event =
            await appointmentsRef.orderByChild('userId').equalTo(userId).once();

        final List<Map<String, dynamic>> appointments = [];

        if (event.snapshot.exists) {
          Map<dynamic, dynamic> data =
              event.snapshot.value as Map<dynamic, dynamic>;
          print('Found ${data.length} total appointments for user');

          // Filter for upcoming appointments (date >= today)
          data.forEach((key, value) {
            if (value is Map &&
                value['date'] != null &&
                value['date'].compareTo(today) >= 0) {
              appointments
                  .add({'id': key, ...Map<String, dynamic>.from(value)});
            }
          });

          print('Filtered to ${appointments.length} upcoming appointments');
          if (appointments.isNotEmpty) {
            print('Sample appointment data: ${appointments.first}');
          }
        } else {
          print('No appointments found in database');
        }

        // Sort by date and time
        appointments.sort((a, b) {
          int dateComp = a['date'].compareTo(b['date']);
          if (dateComp != 0) return dateComp;
          return a['time'].compareTo(b['time']);
        });

        return appointments;
      }
      return [];
    } catch (e) {
      print('Error fetching appointments: $e');
      throw e;
    }
  }

  // Fetch previous appointments for the current user
  Future<List<Map<String, dynamic>>> getPreviousAppointments() async {
    try {
      final user = _auth.currentUser;
      print('Current user for previous appointments: ${user?.uid}');

      if (user != null) {
        final String userId = user.uid;
        // Get today's date in YYYY-MM-DD format for comparison
        final String today = DateTime.now().toString().substring(0, 10);
        print('Filtering for dates < $today');

        // Query the appointments from Realtime Database
        DatabaseReference appointmentsRef = _database.ref('appointments');
        DatabaseEvent event =
            await appointmentsRef.orderByChild('userId').equalTo(userId).once();

        final List<Map<String, dynamic>> previousAppointments = [];

        if (event.snapshot.exists) {
          Map<dynamic, dynamic> data =
              event.snapshot.value as Map<dynamic, dynamic>;
          print('Found ${data.length} total appointments for user');

          // Filter for previous appointments (date < today)
          data.forEach((key, value) {
            if (value is Map &&
                value['date'] != null &&
                value['date'].compareTo(today) < 0) {
              previousAppointments
                  .add({'id': key, ...Map<String, dynamic>.from(value)});
            }
          });

          print(
              'Filtered to ${previousAppointments.length} previous appointments');
          if (previousAppointments.isNotEmpty) {
            print(
                'Sample previous appointment data: ${previousAppointments.first}');
          }
        } else {
          print('No appointments found in database');
        }

        // Sort by date and time (recent first)
        previousAppointments.sort((a, b) {
          int dateComp = b['date'].compareTo(a['date']); // Reverse order
          if (dateComp != 0) return dateComp;
          return b['time'].compareTo(a['time']); // Reverse order
        });

        return previousAppointments;
      }
      return [];
    } catch (e) {
      print('Error fetching previous appointments: $e');
      throw Exception('Error fetching previous appointments: $e');
    }
  }

  // Helper method to handle authentication errors
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This user has been disabled.';
      case 'user-not-found':
        return 'User not found.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'Email is already in use.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return 'An unknown error occurred.';
    }
  }

  // Add this method to your existing AuthService class
  Future<void> migrateIcNumberToIdNo() async {
    try {
      // Get a reference to all users
      final userSnapshots = await _database.ref('users').get();

      if (userSnapshots.exists) {
        final users = userSnapshots.value as Map<dynamic, dynamic>;

        // Update each user
        for (var userId in users.keys) {
          var userData = users[userId];

          if (userData is Map && userData.containsKey('icNumber')) {
            // Create reference to specific user
            final userRef = _database.ref('users/$userId');

            // Add new field with old value
            await userRef.update({'id_no': userData['icNumber']});

            // Remove old field
            await userRef.child('icNumber').remove();

            print('Updated user $userId: icNumber → id_no');
          }
        }
        print('Migration completed');
      }
    } catch (e) {
      print('Migration error: $e');
    }
  }

  // Add these methods to your AuthService class

  // Update an existing appointment
  Future<void> updateAppointment(Map<String, dynamic> appointment) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get the appointment ID
      final appointmentId = appointment['id'];
      if (appointmentId == null) throw Exception('Appointment ID not found');

      // Remove the ID from the data to be updated
      final appointmentData = Map<String, dynamic>.from(appointment);
      appointmentData.remove('id');

      // Update the appointment in Realtime Database
      await _database
          .ref('appointments/$appointmentId')
          .update(appointmentData);
    } catch (e) {
      print('Error updating appointment: $e');
      throw Exception('Failed to update appointment: $e');
    }
  }

  // Cancel an appointment
  Future<void> cancelAppointment(Map<String, dynamic> appointment) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get the appointment ID
      final appointmentId = appointment['id'];
      if (appointmentId == null) throw Exception('Appointment ID not found');

      // Option 1: Delete the appointment completely
      await _database.ref('appointments/$appointmentId').remove();

      // Option 2: Mark the appointment as cancelled
      // await _database.ref('appointments/$appointmentId').update({
      //   'status': 'cancelled',
      //   'cancelledAt': ServerValue.timestamp,
      // });
    } catch (e) {
      print('Error cancelling appointment: $e');
      throw Exception('Failed to cancel appointment: $e');
    }
  }
}
