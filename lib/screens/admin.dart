import 'package:attsys/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<dynamic> teachers = [];
  String? selectedTeacherId;
  String? selectedTeacherName;
  List<dynamic> teacherClasses = [];
  bool loadingTeachers = true;
  bool loadingClasses = false;

  @override
  void initState() {
    super.initState();
    _loadAllTeachers();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadAllTeachers() async {
    setState(() => loadingTeachers = true);

    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse('http://localhost:3000/api/admin/teachers'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        setState(() {
          teachers = json.decode(res.body);
          loadingTeachers = false;
        });
      } else {
        Fluttertoast.showToast(
          msg: 'Failed to load teachers (${res.statusCode})',
        );
        setState(() => loadingTeachers = false);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Network error: $e');
      setState(() => loadingTeachers = false);
    }
  }

  Future<void> _loadTeacherClasses(String teacherId) async {
    setState(() {
      loadingClasses = true;
      teacherClasses = [];
      selectedTeacherId = teacherId;
      selectedTeacherName =
          teachers.firstWhere((t) => t['id'].toString() == teacherId)['name'] ??
          'Unknown';
    });

    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse(
          'http://localhost:3000/api/admin/teachers/$teacherId/classes',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        setState(() {
          teacherClasses = json.decode(res.body);
          loadingClasses = false;
        });
      } else {
        Fluttertoast.showToast(msg: 'Failed to load classes for this teacher');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      setState(() => loadingClasses = false);
    }
  }

  Future<void> _createClassForTeacher() async {
    if (selectedTeacherId == null) {
      Fluttertoast.showToast(msg: 'Select a teacher first');
      return;
    }

    final nameController = TextEditingController();
    final sectionController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add New Class for $selectedTeacherName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Class Name / Section *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sectionController,
                  decoration: const InputDecoration(
                    labelText: 'Section (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    Fluttertoast.showToast(msg: 'Class name required');
                    return;
                  }

                  try {
                    final token = await _getToken();
                    final res = await http.post(
                      Uri.parse(
                        'http://localhost:3000/api/admin/teachers/$selectedTeacherId/classes',
                      ),
                      headers: {
                        'Authorization': 'Bearer $token',
                        'Content-Type': 'application/json',
                      },
                      body: json.encode({
                        'name': name,
                        'section':
                            sectionController.text.trim().isEmpty
                                ? null
                                : sectionController.text.trim(),
                      }),
                    );

                    if (res.statusCode == 201) {
                      Fluttertoast.showToast(msg: 'Class created');
                      Navigator.pop(context);
                      _loadTeacherClasses(selectedTeacherId!);
                    } else {
                      final msg = json.decode(res.body)['message'] ?? 'Failed';
                      Fluttertoast.showToast(msg: msg);
                    }
                  } catch (e) {
                    Fluttertoast.showToast(msg: 'Error: $e');
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteClass(String classId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Class'),
            content: const Text('Are you sure? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm != true || selectedTeacherId == null) return;

    try {
      final token = await _getToken();
      final res = await http.delete(
        Uri.parse('http://localhost:3000/api/admin/classes/$classId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        Fluttertoast.showToast(msg: 'Class deleted');
        _loadTeacherClasses(selectedTeacherId!);
      } else {
        Fluttertoast.showToast(msg: 'Failed to delete class');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          // ... your other admin actions
        ],
      ),
      body: Row(
        children: [
          // Left: Teachers List
          Expanded(
            flex: 2,
            child:
                loadingTeachers
                    ? const Center(child: CircularProgressIndicator())
                    : teachers.isEmpty
                    ? const Center(child: Text('No teachers found'))
                    : ListView.builder(
                      itemCount: teachers.length,
                      itemBuilder: (context, index) {
                        final teacher = teachers[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.school),
                          ),
                          title: Text(
                            teacher['name'] ?? teacher['username'] ?? 'Unknown',
                          ),
                          subtitle: Text(
                            'ID: ${teacher['id']} • ${teacher['classes_count'] ?? '?'} classes',
                          ),
                          selected:
                              selectedTeacherId == teacher['id'].toString(),
                          onTap:
                              () =>
                                  _loadTeacherClasses(teacher['id'].toString()),
                        );
                      },
                    ),
          ),

          // Right: Selected Teacher's Classes
          Expanded(
            flex: 3,
            child:
                selectedTeacherId == null
                    ? const Center(
                      child: Text(
                        'Select a teacher to view/manage their classes',
                      ),
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Classes for $selectedTeacherName',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('New Class'),
                                onPressed: _createClassForTeacher,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (loadingClasses)
                          const Center(child: CircularProgressIndicator())
                        else if (teacherClasses.isEmpty)
                          const Center(child: Text('No classes assigned yet'))
                        else
                          Expanded(
                            child: ListView.builder(
                              itemCount: teacherClasses.length,
                              itemBuilder: (context, index) {
                                final cls = teacherClasses[index];
                                return ListTile(
                                  leading: const Icon(Icons.class_),
                                  title: Text(cls['name']),
                                  subtitle: Text(
                                    cls['section'] != null
                                        ? 'Section: ${cls['section']}'
                                        : 'No section',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () {
                                          // TODO: Implement edit class dialog
                                          Fluttertoast.showToast(
                                            msg: 'Edit coming soon',
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed:
                                            () => _deleteClass(
                                              cls['id'].toString(),
                                            ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
