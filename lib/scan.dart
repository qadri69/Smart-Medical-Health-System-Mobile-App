import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Add date formatting
import 'package:firebase_database/firebase_database.dart'; // Import Firebase Realtime Database

class QRScanScreen extends StatefulWidget {
  final String? userId; // User ID for verification

  const QRScanScreen({
    super.key,
    this.userId, // Make it optional to support both direct pass or auth retrieval
  });

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController controller = MobileScannerController();
  String? scannedData;
  bool isScanning = true;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool? isAttendanceSuccessful; // Track verification result
  String? currentUserId; // For storing the current user ID
  bool isAttendanceMarked = false; // Track if attendance was marked
  String? attendanceMessage; // Message about attendance status

  // Define our theme colors to match the rest of the app
  final Color primaryColor = const Color(0xFF0277BD);
  final Color accentColor = const Color(0xFF26A69A);
  final Color successColor = const Color(0xFF4CAF50);
  final Color errorColor = const Color(0xFFF44336);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _animationController.repeat();

    // Get current user ID - either from passed parameter or from Firebase Auth
    getCurrentUserId();
  }

  // Get the current authenticated user
  void getCurrentUserId() async {
    // If userId is provided directly, use it
    if (widget.userId != null) {
      setState(() {
        currentUserId = widget.userId;
      });
      return;
    }

    // Otherwise get from FirebaseAuth
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          currentUserId = user.uid;
        });
      } else {
        // Handle not authenticated case
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated. Please login first.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error getting current user: $e');
    }
  }

  // Extract user ID from URL
  String? extractUserIdFromUrl(String url) {
    // Check if URL follows expected pattern
    if (url.contains('/scan/')) {
      final parts = url.split('/');
      if (parts.isNotEmpty) {
        return parts.last; // Return last segment as user ID
      }
    }
    return null;
  }

  // Mark attendance for today's appointments - optimized version
  Future<void> markAttendance() async {
    if (currentUserId == null) return;

    try {
      // Get today's date in YYYY-MM-DD format
      final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Single direct query to get appointments for today
      final appointmentsRef = FirebaseDatabase.instance.ref('appointments');
      final query = appointmentsRef.orderByChild('date').equalTo(today);
      final snapshot = await query.get();

      // No appointments found for today
      if (!snapshot.exists) {
        setState(() {
          attendanceMessage = "No appointments scheduled for today.";
          isAttendanceMarked = false;
        });
        return;
      }

      // Process appointments found
      final acceptedAppointments = <Map<String, dynamic>>[];

      // Single pass through results to find matching appointments
      snapshot.children.forEach((child) {
        final data = child.value as Map<dynamic, dynamic>;

        // Check both userId and status in one pass
        if (data['userId'] == currentUserId &&
            data['status'].toString().toLowerCase() == 'accepted') {
          final appointment = <String, dynamic>{};
          data.forEach((key, value) {
            appointment[key.toString()] = value;
          });
          appointment['id'] = child.key;
          acceptedAppointments.add(appointment);
        }
      });

      // Handle results
      if (acceptedAppointments.isEmpty) {
        setState(() {
          attendanceMessage = "No appointments scheduled for today.";
          isAttendanceMarked = false;
        });
        return;
      }

      // Update the appointments to mark attendance
      int updatedCount = 0;
      for (var appointment in acceptedAppointments) {
        await appointmentsRef.child(appointment['id']).update({
          'status': 'Attended',
          'checkedInAt': ServerValue.timestamp,
        });
        updatedCount++;
      }

      setState(() {
        attendanceMessage =
            "Attendance marked for $updatedCount appointment(s).";
        isAttendanceMarked = true;
      });
    } catch (e) {
      print('Error marking attendance: $e');
      setState(() {
        attendanceMessage = "Failed to mark attendance: $e";
        isAttendanceMarked = false;
      });
    }
  }

  // Verify if scanned QR matches user ID
  void verifyAttendance(String scannedData) async {
    final scannedUserId = extractUserIdFromUrl(scannedData);

    if (currentUserId == null) {
      setState(() {
        isAttendanceSuccessful = false;
      });
      return;
    }

    if (scannedUserId != null && scannedUserId == currentUserId) {
      setState(() {
        isAttendanceSuccessful = true;
      });

      // If QR verification is successful, mark attendance for today's appointments
      await markAttendance();
    } else {
      setState(() {
        isAttendanceSuccessful = false;
        isAttendanceMarked = false;
        attendanceMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // Change this to add bottom padding for navigation bar
        bottom:
            false, // Don't account for bottom safe area since you have a nav bar
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF5F7FA),
                Color(0xFFE4F1F9),
              ],
            ),
          ),
          // Wrap the main column in a SingleChildScrollView to handle overflow
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Top controls remain the same
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: ValueListenableBuilder(
                          valueListenable: controller.torchState,
                          builder: (context, state, child) {
                            switch (state) {
                              case TorchState.on:
                                return Icon(Icons.flash_on, color: accentColor);
                              case TorchState.off:
                                return Icon(Icons.flash_off,
                                    color: primaryColor);
                            }
                          },
                        ),
                        onPressed: () => controller.toggleTorch(),
                      ),
                      IconButton(
                        icon: ValueListenableBuilder(
                          valueListenable: controller.cameraFacingState,
                          builder: (context, state, child) {
                            switch (state) {
                              case CameraFacing.front:
                                return Icon(Icons.camera_front,
                                    color: primaryColor);
                              case CameraFacing.back:
                                return Icon(Icons.camera_rear,
                                    color: primaryColor);
                            }
                          },
                        ),
                        onPressed: () => controller.switchCamera(),
                      ),
                    ],
                  ),
                ),

                // Instructions card
                if (scannedData == null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
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
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: accentColor,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Position the QR code within the frame to verify your attendance.',
                              style: TextStyle(
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Scanner - give it a fixed height instead of Expanded
                Container(
                  height: MediaQuery.of(context).size.height *
                      0.45, // 45% of screen height
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: controller,
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty && isScanning) {
                              HapticFeedback
                                  .mediumImpact(); // Add haptic feedback
                              isScanning = false;
                              final rawValue = barcodes.first.rawValue;
                              if (rawValue != null) {
                                setState(() {
                                  scannedData = rawValue;
                                });
                                verifyAttendance(
                                    rawValue); // Verify the scanned data
                              }
                              controller.stop();
                            }
                          },
                        ),
                        // Scanner overlay
                        CustomPaint(
                          painter: ScannerOverlay(
                            borderColor: accentColor,
                            borderRadius: 20,
                            borderLength: 40,
                            borderWidth: 5,
                            cutOutSize: 270,
                            scanProgress: isScanning ? _animation.value : 0,
                          ),
                          child: Container(),
                        ),

                        // Animated scan line
                        if (isScanning && scannedData == null)
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  margin: EdgeInsets.only(
                                    top: 135 +
                                        270 * _animation.value -
                                        135 * _animation.value,
                                  ),
                                  height: 2,
                                  width: 220,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accentColor.withOpacity(0),
                                        accentColor.withOpacity(1),
                                        accentColor.withOpacity(1),
                                        accentColor.withOpacity(0),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Results area - no longer using Expanded
                Padding(
                  padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 80), // Added bottom padding for nav bar
                  child: scannedData != null
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isAttendanceSuccessful == true
                                          ? successColor.withOpacity(0.1)
                                          : isAttendanceSuccessful == false
                                              ? errorColor.withOpacity(0.1)
                                              : accentColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isAttendanceSuccessful == true
                                          ? Icons.check_circle
                                          : isAttendanceSuccessful == false
                                              ? Icons.error
                                              : Icons.qr_code_scanner,
                                      color: isAttendanceSuccessful == true
                                          ? successColor
                                          : isAttendanceSuccessful == false
                                              ? errorColor
                                              : accentColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isAttendanceSuccessful == true
                                        ? 'Verification Successful'
                                        : isAttendanceSuccessful == false
                                            ? 'Verification Failed'
                                            : 'Scan Result',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Status message
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isAttendanceSuccessful == true
                                      ? successColor.withOpacity(0.1)
                                      : isAttendanceSuccessful == false
                                          ? errorColor.withOpacity(0.1)
                                          : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isAttendanceSuccessful == true
                                        ? successColor.withOpacity(0.3)
                                        : isAttendanceSuccessful == false
                                            ? errorColor.withOpacity(0.3)
                                            : Colors.grey[300]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isAttendanceSuccessful == true
                                          ? Icons.check_circle_outline
                                          : isAttendanceSuccessful == false
                                              ? Icons.error_outline
                                              : Icons.info_outline,
                                      color: isAttendanceSuccessful == true
                                          ? successColor
                                          : isAttendanceSuccessful == false
                                              ? errorColor
                                              : Colors.grey[700],
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isAttendanceSuccessful == true
                                                ? 'Your identity has been verified!'
                                                : isAttendanceSuccessful ==
                                                        false
                                                    ? 'This QR code does not match your user ID.'
                                                    : scannedData!,
                                            style: TextStyle(
                                              color: isAttendanceSuccessful ==
                                                      true
                                                  ? successColor
                                                  : isAttendanceSuccessful ==
                                                          false
                                                      ? errorColor
                                                      : Colors.grey[800],
                                            ),
                                          ),
                                          // Show attendance status message if available
                                          if (isAttendanceSuccessful == true &&
                                              attendanceMessage != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 8.0),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isAttendanceMarked
                                                        ? Icons.event_available
                                                        : Icons.event_note,
                                                    size: 16,
                                                    color: isAttendanceMarked
                                                        ? successColor
                                                        : Colors.orange,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      attendanceMessage!,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            isAttendanceMarked
                                                                ? successColor
                                                                : Colors.orange
                                                                    .shade800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isAttendanceSuccessful == null)
                                      IconButton(
                                        icon: Icon(
                                          Icons.content_copy,
                                          color: primaryColor,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: scannedData!),
                                          ).then((_) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                    'Copied to clipboard'),
                                                backgroundColor: accentColor,
                                              ),
                                            );
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        isScanning = true;
                                        scannedData = null;
                                        isAttendanceSuccessful = null;
                                        isAttendanceMarked = false;
                                        attendanceMessage = null;
                                      });
                                      controller.start();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                    icon: const Icon(Icons.qr_code_scanner),
                                    label: const Text('Scan Again'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Ready to scan',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.north,
                                  color: primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Point camera at QR code',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
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

// Enhanced overlay painter with animated scan effect
class ScannerOverlay extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;
  final double scanProgress;

  ScannerOverlay({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutOutSize,
    this.scanProgress = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final double cutOutX = (size.width - cutOutSize) / 2;
    final double cutOutY = (size.height - cutOutSize) / 2;

    // Background with cutout
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(cutOutX, cutOutY, cutOutSize, cutOutSize),
              Radius.circular(borderRadius),
            ),
          ),
      ),
      paint,
    );

    // Draw border
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final RRect cutOutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cutOutX, cutOutY, cutOutSize, cutOutSize),
      Radius.circular(borderRadius),
    );

    // Add subtle glow effect
    canvas.drawRRect(
      cutOutRect.inflate(2),
      Paint()
        ..color = borderColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth - 1
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Top left corner
    canvas.drawLine(
      Offset(cutOutX, cutOutY + borderRadius),
      Offset(cutOutX, cutOutY + borderLength),
      borderPaint,
    );
    canvas.drawLine(
      Offset(cutOutX + borderRadius, cutOutY),
      Offset(cutOutX + borderLength, cutOutY),
      borderPaint,
    );

    // Top right corner
    canvas.drawLine(
      Offset(cutOutX + cutOutSize, cutOutY + borderRadius),
      Offset(cutOutX + cutOutSize, cutOutY + borderLength),
      borderPaint,
    );
    canvas.drawLine(
      Offset(cutOutX + cutOutSize - borderRadius, cutOutY),
      Offset(cutOutX + cutOutSize - borderLength, cutOutY),
      borderPaint,
    );

    // Bottom left corner
    canvas.drawLine(
      Offset(cutOutX, cutOutY + cutOutSize - borderRadius),
      Offset(cutOutX, cutOutY + cutOutSize - borderLength),
      borderPaint,
    );
    canvas.drawLine(
      Offset(cutOutX + borderRadius, cutOutY + cutOutSize),
      Offset(cutOutX + borderLength, cutOutY + cutOutSize),
      borderPaint,
    );

    // Bottom right corner
    canvas.drawLine(
      Offset(cutOutX + cutOutSize, cutOutY + cutOutSize - borderRadius),
      Offset(cutOutX + cutOutSize, cutOutY + cutOutSize - borderLength),
      borderPaint,
    );
    canvas.drawLine(
      Offset(cutOutX + cutOutSize - borderRadius, cutOutY + cutOutSize),
      Offset(cutOutX + cutOutSize - borderLength, cutOutY + cutOutSize),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
