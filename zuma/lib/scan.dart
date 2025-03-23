import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:mopro_flutter/mopro_flutter.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  Barcode? result;
  bool isFlashOn = false;

  // Add MoPro Flutter plugin
  final MoproFlutter _moproFlutterPlugin = MoproFlutter();
  bool? verificationResult;
  bool isVerifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (qrController == null || !mounted) return;

    if (state == AppLifecycleState.inactive) {
      qrController?.pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      qrController?.resumeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    qrController?.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (qrController != null) {
      if (Platform.isAndroid) {
        qrController!.pauseCamera();
      } else if (Platform.isIOS) {
        qrController!.resumeCamera();
      }
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      qrController = controller;
    });

    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
      });

      // Show a snackbar with the result
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanned: ${result!.code}'),
            duration: const Duration(seconds: 3),
          ),
        );

        // Execute verification code after scanning
        if (result!.code != null) {
          _executeVerification(result!.code!);
        }
      }
    });
  }

  void _toggleFlash() async {
    if (qrController != null) {
      try {
        await qrController!.toggleFlash();
        setState(() {
          isFlashOn = !isFlashOn;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error toggling flash'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _flipCamera() async {
    if (qrController != null) {
      try {
        await qrController!.flipCamera();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error switching camera'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _executeVerification(String scannedData) async {
    try {
      setState(() {
        isVerifying = true;
      });

      // Separate proof and inputs as per your code
      List<String> separated = scannedData.split('SPLIT');

      if (separated.length >= 2) {
        String proof = separated[0]; // The first part (proof)
        String inputs = separated[1]; // The second part (inputs)

        // Execute the verification with MoPro plugin
        bool? valid = await _moproFlutterPlugin.semaphoreVerify(proof, inputs);

        // Update state with verification result
        setState(() {
          verificationResult = valid;
          isVerifying = false;
        });

        print('Verification result: $valid');
      } else {
        // If the QR code doesn't have the expected format
        setState(() {
          verificationResult = false;
          isVerifying = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid QR code format: Expected proof and inputs'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Handle any errors
      setState(() {
        verificationResult = false;
        isVerifying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification error: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );

      print('Verification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
            tooltip: 'Toggle Flash',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: _flipCamera,
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Column(
        children: [
          // Scanner view
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Theme.of(context).primaryColor,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: MediaQuery.of(context).size.width * 0.7,
                  ),
                ),

                // Scanning indicator
                Positioned(
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Scanning...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Result section
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Scan Result',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (result != null && result!.code != null) ...[
                    Expanded(
                      child: SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Format: ${result!.format.name}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                result!.code ?? 'Unknown QR code',
                                style: const TextStyle(fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              // Show verification result if available
                              if (isVerifying)
                                const CircularProgressIndicator()
                              else if (verificationResult != null)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        verificationResult!
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        verificationResult!
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color:
                                            verificationResult!
                                                ? Colors.green
                                                : Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        verificationResult!
                                            ? 'Verification Successful'
                                            : 'Verification Failed',
                                        style: TextStyle(
                                          color:
                                              verificationResult!
                                                  ? Colors.green
                                                  : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Add action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            // Reset the scan result and verification
                            setState(() {
                              result = null;
                              verificationResult = null;
                              isVerifying = false;
                            });
                            // Resume camera if paused
                            qrController?.resumeCamera();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Scan Again'),
                        ),
                        if (verificationResult == null &&
                            !isVerifying &&
                            result != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (result!.code != null) {
                                  _executeVerification(result!.code!);
                                }
                              },
                              icon: const Icon(Icons.verified_user),
                              label: const Text('Verify'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      'Position a QR code in the scanning area',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
