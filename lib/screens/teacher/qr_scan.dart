import 'package:attsys/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


class QRScanScreen extends StatefulWidget {
  final String classId;
  final String className;
  
  const QRScanScreen({
    super.key, 
    required this.classId,
    required this.className,
  });

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final MobileScannerController controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final Map<String, DateTime> _lastScannedLRN = {};
  static const int cooldownSeconds = 5;
  bool isProcessing = false;
  
  String? lastScannedStudent;
  int successCount = 0;

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

      // ✅ FIXED: Send correct payload format
      final payload = 'lrn:$lrn|class:${widget.classId}';

      final response = await http.post(
        Uri.parse(ApiConfig.teacherRecordScan),
        headers: ApiConfig.headers(token),
        body: json.encode({'payload': payload}),
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final studentName = data['student'] ?? 'Student';
        
        setState(() {
          lastScannedStudent = studentName;
          successCount++;
        });
        
        _showMessage('✓ $studentName marked present', isError: false);
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
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _processBarcode(String rawValue) {
    // ✅ FIXED: Parse format "lrn:123456789012|class:45"
    final parts = rawValue.split('|');
    if (parts.length != 2) {
      debugPrint('Invalid QR format: $rawValue');
      return;
    }

    final lrnPart = parts[0];
    final classPart = parts[1];

    if (!lrnPart.startsWith('lrn:') || !classPart.startsWith('class:')) {
      debugPrint('Invalid QR prefixes: $rawValue');
      return;
    }

    final lrn = lrnPart.substring(4);
    final scannedClassId = classPart.substring(6);

    // Validate LRN format
    if (lrn.length != 12 || !RegExp(r'^\d{12}$').hasMatch(lrn)) {
      _showMessage('Invalid LRN format', isError: true);
      return;
    }

    if (scannedClassId != widget.classId) {
      _showMessage('QR code is for a different class', isError: true);
      return;
    }

    // Check cooldown
    final now = DateTime.now();
    if (_lastScannedLRN.containsKey(lrn)) {
      final diff = now.difference(_lastScannedLRN[lrn]!).inSeconds;
      if (diff < cooldownSeconds) {
        debugPrint('Cooldown active for LRN: $lrn');
        return;
      }
    }
    
    _lastScannedLRN[lrn] = now;
    _recordAttendance(lrn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scan Attendance', style: TextStyle(fontSize: 18)),
            Text(
              widget.className,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(
              controller.torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (isProcessing) return;
              
              for (final barcode in capture.barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue != null) {
                  _processBarcode(rawValue);
                  break;
                }
              }
            },
          ),

          // Scanning frame overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isProcessing ? Colors.orange : Colors.greenAccent,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: isProcessing
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.orange,
                        strokeWidth: 3,
                      ),
                    )
                  : null,
            ),
          ),

          // Corner decorations
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                children: [
                  _buildCorner(top: 0, left: 0),
                  _buildCorner(top: 0, right: 0),
                  _buildCorner(bottom: 0, left: 0),
                  _buildCorner(bottom: 0, right: 0),
                ],
              ),
            ),
          ),

          // Stats card at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Scanned Today:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$successCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (lastScannedStudent != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Last: $lastScannedStudent',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Instructions at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                    Colors.black,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isProcessing ? Icons.hourglass_empty : Icons.qr_code_scanner,
                    color: Colors.white70,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isProcessing
                        ? 'Processing...'
                        : 'Align student QR code in the frame',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'QR codes are scanned automatically',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner({double? top, double? bottom, double? left, double? right}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: top != null
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            bottom: bottom != null
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            left: left != null
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            right: right != null
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}