import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'mongodb_service.dart';

class EventDetailPage extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final Color bannerColor;
  final String currentUserEmail; // Add current user email

  const EventDetailPage({
    Key? key,
    required this.eventId,
    required this.eventTitle,
    required this.bannerColor,
    required this.currentUserEmail, // Required parameter
  }) : super(key: key);

  @override
  _EventDetailPageState createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool _isLoading = true;
  bool _isAttending = false;
  bool _isJoining = false;
  String _error = '';
  Event? _event;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _fetchEventDetails();
  }

  // Fetch event details using findOne
  Future<void> _fetchEventDetails() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Use the MongoDBService to find the event by ID
      final event = await MongoDBService.findEventById(widget.eventId);

      if (event == null) {
        setState(() {
          _error = 'Event not found';
          _isLoading = false;
        });
        return;
      }

      // Check if user is already attending
      final isAttending = await MongoDBService.isUserAttending(
        widget.eventId,
        widget.currentUserEmail,
      );

      // Get user role if attending
      String? userRole;
      if (isAttending) {
        userRole = await MongoDBService.getUserRole(
          widget.eventId,
          widget.currentUserEmail,
        );
      }

      setState(() {
        _event = event;
        _isAttending = isAttending;
        _userRole = userRole;
        _isLoading = false;
      });

      print("Successfully fetched event details: ${event.name}");
      print("User is attending: $_isAttending");
      print("User role: $_userRole");
    } catch (e) {
      setState(() {
        _error = 'Error fetching event details: $e';
        _isLoading = false;
      });
      print("Error fetching event: $e");
    }
  }

  // Update the _joinEvent method to properly handle the event ID
  Future<void> _joinEvent() async {
    if (_event == null) return;

    setState(() {
      _isJoining = true;
    });

    try {
      // Create attendee object with email from widget
      final attendee = Attendee(
        email: widget.currentUserEmail,
        role: 'attendee', // Default role for new attendees
        joinedAt: DateTime.now(),
      );

      // Add to database - use the correct eventId from widget
      final result = await MongoDBService.addAttendeeToEvent(
        widget.eventId, // This should properly pass the MongoDB ObjectId
        attendee,
      );

      if (result) {
        // Refresh event details to show updated attendee list
        await _fetchEventDetails();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the event!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are already attending this event'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print("Error joining event: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join the event: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8E77AC), // Purple background
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : _error.isNotEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        _error,
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF8E77AC),
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              )
              : _buildEventDetails(),
    );
  }

  Widget _buildEventDetails() {
    // If we have no event data but no error, show placeholder
    if (_event == null) {
      return const Center(
        child: Text(
          'No event data available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // Format dates
    final dateFormat = DateFormat('yyyy/MM/dd');
    final timeFormat = DateFormat('h:mm a');
    final formattedStartDate = dateFormat.format(_event!.startTime);
    final formattedStartTime = timeFormat.format(_event!.startTime);
    final formattedEndTime = timeFormat.format(_event!.endTime);

    // Determine category-based icon
    IconData categoryIcon = Icons.event;
    if (_event!.category == 'AI') {
      categoryIcon = Icons.smart_toy;
    } else if (_event!.category == 'Blockchain') {
      categoryIcon = Icons.link;
    } else if (_event!.category == 'Art & Culture') {
      categoryIcon = Icons.palette;
    } else if (_event!.category == 'Climate') {
      categoryIcon = Icons.wb_sunny;
    }

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // App bar with image
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF8E77AC),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  _event!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  color: widget.bannerColor,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Event banner/image
                      Center(
                        child: Icon(
                          categoryIcon,
                          size: 80,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      // Category tag if available
                      if (_event!.category != null)
                        Positioned(
                          top: 48,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _event!.category!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // Gradient overlay for better text visibility
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 80,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date and Time Section
                    EventInfoCard(
                      icon: Icons.calendar_today,
                      title: 'Date & Time',
                      children: [
                        Text(
                          '$formattedStartDate, $formattedStartTime - $formattedEndTime',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Add to Calendar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Location Section
                    EventInfoCard(
                      icon: Icons.location_on,
                      title: 'Location',
                      children: [
                        Text(
                          _event!.location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Map',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Description
                    EventInfoCard(
                      icon: Icons.description,
                      title: 'Details',
                      children: [
                        Text(
                          _event!.description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Participant Limit
                    EventInfoCard(
                      icon: Icons.people,
                      title: 'Attendance',
                      children: [
                        Text(
                          'Limit: ${_event!.participantLimit}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Current Attendees:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Display actual attendees if available
                            if (_event!.attendees.isNotEmpty)
                              ..._buildAttendeeAvatars()
                            else ...[
                              for (int i = 0; i < 3; i++)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        Colors.primaries[i %
                                            Colors.primaries.length],
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + i),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                child: const Center(
                                  child: Text(
                                    '+5',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 16),

                        // User status display
                        if (_isAttending)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'You are attending as ${_userRole ?? 'attendee'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 100,
                    ), // Extra space for the fixed button
                    // Event created time
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                      child: Text(
                        'Event created on: ${dateFormat.format(_event!.createdAt)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),

                    // Host information
                    if (_event!.hostEmail.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                        child: Text(
                          'Hosted by: ${_event!.hostEmail}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Fixed Attend Button at the bottom
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child:
              _isAttending
                  ? ElevatedButton(
                    onPressed: null, // Button is disabled
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Already Applied',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ElevatedButton(
                    onPressed: _isJoining ? null : _joinEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child:
                        _isJoining
                            ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Joining Event...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            )
                            : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Attend This Event',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                  ),
        ),
      ],
    );
  }

  // Helper method to build attendee avatars
  List<Widget> _buildAttendeeAvatars() {
    final List<Widget> avatars = [];
    final maxVisibleAttendees = 4; // Maximum number to show before "+X more"

    // If there are no attendees, return empty list
    if (_event!.attendees.isEmpty) {
      return avatars;
    }

    // Determine how many to display
    final int totalAttendees = _event!.attendees.length;
    final int visibleCount =
        totalAttendees > maxVisibleAttendees
            ? maxVisibleAttendees -
                1 // Save space for +X more
            : totalAttendees;

    // Add visible attendee avatars
    for (int i = 0; i < visibleCount; i++) {
      final attendee = _event!.attendees[i];

      // Get first letter of email for avatar
      final String initial =
          attendee.email.isNotEmpty ? attendee.email[0].toUpperCase() : '?';

      // Generate color based on email (for consistency)
      final int colorIndex = attendee.email.hashCode % Colors.primaries.length;

      avatars.add(
        Container(
          margin: const EdgeInsets.only(right: 8),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.primaries[colorIndex],
            border:
                attendee.role == 'host'
                    ? Border.all(color: Colors.yellow, width: 2)
                    : null,
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (attendee.role == 'host')
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: const BoxDecoration(
                      color: Colors.yellow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 10,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Add +X more if needed
    if (totalAttendees > maxVisibleAttendees) {
      avatars.add(
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.3),
          ),
          child: Center(
            child: Text(
              '+${totalAttendees - visibleCount}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return avatars;
  }
}

class EventInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const EventInfoCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
