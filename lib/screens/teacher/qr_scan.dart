import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QRScanScreen extends StatefulWidget {
  final String classId;
  const QRScanScreen({super.key, required this.classId});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final MobileScannerController controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final Map<String, DateTime> _lastScannedLRN = {};
  static const int cooldownSeconds = 8;
  bool isProcessing = false;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _recordAttendance(String lrn) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);

    try {
      final token = await _getToken();
      if (token == null) {
        _showMessage('Authentication token missing', isError: true);
        return;
      }

      final response = await http.post(
        Uri.parse('http://localhost:3000/api/teacher/record-scan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'payload': 'lrn:$lrn|class:${widget.classId}'}),
      );

      if (response.statusCode == 200) {
        _showMessage('Attendance recorded!', isError: false);
      } else {
        final err = json.decode(response.body)['message'] ?? 'Unknown error';
        _showMessage('Failed: $err', isError: true);
      }
    } catch (e) {
      _showMessage('Network error: $e', isError: true);
    } finally {
      setState(() => isProcessing = false);
    }
  }

  void _showMessage(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _processBarcode(String rawValue) {
    // Expected format: name|lrn|classid
    final parts = rawValue.split('|');
    if (parts.length != 2) return;

    final lrnPart = parts[0];
    final classPart = parts[1];

    if (!lrnPart.startsWith('lrn:') || !classPart.startsWith('class:')) return;

    final lrn = lrnPart.substring(4);
    final scannedClassId = classPart.substring(6);

    if (scannedClassId != widget.classId) {
      _showMessage('QR code is for a different class', isError: true);
      return;
    }

    final now = DateTime.now();
    if (_lastScannedLRN.containsKey(lrn)) {
      final diff = now.difference(_lastScannedLRN[lrn]!).inSeconds;
      if (diff < cooldownSeconds) return;
    }
    _lastScannedLRN[lrn] = now;

    _recordAttendance(lrn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Student QR'),
        actions: [
          IconButton(
            icon: Icon(
              controller.torchEnabled ? Icons.flash_on : Icons.flash_off,
            ),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: Icon(
              controller.useNewCameraSelector == CameraFacing.front
                  ? Icons.camera_front
                  : Icons.camera_rear,
            ),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue != null) {
                  _processBarcode(rawValue);
                  break; // handle one QR at a time
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.redAccent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Text(
                isProcessing
                    ? 'Processing...'
                    : 'Align student QR code inside the red square',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
