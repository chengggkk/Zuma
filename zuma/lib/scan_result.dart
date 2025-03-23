import 'package:flutter/material.dart';
import 'navbar.dart'; // Import the navigation bar instead of home directly
import 'scan.dart'; // Import ScanPage for navigation back to scan

class ScanResultPage extends StatelessWidget {
  final bool isValid;
  final String? userEmail; // Add user email parameter

  const ScanResultPage({
    Key? key,
    required this.isValid,
    this.userEmail, // Make it optional
  }) : super(key: key);

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
                  // Navigate back to scan page with userEmail
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => ScanPage(userEmail: userEmail),
                    ),
                  );
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
                    if (userEmail != null) {
                      // Navigate to BottomNavBar with the user email
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder:
                              (context) => BottomNavBarWithUser(
                                userEmail: userEmail!,
                                username:
                                    null, // Username is optional in your implementation
                              ),
                        ),
                      );
                    } else {
                      // If no user email is available, show a message or navigate to login
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'User information is missing. Please log in again.',
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );
                      // Navigate to login page
                      Navigator.of(context).pushReplacementNamed('/');
                    }
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
