import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'mongodb_service.dart';
import 'event_detail.dart' as detail;

class HomePage extends StatefulWidget {
  final String? username; // Properly declare the username property
  final String userEmail; // Add user email to fetch their events

  const HomePage({Key? key, this.username, required this.userEmail})
    : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  List<Event> _myEvents = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchMyEvents();
  }

  // Fetch events where the user is an attendee
  Future<void> _fetchMyEvents() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Use MongoDBService to fetch events where the user is an attendee
      final events = await MongoDBService.getEventsForUser(widget.userEmail);

      setState(() {
        _myEvents = events;
        _isLoading = false;
      });

      print("Fetched ${events.length} events for user ${widget.userEmail}");
    } catch (e) {
      setState(() {
        _error = 'Error fetching your events: $e';
        _isLoading = false;
      });
      print("Error fetching user events: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home'), elevation: 0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchMyEvents, // Allow pull-to-refresh
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            physics:
                const AlwaysScrollableScrollPhysics(), // Needed for RefreshIndicator
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back${widget.username != null ? ", ${widget.username}" : ""}!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // My events section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My Events',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                _error.isNotEmpty
                    ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Error loading events: $_error',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _fetchMyEvents,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    )
                    : _myEvents.isEmpty && !_isLoading
                    ? Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'You haven\'t joined any events yet',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _myEvents.length,
                        itemBuilder: (context, index) {
                          final event = _myEvents[index];
                          return _buildEventCard(event, context);
                        },
                      ),
                    ),

                const SizedBox(height: 24),

                // Calendar section
                const Text(
                  'Calendar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Table Calendar widget
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2023, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) {
                        return isSameDay(_selectedDay, day);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onFormatChanged: (format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                      calendarStyle: CalendarStyle(
                        // Today's date marker
                        todayDecoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        // Selected date marker
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonTextStyle: const TextStyle(fontSize: 14),
                        titleCentered: true,
                        formatButtonDecoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      eventLoader: (day) {
                        // Return events for this day
                        return _getEventsForDay(day);
                      },
                    ),
                  ),
                ),

                // Events for the selected day
                if (_selectedDay != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Events on ${DateFormat('MMM d, yyyy').format(_selectedDay!)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        child: const Text('View All'),
                        onPressed: () {
                          // Navigate to see all events on this day
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Display events for the selected day
                  _buildEventsForSelectedDay(),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build event card for horizontal list
  Widget _buildEventCard(Event event, BuildContext context) {
    // Determine color based on category
    Color cardColor;
    IconData categoryIcon;

    if (event.category == 'AI') {
      cardColor = Colors.blue.shade700;
      categoryIcon = Icons.smart_toy;
    } else if (event.category == 'Blockchain') {
      cardColor = Colors.orange.shade700;
      categoryIcon = Icons.link;
    } else if (event.category == 'Art & Culture') {
      cardColor = Colors.purple.shade700;
      categoryIcon = Icons.palette;
    } else if (event.category == 'Climate') {
      cardColor = Colors.green.shade700;
      categoryIcon = Icons.wb_sunny;
    } else {
      cardColor = Colors.grey.shade700;
      categoryIcon = Icons.event;
    }

    return GestureDetector(
      onTap: () {
        // Navigate to event details page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => detail.EventDetailPage(
                  eventId: event.id,
                  eventTitle: event.name,
                  bannerColor: cardColor,
                  currentUserEmail: widget.userEmail,
                ),
          ),
        ).then((_) {
          // Refresh events when returning from detail page
          _fetchMyEvents();
        });
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event banner/header
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Container(
                height: 120,
                color: cardColor,
                child: Stack(
                  children: [
                    // Event icon in the center
                    Center(
                      child: Icon(
                        categoryIcon,
                        size: 48,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    // Category tag if available
                    if (event.category != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            event.category!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Event details
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat(
                          'MMM d, yyyy • h:mm a',
                        ).format(event.startTime),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Get events for a specific day (used by the calendar)
  List<Event> _getEventsForDay(DateTime day) {
    // Filter events that occur on the given day
    return _myEvents.where((event) {
      return isSameDay(event.startTime, day);
    }).toList();
  }

  // Build widget to display events for the selected day
  Widget _buildEventsForSelectedDay() {
    final eventsOnDay = _getEventsForDay(_selectedDay!);

    if (eventsOnDay.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No events scheduled for this day',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      children:
          eventsOnDay.map((event) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    width: 4,
                    color:
                        event.category == 'AI'
                            ? Colors.blue
                            : event.category == 'Blockchain'
                            ? Colors.orange
                            : event.category == 'Art & Culture'
                            ? Colors.purple
                            : event.category == 'Climate'
                            ? Colors.green
                            : Colors.grey,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    event.category == 'AI'
                        ? Icons.smart_toy
                        : event.category == 'Blockchain'
                        ? Icons.link
                        : event.category == 'Art & Culture'
                        ? Icons.palette
                        : event.category == 'Climate'
                        ? Icons.wb_sunny
                        : Icons.event,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${DateFormat('h:mm a').format(event.startTime)} - ${DateFormat('h:mm a').format(event.endTime)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      // Navigate to event details
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => detail.EventDetailPage(
                                eventId: event.id,
                                eventTitle: event.name,
                                bannerColor:
                                    event.category == 'AI'
                                        ? Colors.blue
                                        : event.category == 'Blockchain'
                                        ? Colors.orange
                                        : event.category == 'Art & Culture'
                                        ? Colors.purple
                                        : event.category == 'Climate'
                                        ? Colors.green
                                        : Colors.grey,
                                currentUserEmail: widget.userEmail,
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  // Helper method to check if two dates are the same day
  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
