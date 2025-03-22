import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mopro_flutter/mopro_flutter.dart';
import 'package:mopro_flutter/mopro_types.dart';
import 'package:flutter/services.dart';

class QRCodePage extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final String userName;
  final DateTime registrationTime;

  const QRCodePage({
    Key? key,
    required this.eventId,
    required this.eventTitle,
    required this.userName,
    required this.registrationTime,
  }) : super(key: key);

  @override
  _QRCodePageState createState() => _QRCodePageState();
}

class _QRCodePageState extends State<QRCodePage> {
  final MoproFlutter _moproFlutterPlugin = MoproFlutter();
  bool isProving = false;
  PlatformException? _error;
  SemaphoreProveResult? _proofResult;

  @override
  Widget build(BuildContext context) {
    // final String qrData = _generateQRData();
    final Future<String> qrData = _generateProof();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Entry QR Code'),
        backgroundColor: const Color(0xFF8E77AC),
      ),
      body: Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildEventInfo(),
              FutureBuilder<String>(
                future: qrData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator(); // Show loading spinner
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('No QR Code Data');
                  }

                  return _buildQRCode(snapshot.data!); // Display QR code
                },
              ),
              const SizedBox(height: 20),
              _buildInstructions(),
            ],
          ),
        ),
      ),
    );
  }

  /// Generates the QR code data
  String _generateQRData() {
    return """
    {
      "eventId": "${widget.eventId}",
      "eventTitle": "${widget.eventTitle}",
      "user": "${widget.userName}",
      "registrationTime": "${widget.registrationTime.toIso8601String()}",
      "ticketId": "${DateTime.now().millisecondsSinceEpoch}"
    }
    """;
  }

  /// Builds event information section
  Widget _buildEventInfo() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Text(
            widget.eventTitle,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF8E77AC).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: Color(0xFF8E77AC), size: 18),
                SizedBox(width: 6),
                Text(
                  'Registration Confirmed',
                  style: TextStyle(
                    color: Color(0xFF8E77AC),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the QR code widget
  Widget _buildQRCode(String qrData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: QrImageView(
        data: qrData,
        version: QrVersions.auto,
        size: 250.0,
        embeddedImage: const AssetImage('assets/app_logo.png'),
        embeddedImageStyle: QrEmbeddedImageStyle(size: const Size(40, 40)),
      ),
    );
  }

  /// Instructions section
  Widget _buildInstructions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          const Text(
            'Please present this QR Code on the day of the event',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            'Registration time: ${_formatDateTime(widget.registrationTime)}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR Code saved to gallery')),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Save to Gallery'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8E77AC),
              side: const BorderSide(color: Color(0xFF8E77AC)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Generates proof using Mopro
  Future<String> _generateProof() async {
    // If proof already exists, return it immediately
    if (_proofResult != null) {
      return _proofResult!.proof;
    }

    setState(() {
      isProving = true;
      _error = null;
      _proofResult = null;
    });

    try {
      var leaves = [
        "3",
        "12117908060695761916205289021945666294466648454297996401752691981878568491412",
        "3",
        "4",
        "5",
      ];
      var proofResult = await _moproFlutterPlugin.semaphoreProve(
        "idSecret",
        leaves,
        "signal",
        "externalNullifier",
      );

      setState(() {
        _proofResult = proofResult;
      });

      print(proofResult?.proof);
      print(proofResult?.inputs);
      String combined = '${proofResult?.proof}\n${proofResult?.inputs}';

      // Separate proof and inputs
      // List<String> separated = combined.split('\n');
      // String proof = separated[0]; // The first part (proof)
      // String inputs = separated[1]; // The second part (inputs)

      return combined;
    } on PlatformException catch (e) {
      setState(() {
        _error = e;
      });

      print("Error: $e");
    } finally {
      setState(() {
        isProving = false;
      });
    }
    return "";
  }

  /// Formats DateTime to a readable format
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
