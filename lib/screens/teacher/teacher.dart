import 'dart:convert';
import 'package:attsys/providers/auth_provider.dart';
import 'package:attsys/screens/teacher/classs_list.dart';
import 'package:attsys/screens/teacher/create_section.dart';
import 'package:attsys/screens/teacher/qr_scan.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  List<dynamic> myClasses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyClasses();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadMyClasses() async {
    setState(() => isLoading = true);

    try {
      final token = await _getToken();
      if (token == null) throw 'Token missing';

      final res = await http.get(
        Uri.parse('http://localhost:3000/api/teacher/classes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final classes = json.decode(res.body) as List;
        setState(() {
          myClasses = classes;
          isLoading = false;
        });
      } else {
        _showError('Failed to load classes: ${res.statusCode}');
      }
    } catch (e) {
      _showError('Network error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _openQRScanner(String classId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QRScanScreen(classId: classId)),
    );
  }

  void _openCreateSection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateSectionScreen()),
    ).then((_) => _loadMyClasses());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(
                context,
                '/',
              ); // or push to LoginScreen
            },
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : myClasses.isEmpty
              ? const Center(child: Text('No classes yet. Create one!'))
              : ListView.separated(
                itemCount: myClasses.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final cls = myClasses[index];
                  final className =
                      '${cls['name']} (${cls['grade_level']} ${cls['section'] ?? ''}) • ${cls['school_year']}';

                  return ListTile(
                    leading: const Icon(Icons.class_),
                    title: Text(cls['name']),
                    subtitle: Text(
                      '${cls['grade_level']} ${cls['section'] ?? ''} • ${cls['school_year']}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.qr_code_scanner,
                            color: Colors.blue,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => QRScanScreen(
                                      classId: cls['id'].toString(),
                                    ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.people, color: Colors.green),
                          tooltip: 'View / Add Students',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ClassStudentsScreen(
                                      classId: cls['id'].toString(),
                                      className: cls['name'],
                                    ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      // Optional: you can also open students list on tap instead of only on button
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ClassStudentsScreen(
                                classId: cls['id'].toString(),
                                className: cls['name'],
                              ),
                        ),
                      );
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSection,
        child: const Icon(Icons.add),
        tooltip: 'Create New Class',
      ),
    );
  }
}
