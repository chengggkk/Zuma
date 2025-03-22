import 'package:flutter/material.dart';
import 'event_detail.dart' as detail;
// Import the MongoDB service with an alias
import 'mongodb_service.dart';

class ExplorePage extends StatefulWidget {
  final String currentUserEmail; // Add this parameter

  const ExplorePage({
    super.key,
    required this.currentUserEmail, // Make it required
  });

  @override
  _ExplorePageState createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  // Categories for filtering
  final List<CategoryItem> _categories = [
    CategoryItem('All', Icons.category),
    CategoryItem('AI', Icons.smart_toy),
    CategoryItem('Blockchain', Icons.link), // Added blockchain category
    CategoryItem('Art & Culture', Icons.palette),
    CategoryItem('Climate', Icons.wb_sunny),
  ];

  // List of events from MongoDB
  List<Event> _events = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  // Fetch events from MongoDB
  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final events = await MongoDBService.getAllEvents();

      setState(() {
        _events = events;
        _isLoading = false;
      });

      print("Fetched ${events.length} events");
    } catch (e) {
      setState(() {
        _error = 'Error fetching events: $e';
        _isLoading = false;
      });
      print(_error);
    }
  }

  // Filter events by category
  Future<void> _filterByCategory(String category) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      List<Event> events;

      if (category == 'All') {
        events = await MongoDBService.getAllEvents();
      } else {
        events = await MongoDBService.getEventsByCategory(category);
      }

      setState(() {
        _events = events;
        _isLoading = false;
      });

      print("Filtered to ${events.length} events in $category category");
    } catch (e) {
      setState(() {
        _error = 'Error filtering events: $e';
        _isLoading = false;
      });
      print(_error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explore'), elevation: 0),
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Something went wrong',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          _error,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchEvents,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
                : CustomScrollView(
                  slivers: [
                    // City section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Taipei',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                // View all events in this city
                              },
                              child: Row(
                                children: const [
                                  Text(
                                    'View All',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: Colors.blue),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Trending Events section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Text(
                          'All Events (${_events.length})',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.7),
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),

                    // MongoDB Events
                    SliverToBoxAdapter(
                      child:
                          _events.isEmpty
                              ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.event_busy,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No events found',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.headlineSmall,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try creating a new event or changing your filters',
                                        textAlign: TextAlign.center,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              : SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.38,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: _events.length,
                                  itemBuilder: (context, index) {
                                    final event = _events[index];
                                    return _buildEventCardFromDB(event);
                                  },
                                ),
                              ),
                    ),

                    // Static Event Cards (can be removed once MongoDB is working)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          top: 16,
                          bottom: 8,
                        ),
                        child: Text(
                          'Example Events',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.7),
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _buildEventCard(
                              'NVIDIA GTC 2025',
                              'Chinese guided tech sharing session GPU.AI meetup',
                              'Mar 24, 6:00 PM',
                              ['Gladys Chang', 'Jinny Lin'],
                              Colors.blue.shade900,
                              'AI',
                            ),
                            _buildEventCard(
                              'Babylon Genesis Pre-Launch Meetup: Taipei',
                              'featuring Zeus Network | Bitcoin to Solana',
                              'Mar 24, 7:00 PM',
                              ['Jihoon', 'Zeus Network'],
                              Colors.orange.shade900,
                              'Blockchain',
                            ),
                            _buildEventCard(
                              'AI Future Unveiled - NVIDIA GTC 2025',
                              'Chinese guided sharing session',
                              'Mar 26, 6:00 PM',
                              ['Jinny Lin (NVIDIA)', 'David Zheng'],
                              Colors.green.shade900,
                              'AI',
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Categories section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Categories',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                // View all categories
                              },
                              child: Row(
                                children: const [
                                  Text(
                                    'View All',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: Colors.blue),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Category grid
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                _filterByCategory(_categories[index].name);
                              },
                              child: _buildCategoryCard(_categories[index]),
                            );
                          },
                        ),
                      ),
                    ),

                    // Additional sections remain the same...
                    // Cities section, etc.

                    // Add bottom padding
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchEvents,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  // Build event card from database
  Widget _buildEventCardFromDB(Event event) {
    // Determine color based on category
    Color cardColor;

    if (event.category == 'AI') {
      cardColor = Colors.blue.shade900;
    } else if (event.category == 'Blockchain') {
      cardColor = Colors.orange.shade900;
    } else if (event.category == 'Art & Culture') {
      cardColor = Colors.purple.shade900;
    } else if (event.category == 'Climate') {
      cardColor = Colors.green.shade900;
    } else {
      cardColor = Colors.grey.shade700;
    }

    // Format date for display
    final dateFormat =
        '${event.startTime.month}/${event.startTime.day}, ${event.startTime.hour}:${event.startTime.minute.toString().padLeft(2, '0')} ${event.startTime.hour >= 12 ? 'PM' : 'AM'}';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => detail.EventDetailPage(
                  eventId: event.id,
                  eventTitle: event.name,
                  bannerColor: cardColor,
                  currentUserEmail:
                      widget.currentUserEmail, // Pass current user email
                ),
          ),
        );
      },
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 16, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event image
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Stack(
                children: [
                  // Event icon in the center
                  Center(
                    child: Icon(
                      event.category == 'AI'
                          ? Icons.smart_toy
                          : event.category == 'Blockchain'
                          ? Icons.link
                          : Icons.event,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  // Tag in the top-right corner
                  if (event.category != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
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
            // Event details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    event.name,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Description
                  Text(
                    event.description,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Date and time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.grey.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.grey.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

  // The rest of your existing methods (_buildEventCard, _buildCategoryCard, _buildCityCard)
  // Remain the same as in your original code...

  Widget _buildEventCard(
    String title,
    String description,
    String dateTime,
    List<String> organizers,
    Color color,
    String tag,
  ) {
    // Original implementation (unchanged)
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => detail.EventDetailPage(
                  eventId: title.toLowerCase().replaceAll(' ', '_'),
                  eventTitle: title,
                  bannerColor: color,
                  currentUserEmail:
                      widget
                          .currentUserEmail, // Pass current user email here too
                ),
          ),
        );
      },
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 16, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event image
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Stack(
                children: [
                  // Event icon in the center
                  Center(
                    child: Icon(
                      tag == 'AI'
                          ? Icons.smart_toy
                          : tag == 'Blockchain'
                          ? Icons.link
                          : Icons.event,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  // Tag in the top-right corner
                  if (tag.isNotEmpty)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
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
            // Event details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Organizer profiles
                  Row(
                    children: [
                      for (int i = 0; i < organizers.length && i < 3; i++)
                        Container(
                          width: 24,
                          height: 24,
                          margin: EdgeInsets.only(right: i == 0 ? 4 : 0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 16,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          organizers.join(', '),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Description
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Date and time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.grey.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateTime,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
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

  Widget _buildCategoryCard(CategoryItem category) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                category.icon,
                color:
                    category.name == 'AI'
                        ? Colors.purple.shade300
                        : category.name == 'Blockchain'
                        ? Colors.orange.shade300
                        : category.name == 'Art & Culture'
                        ? Colors.green.shade300
                        : Colors.amber.shade300,
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityCard(String name, IconData icon) {
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Gradient overlay for better text visibility
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
              ),
            ),
          ),
          // City icon and name
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryItem {
  final String name;
  final IconData icon;

  CategoryItem(this.name, this.icon);
}
