import 'package:flutter/material.dart';
import 'home.dart';
import 'explore.dart';
import 'create_event.dart';
import 'scan.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;

  // Mock user email for demo purposes
  final String currentUserEmail = "user@example.com";

  // Pages that will be displayed when navigation items are tapped
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Initialize pages with the required parameters
    _pages = [
      HomePage(userEmail: currentUserEmail), // Pass the userEmail parameter
      ExplorePage(currentUserEmail: currentUserEmail), // Pass currentUserEmail
      const ScanPage(),
      const CreateEventPage(),
      const NotificationsPage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Important for 5+ items
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: false, // Hide labels for unselected items
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_outlined),
            activeIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), elevation: 0),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100 * ((index % 5) + 1)],
              child: const Icon(Icons.notifications, color: Colors.white),
            ),
            title: Text('Notification ${index + 1}'),
            subtitle: const Text('This is a sample notification message'),
            trailing: Text('${index + 1}m ago'),
          );
        },
      ),
    );
  }
}
