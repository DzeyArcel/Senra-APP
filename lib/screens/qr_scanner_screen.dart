import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'device_pairing_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool scanned = false; // Prevent double scanning

  void _onDetect(BarcodeCapture capture) {
    if (scanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    scanned = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DevicePairingScreen(
          scannedDeviceId: code.trim().toUpperCase(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: Column(
          children: [
            // ← Back
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back, color: Colors.white70, size: 18),
                        SizedBox(width: 4),
                        Text(
                          "Back",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Text(
              "Device Pairing",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "Scan Device QR Code",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            const Text(
              "Point your camera at the QR code on your Senra device",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),

            const SizedBox(height: 30),

            // SCANNER BOX (Figma Style)
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: MobileScannerController(
                            detectionSpeed: DetectionSpeed.normal,
                            facing: CameraFacing.back,
                          ),
                          onDetect: _onDetect,
                        ),

                        // Blue border overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF33B5FF),
                                width: 3,
                              ),
                            ),
                          ),
                        ),

                        // Frame icon text
                        const Center(
                          child: Text(
                            "Position QR code within frame",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // SIMULATE BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DevicePairingScreen(scannedDeviceId: "SNR-TEST-001"),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162233),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF33B5FF)),
                  ),
                  child: const Center(
                    child: Text(
                      "Simulate QR Code Detected",
                      style: TextStyle(
                        color: Color(0xFF33B5FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
