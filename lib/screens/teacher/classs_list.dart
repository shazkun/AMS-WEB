import 'dart:convert';
import 'package:attsys/screens/teacher/student_profile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ClassStudentsScreen extends StatefulWidget {
  final String classId;
  final String className;

  const ClassStudentsScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State<ClassStudentsScreen> {
  List<dynamic> students = [];
  bool isLoading = true;
  String? errorMessage;

  final TextEditingController _lrnController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadStudents() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse(
          'http://localhost:3000/api/teacher/classes/${widget.classId}/students',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        setState(() {
          students = json.decode(res.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load students (${res.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _addStudent() async {
    final lrn = _lrnController.text.trim();
    if (lrn.isEmpty || lrn.length != 12 || !RegExp(r'^\d{12}$').hasMatch(lrn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid 12-digit LRN'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse(
          'http://localhost:3000/api/teacher/classes/${widget.classId}/students',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'lrn': lrn}),
      );

      if (res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student added'),
            backgroundColor: Colors.green,
          ),
        );
        _lrnController.clear();
        _loadStudents();
      } else {
        final err = json.decode(res.body)['message'] ?? 'Failed to add';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.className} - Students')),
      body: Column(
        children: [
          // Add student row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lrnController,
                    decoration: const InputDecoration(
                      labelText: '12-digit LRN',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _addStudent,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null
                    ? Center(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                    : students.isEmpty
                    ? const Center(child: Text('No students enrolled yet'))
                    : ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final s = students[index];
                        final name =
                            '${s['firstname']} ${s['suffix'] ?? ''} ${s['surname']}'
                                .trim();
                        return ListTile(
                          leading: CircleAvatar(child: Text(s['firstname'][0])),
                          title: Text(name),
                          subtitle: Text('LRN: ${s['lrn']}'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => StudentProfileScreen(
                                      lrn:
                                          s['lrn'], // ← pass the selected student's LRN
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
