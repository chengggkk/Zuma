import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRCodePage extends StatelessWidget {
  final String eventId;
  final String eventTitle;
  final String userName;
  final DateTime registrationTime;

  QRCodePage({
    Key? key,
    required this.eventId,
    required this.eventTitle,
    this.userName = "Guest User",
    DateTime? registrationTime,
  }) : this.registrationTime = registrationTime ?? DateTime.now(),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    // Create QR code data with event information
    final String qrData = """
    {
      "eventId": "$eventId",
      "eventTitle": "$eventTitle",
      "user": "$userName",
      "registrationTime": "${registrationTime.toIso8601String()}",
      "ticketId": "${DateTime.now().millisecondsSinceEpoch}"
    }
    """;

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
              // Event title and info
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      eventTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E77AC).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            color: Color(0xFF8E77AC),
                            size: 18,
                          ),
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
              ),

              // QR Code
              Container(
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
                  embeddedImageStyle: QrEmbeddedImageStyle(
                    size: const Size(40, 40),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Instructions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    const Text(
                      'Please present this QR Code on the day of the event',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Registration time: ${_formatDateTime(registrationTime)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Implement save to gallery functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('QR Code saved to gallery'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Save to Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8E77AC),
                        side: const BorderSide(color: Color(0xFF8E77AC)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Format date time to a readable string
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
