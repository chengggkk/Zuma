import 'package:flutter/material.dart';

class ScanResultPage extends StatelessWidget {
  final bool isValid;

  const ScanResultPage({Key? key, required this.isValid}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Result'), elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon based on validation result
              Icon(
                isValid ? Icons.check_circle_outline : Icons.cancel_outlined,
                size: 120,
                color: isValid ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 32),
              // Result text
              Text(
                isValid ? 'Welcome' : 'The ticket is invalid',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isValid ? Colors.green.shade700 : Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Additional information
              Text(
                isValid
                    ? 'Your ticket has been verified successfully.'
                    : 'We could not verify your ticket. Please try again or contact support.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // Back to scanner button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(
                    '/scan',
                  ); // Assuming you have a named route
                  // Alternatively:
                  // Navigator.of(context).pushReplacement(
                  //   MaterialPageRoute(builder: (context) => const ScanPage()),
                  // );
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Another Ticket'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              // Home button
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushReplacementNamed('/'); // Go to home page
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Go to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
