import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../providers/auth_provider.dart';

class CreateSectionScreen extends StatefulWidget {
  const CreateSectionScreen({super.key});

  @override
  State<CreateSectionScreen> createState() => _CreateSectionScreenState();
}

class _CreateSectionScreenState extends State<CreateSectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sectionController = TextEditingController();
  final _subjectController = TextEditingController();
  final _schoolYearController = TextEditingController(text: '2025-2026');

  String? _selectedGrade;
  final List<String> _gradeLevels = List.generate(
    13,
    (i) => (i + 1).toString(),
  ); // 1–13

  final List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  List<String> _selectedDays = [];

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isLoading = false;

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 7, minute: 30),
    );
    if (picked != null && mounted) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 8, minute: 30),
    );
    if (picked != null && mounted) setState(() => _endTime = picked);
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select grade level')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = await auth.getToken();

      final body = {
        'name': _nameController.text.trim(),
        'gradeLevel': _selectedGrade,
        'section':
            _sectionController.text.trim().isEmpty
                ? null
                : _sectionController.text.trim(),
        'subject':
            _subjectController.text.trim().isEmpty
                ? null
                : _subjectController.text.trim(),
        'schoolYear': _schoolYearController.text.trim(),
        'days': _selectedDays,
        'startTime': _startTime != null ? _formatTimeOfDay(_startTime!) : null,
        'endTime': _endTime != null ? _formatTimeOfDay(_endTime!) : null,
      };

      final res = await http.post(
        Uri.parse('http://localhost:3000/api/teacher/classes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Class created successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        final err = json.decode(res.body)['message'] ?? 'Unknown error';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: $err'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Class')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Class Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedGrade,
                decoration: const InputDecoration(
                  labelText: 'Grade Level *',
                  border: OutlineInputBorder(),
                ),
                items:
                    _gradeLevels
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text('Grade $g'),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _selectedGrade = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _sectionController,
                decoration: const InputDecoration(
                  labelText: 'Section (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _schoolYearController,
                decoration: const InputDecoration(
                  labelText: 'School Year * (e.g. 2025-2026)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              const Text(
                'Class Days',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _weekDays.map((day) {
                      final selected = _selectedDays.contains(day);
                      return FilterChip(
                        label: Text(day),
                        selected: selected,
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedDays.add(day);
                            } else {
                              _selectedDays.remove(day);
                            }
                          });
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),

              const Text(
                'Class Time',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              ListTile(
                title: Text(
                  _startTime == null
                      ? 'Start Time'
                      : 'Start: ${_formatTimeOfDay(_startTime!)}',
                ),
                trailing: const Icon(Icons.access_time),
                onTap: _pickStartTime,
              ),
              ListTile(
                title: Text(
                  _endTime == null
                      ? 'End Time'
                      : 'End: ${_formatTimeOfDay(_endTime!)}',
                ),
                trailing: const Icon(Icons.access_time),
                onTap: _pickEndTime,
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                          : const Text(
                            'Create Class',
                            style: TextStyle(fontSize: 17),
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
