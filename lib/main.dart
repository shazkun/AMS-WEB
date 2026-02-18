import 'package:attsys/providers/auth_provider.dart';
import 'package:attsys/screens/admin.dart';
import 'package:attsys/screens/login.dart';
import 'package:attsys/screens/student.dart';
import 'package:attsys/screens/teacher/teacher.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(create: (_) => AuthProvider(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            switch (auth.role) {
              case 'admin':
                return const AdminDashboard();
              case 'teacher':
                return const TeacherDashboard();
              case 'student':
                return const StudentDashboard();
              default:
                return const LoginScreen();
            }
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
