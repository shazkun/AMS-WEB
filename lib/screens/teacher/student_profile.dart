// screens/student_profile.dart
import 'dart:convert';
import 'package:attsys/providers/auth_provider.dart';
import 'package:attsys/widgets/logout.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// screens/student_profile_screen.dart
// (only showing the changed parts – merge with your existing file)

// screens/student_profile_screen.dart

class StudentProfileScreen extends StatefulWidget {
  final String? lrn; // null = own profile, non-null = viewing specific student

  const StudentProfileScreen({super.key, this.lrn});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  Map<String, dynamic>? profile;
  bool isLoading = true;
  String? errorMessage;
  String? qrPayload;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      String url;
      if (widget.lrn != null) {
        // Teacher viewing specific student
        url = 'http://localhost:3000/api/teacher/students/${widget.lrn}';
      } else {
        // Own profile
        url = 'http://localhost:3000/api/student/profile';
      }

      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          profile = data;
          isLoading = false;
        });
        _generateQrPayload(); // Generate QR in both cases now
      } else {
        setState(() {
          errorMessage =
              'Failed to load profile: ${res.statusCode} - ${res.body}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  void _generateQrPayload() {
    if (profile == null || profile!['lrn'] == null) {
      debugPrint("QR generation skipped: no LRN");
      return;
    }

    // Use a placeholder class ID (you can make this dynamic later)
    final classId = "1"; // ← or pass real classId from constructor if needed

    setState(() {
      qrPayload = "${profile!['surname']}|${profile!['lrn']}|$classId";
      debugPrint("QR generated: $qrPayload");
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.lrn == null;
    final title = isOwnProfile ? 'My Profile' : 'Student Profile';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [LogoutButton()], // if you have this widget
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
              : profile == null
              ? const Center(child: Text('No profile data'))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        profile!['firstname'][0] + profile!['surname'][0],
                        style: const TextStyle(
                          fontSize: 48,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${profile!['firstname']} ${profile!['suffix'] ?? ''} ${profile!['surname']}'
                          .trim(),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'LRN: ${profile!['lrn']}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Birthday: ${profile!['birthday'] ?? '—'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 40),

                    // QR Section – always show when profile is loaded
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              widget.lrn == null
                                  ? 'Your Attendance QR Code'
                                  : 'Student QR Code',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),

                            if (isLoading)
                              const SizedBox(
                                height: 260,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (errorMessage != null)
                              SizedBox(
                                height: 260,
                                child: Center(
                                  child: Text(
                                    'Cannot load profile\n$errorMessage',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                ),
                              )
                            else if (qrPayload == null)
                              SizedBox(
                                height: 260,
                                child: Center(
                                  child: Text(
                                    'QR not ready',
                                    style: TextStyle(color: Colors.orange[800]),
                                  ),
                                ),
                              )
                            else
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // QR code
                                  QrImageView(
                                    data: qrPayload!,
                                    version: QrVersions.auto,
                                    size: 240,
                                    backgroundColor: Colors.white,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Colors.black,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.circle,
                                      color: Colors.black,
                                    ),
                                  ),

                                  // Overlay: Firstname Surname + LRN
                                ],
                              ),

                            const SizedBox(height: 16),
                            Text(
                              widget.lrn == null
                                  ? 'Show this to your teacher to mark attendance'
                                  : 'Scan this to mark attendance',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

  // In build method – make the QR section show useful feedback

 