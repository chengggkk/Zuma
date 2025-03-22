import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

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

  // Camera controller for the new implementation
  CameraController? cameraController;
  List<CameraDescription>? cameras;
  bool isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = cameraController;

    // App state changed before we got the chance to initialize.
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      cameras = await availableCameras();
      if (cameras == null || cameras!.isEmpty) {
        print('No cameras available');
        return;
      }

      // Initialize camera controller with the first camera (usually back camera)
      cameraController = CameraController(
        cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      // Initialize the controller and update the UI
      await cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        isCameraInitialized = true;
        print('Camera initialized successfully');
      });

      // Enable flash if needed
      if (isFlashOn) {
        await cameraController!.setFlashMode(FlashMode.torch);
      }
    } catch (e) {
      print('Error initializing camera: $e');
      // Try legacy QR view if camera fails
      setState(() {
        isCameraInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    qrController?.dispose();
    cameraController?.dispose();
    super.dispose();
  }

  // In case the widget is removed from the widget tree while the asynchronous platform
  // message is in flight, we handle this to avoid memory leaks
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

    if (cameraController != null && cameraController!.value.isInitialized) {
      if (Platform.isAndroid) {
        cameraController!.pausePreview();
      } else if (Platform.isIOS) {
        cameraController!.resumePreview();
      }
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    qrController = controller;
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
      });

      // You can handle the scanned result here
      if (result != null) {
        // Show a snackbar with the result
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanned: ${result!.code}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _toggleFlash() async {
    if (isCameraInitialized && cameraController != null) {
      // Using CameraController for flash
      try {
        if (isFlashOn) {
          await cameraController!.setFlashMode(FlashMode.off);
        } else {
          await cameraController!.setFlashMode(FlashMode.torch);
        }
        setState(() {
          isFlashOn = !isFlashOn;
        });
      } catch (e) {
        print('Error toggling flash: $e');
      }
    } else if (qrController != null) {
      // Fallback to QR controller for flash
      try {
        await qrController!.toggleFlash();
        setState(() {
          isFlashOn = !isFlashOn;
        });
      } catch (e) {
        print('Error toggling QR flash: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        elevation: 0,
        actions: [
          if (isCameraInitialized || qrController != null)
            IconButton(
              icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _toggleFlash,
            ),
        ],
      ),
      body:
          isCameraInitialized &&
                  cameraController != null &&
                  cameraController!.value.isInitialized
              ? _buildCameraView()
              : _buildLegacyQRView(),
    );
  }

  Widget _buildCameraView() {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return const Center(child: Text('Camera not initialized'));
    }

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CameraPreview(cameraController!),
              // QR scan overlay
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 10,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.width * 0.8,
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  result != null
                      ? 'QR Code: ${result!.code}'
                      : 'Scan a QR code',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Debug info
                Text(
                  'Camera active: ${cameraController!.value.isInitialized}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegacyQRView() {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Theme.of(context).primaryColor,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: MediaQuery.of(context).size.width * 0.8,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  result != null
                      ? 'QR Code: ${result!.code}'
                      : 'Scan a QR code',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
