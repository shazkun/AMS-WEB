import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../providers/auth_provider.dart';
import '../config/api_config.dart';

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
      final res = await http
          .get(
            Uri.parse(ApiConfig.adminTeachers),
            headers: ApiConfig.headers(token),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        setState(() {
          teachers = json.decode(res.body);
          loadingTeachers = false;
        });
      } else {
        Fluttertoast.showToast(
          msg: 'Failed to load teachers (${res.statusCode})',
          backgroundColor: Colors.red,
        );
        setState(() => loadingTeachers = false);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Network error: $e',
        backgroundColor: Colors.red,
      );
      setState(() => loadingTeachers = false);
    }
  }

  Future<void> _loadTeacherClasses(String teacherId) async {
    setState(() {
      loadingClasses = true;
      teacherClasses = [];
      selectedTeacherId = teacherId;

      // ✅ FIXED: Use the 'name' field from backend
      final teacher = teachers.firstWhere(
        (t) => t['id'].toString() == teacherId,
      );
      selectedTeacherName =
          teacher['name'] ?? '${teacher['firstname']} ${teacher['surname']}';
    });

    try {
      final token = await _getToken();
      final res = await http
          .get(
            Uri.parse(ApiConfig.adminTeacherClasses(teacherId)),
            headers: ApiConfig.headers(token),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        setState(() {
          teacherClasses = json.decode(res.body);
          loadingClasses = false;
        });
      } else {
        Fluttertoast.showToast(
          msg: 'Failed to load classes for this teacher',
          backgroundColor: Colors.red,
        );
        setState(() => loadingClasses = false);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e', backgroundColor: Colors.red);
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
    final gradeController = TextEditingController();
    final schoolYearController = TextEditingController(text: '2025-2026');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add New Class for $selectedTeacherName'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Class Name *',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Mathematics',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: gradeController,
                    decoration: const InputDecoration(
                      labelText: 'Grade Level *',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 10',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sectionController,
                    decoration: const InputDecoration(
                      labelText: 'Section (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., A',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: schoolYearController,
                    decoration: const InputDecoration(
                      labelText: 'School Year *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final grade = gradeController.text.trim();

                  if (name.isEmpty || grade.isEmpty) {
                    Fluttertoast.showToast(
                      msg: 'Class name and grade level required',
                      backgroundColor: Colors.red,
                    );
                    return;
                  }

                  try {
                    final token = await _getToken();
                    final res = await http
                        .post(
                          Uri.parse(
                            ApiConfig.adminTeacherClasses(selectedTeacherId!),
                          ),
                          headers: ApiConfig.headers(token),
                          body: json.encode({
                            'name': name,
                            'gradeLevel': grade,
                            'section':
                                sectionController.text.trim().isEmpty
                                    ? null
                                    : sectionController.text.trim(),
                            'schoolYear': schoolYearController.text.trim(),
                          }),
                        )
                        .timeout(ApiConfig.timeout);

                    if (res.statusCode == 201) {
                      Fluttertoast.showToast(
                        msg: 'Class created successfully',
                        backgroundColor: Colors.green,
                      );
                      Navigator.pop(context);
                      _loadTeacherClasses(selectedTeacherId!);
                    } else {
                      final msg = json.decode(res.body)['message'] ?? 'Failed';
                      Fluttertoast.showToast(
                        msg: msg,
                        backgroundColor: Colors.red,
                      );
                    }
                  } catch (e) {
                    Fluttertoast.showToast(
                      msg: 'Error: $e',
                      backgroundColor: Colors.red,
                    );
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
            content: const Text(
              'Are you sure? This will delete the class and all related attendance records. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm != true || selectedTeacherId == null) return;

    try {
      final token = await _getToken();
      final res = await http
          .delete(
            Uri.parse(ApiConfig.adminDeleteClass(classId)),
            headers: ApiConfig.headers(token),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 200 || res.statusCode == 204) {
        Fluttertoast.showToast(
          msg: 'Class deleted successfully',
          backgroundColor: Colors.green,
        );
        _loadTeacherClasses(selectedTeacherId!);
      } else {
        Fluttertoast.showToast(
          msg: 'Failed to delete class',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e', backgroundColor: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _loadAllTeachers();
              if (selectedTeacherId != null) {
                _loadTeacherClasses(selectedTeacherId!);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Left: Teachers List
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue.shade50,
                    child: Row(
                      children: [
                        const Icon(Icons.school, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Teachers',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${teachers.length}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        loadingTeachers
                            ? const Center(child: CircularProgressIndicator())
                            : teachers.isEmpty
                            ? const Center(child: Text('No teachers found'))
                            : ListView.builder(
                              itemCount: teachers.length,
                              itemBuilder: (context, index) {
                                final teacher = teachers[index];
                                final isSelected =
                                    selectedTeacherId ==
                                    teacher['id'].toString();

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  elevation: isSelected ? 4 : 1,
                                  color:
                                      isSelected ? Colors.blue.shade50 : null,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          isSelected
                                              ? Colors.blue
                                              : Colors.grey.shade300,
                                      child: Icon(
                                        Icons.person,
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : Colors.grey.shade700,
                                      ),
                                    ),
                                    title: Text(
                                      teacher['name'] ?? 'Unknown',
                                      style: TextStyle(
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('ID: ${teacher['id']}'),
                                        Text(
                                          '${teacher['classes_count'] ?? 0} classes',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    selected: isSelected,
                                    onTap:
                                        () => _loadTeacherClasses(
                                          teacher['id'].toString(),
                                        ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
          ),

          // Right: Selected Teacher's Classes
          Expanded(
            flex: 3,
            child:
                selectedTeacherId == null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_back,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Select a teacher to view their classes',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.green.shade50,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Classes',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      selectedTeacherName ?? 'Teacher',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text('New Class'),
                                onPressed: _createClassForTeacher,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child:
                              loadingClasses
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : teacherClasses.isEmpty
                                  ? const Center(
                                    child: Text('No classes assigned yet'),
                                  )
                                  : ListView.builder(
                                    padding: const EdgeInsets.all(8),
                                    itemCount: teacherClasses.length,
                                    itemBuilder: (context, index) {
                                      final cls = teacherClasses[index];
                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: ListTile(
                                          leading: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.class_,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                          title: Text(
                                            cls['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Grade ${cls['grade_level']}${cls['section'] != null ? ' - Section ${cls['section']}' : ''}',
                                              ),
                                              Text(
                                                'SY: ${cls['school_year']} • ${cls['student_count'] ?? 0} students',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit,
                                                  color: Colors.blue,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  Fluttertoast.showToast(
                                                    msg: 'Edit coming soon',
                                                  );
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                onPressed:
                                                    () => _deleteClass(
                                                      cls['id'].toString(),
                                                    ),
                                              ),
                                            ],
                                          ),
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
