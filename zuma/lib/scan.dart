import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  Barcode? result;
  bool isFlashOn = false;
  bool isCameraPermissionGranted = false;

  // Camera controller for the new implementation
  late CameraController cameraController;
  late List<CameraDescription> cameras;
  bool isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        return;
      }

      // Initialize camera controller with the first camera (usually back camera)
      cameraController = CameraController(cameras[0], ResolutionPreset.max);

      // Initialize the controller and update the UI
      await cameraController.initialize();
      if (!mounted) return;

      setState(() {
        isCameraInitialized = true;
      });

      // Enable flash if needed
      if (isFlashOn) {
        await cameraController.setFlashMode(FlashMode.torch);
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    qrController?.dispose();
    if (isCameraInitialized) {
      cameraController.dispose();
    }
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

    if (isCameraInitialized) {
      if (Platform.isAndroid) {
        cameraController.pausePreview();
      } else if (Platform.isIOS) {
        cameraController.resumePreview();
      }
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      setState(() {
        isCameraPermissionGranted = true;
      });
    } else if (status.isPermanentlyDenied) {
      // If permission is permanently denied, open app settings
      await openAppSettings();
    } else {
      // Show a dialog explaining why we need camera permission
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (BuildContext context) => AlertDialog(
                title: const Text('Camera Permission'),
                content: const Text(
                  'Camera permission is required to scan QR codes. Please grant camera permission to continue.',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _requestCameraPermission(); // Try requesting again
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
        );
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
        // Optionally pause camera when a QR code is detected
        // controller.pauseCamera();

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
    if (isCameraInitialized) {
      // Using CameraController for flash
      if (isFlashOn) {
        await cameraController.setFlashMode(FlashMode.off);
      } else {
        await cameraController.setFlashMode(FlashMode.torch);
      }
    } else {
      // Fallback to QR controller for flash
      await qrController?.toggleFlash();
    }

    setState(() {
      isFlashOn = !isFlashOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        elevation: 0,
        actions: [
          if (isCameraPermissionGranted)
            IconButton(
              icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _toggleFlash,
            ),
        ],
      ),
      body:
          !isCameraPermissionGranted
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera permission is required',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await _requestCameraPermission();
                        // Force rebuild after permission request
                        if (mounted) setState(() {});
                      },
                      child: const Text('Request Permission'),
                    ),
                  ],
                ),
              )
              : isCameraInitialized
              ? _buildCameraView()
              : _buildLegacyQRView(),
    );
  }

  Widget _buildCameraView() {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CameraPreview(cameraController),
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
