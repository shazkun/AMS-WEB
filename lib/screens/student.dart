import 'dart:convert';
import 'package:attsys/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  List<dynamic> enrolledClasses = [];
  List<dynamic> attendanceRecords = [];
  String? selectedClassId;
  String? selectedClassName;

  Map<String, int> stats = {'Present': 0, 'Absent': 0, 'Late': 0, 'Excused': 0};
  int totalSessions = 0;

  bool isLoadingClasses = true;
  bool isLoadingAttendance = false;

  @override
  void initState() {
    super.initState();
    _loadEnrolledClasses();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadEnrolledClasses() async {
    setState(() => isLoadingClasses = true);

    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse('http://localhost:3000/api/student/classes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          enrolledClasses = data;
          isLoadingClasses = false;
        });

        if (data.isNotEmpty) {
          _selectClass(data[0]['id'].toString(), data[0]['name']);
        }
      } else {
        _showError('Failed to load classes');
      }
    } catch (e) {
      _showError('Network error: $e');
    }
  }

  Future<void> _selectClass(String classId, String className) async {
    setState(() {
      selectedClassId = classId;
      selectedClassName = className;
      isLoadingAttendance = true;
      attendanceRecords = [];
      stats = {'Present': 0, 'Absent': 0, 'Late': 0, 'Excused': 0};
      totalSessions = 0;
    });

    try {
      final token = await _getToken();
      final uri = Uri.parse(
        'http://localhost:3000/api/student/attendance',
      ).replace(queryParameters: {'classId': classId});

      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final records = json.decode(res.body);
        final newStats = {'Present': 0, 'Absent': 0, 'Late': 0, 'Excused': 0};

        for (var r in records) {
          final status = r['status'] as String;
          if (newStats.containsKey(status)) {
            newStats[status] = newStats[status]! + 1;
          }
        }

        setState(() {
          attendanceRecords = records;
          stats = newStats;
          totalSessions = records.length;
          isLoadingAttendance = false;
        });
      } else {
        _showError('Failed to load attendance');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  List<PieChartSectionData> _buildPieSections() {
    final colors = {
      'Present': Colors.green,
      'Absent': Colors.red,
      'Late': Colors.orange,
      'Excused': Colors.blue,
    };

    return stats.entries.where((e) => e.value > 0).map((e) {
      final percentage =
          totalSessions > 0 ? (e.value / totalSessions) * 100 : 0;
      return PieChartSectionData(
        value: e.value.toDouble(),
        title: '${e.key}\n${percentage.toStringAsFixed(0)}%',
        color: colors[e.key] ?? Colors.grey,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Class selector
          if (enrolledClasses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButton<String>(
                value: selectedClassId,
                isExpanded: true,
                hint: const Text('Select a class'),
                items:
                    enrolledClasses.map((cls) {
                      return DropdownMenuItem<String>(
                        value: cls['id'].toString(),
                        child: Text(
                          '${cls['name']} (${cls['grade_level']} ${cls['section'] ?? ''})',
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final cls = enrolledClasses.firstWhere(
                    (c) => c['id'].toString() == value,
                  );
                  _selectClass(value, cls['name']);
                },
              ),
            ),

          // Stats card
          if (selectedClassId != null)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Attendance - $selectedClassName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child:
                          totalSessions == 0
                              ? const Center(child: Text('No records yet'))
                              : PieChart(
                                PieChartData(
                                  sections: _buildPieSections(),
                                  centerSpaceRadius: 40,
                                  sectionsSpace: 2,
                                ),
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text('Total sessions: $totalSessions'),
                  ],
                ),
              ),
            ),

          // Attendance list
          Expanded(
            child:
                isLoadingAttendance
                    ? const Center(child: CircularProgressIndicator())
                    : attendanceRecords.isEmpty
                    ? const Center(
                      child: Text('No attendance records for this class yet'),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: attendanceRecords.length,
                      itemBuilder: (context, i) {
                        final r = attendanceRecords[i];
                        final date = DateTime.parse(r['session_date']);
                        final color = switch (r['status']) {
                          'Present' => Colors.green,
                          'Absent' => Colors.red,
                          'Late' => Colors.orange,
                          _ => Colors.blue,
                        };

                        return ListTile(
                          leading: Icon(Icons.circle, color: color, size: 18),
                          title: Text(DateFormat('MMM dd, yyyy').format(date)),
                          subtitle: Text(r['status']),
                          trailing: Text(
                            r['time_marked'] ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
