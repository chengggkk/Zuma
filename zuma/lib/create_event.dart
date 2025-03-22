import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'navbar.dart'; // Import the bottom navigation bar

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  _CreateEventPageState createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  // Form controller
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Default values - using current date instead of hardcoded dates
  late DateTime _startTime;
  late DateTime _endTime;
  final bool _isPublic = true;
  final String _participantLimit = "Unlimited"; // Unlimited participants

  // Category selection
  String _selectedCategory = "AI"; // Default category
  final List<String> _categories = [
    "AI",
    "Blockchain",
    "Web3",
    "Tech",
    "Social",
    "Other",
  ];

  // Loading state
  bool _isLoading = false;

  // MongoDB connection
  mongo.Db? _db;

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _loadEnvAndConnectDB();
  }

  // Initialize dates with current date
  void _initializeDates() {
    final now = DateTime.now();
    _startTime = DateTime(now.year, now.month, now.day, 16, 0); // 4:00 PM
    _endTime = DateTime(now.year, now.month, now.day, 17, 0); // 5:00 PM
  }

  // Load environment variables before connecting to DB
  Future<void> _loadEnvAndConnectDB() async {
    try {
      await dotenv
          .load(); // Make sure this completes before using env variables
      await _connectToMongoDB();
    } catch (e) {
      print("Error loading environment variables: $e");
    }
  }

  // Connect to MongoDB
  Future<void> _connectToMongoDB() async {
    try {
      // Get MongoDB URI from .env file
      final mongoUri = dotenv.env['MONGODB_URI'] ?? '';

      if (mongoUri.isEmpty) {
        print("Error: MONGODB_URI not found in .env file");
        return;
      }

      _db = await mongo.Db.create(mongoUri);
      await _db!.open();
      print("Connected to MongoDB");
    } catch (e) {
      print("Error connecting to MongoDB: $e");
    }
  }

  // Save event to MongoDB
  Future<bool> _saveEventToMongoDB(Map<String, dynamic> eventData) async {
    try {
      if (_db == null || !_db!.isConnected) {
        // Attempt to reconnect
        await _connectToMongoDB();

        // If still not connected, return false
        if (_db == null || !_db!.isConnected) {
          print("Failed to connect to MongoDB");
          return false;
        }
      }

      final eventsCollection = _db!.collection('events');

      // Convert DateTime objects to ISO strings for MongoDB
      final Map<String, dynamic> eventDoc = {
        'name': eventData['name'],
        'startTime': eventData['startTime'].toIso8601String(),
        'endTime': eventData['endTime'].toIso8601String(),
        'location': eventData['location'],
        'description': eventData['description'],
        'isPublic': eventData['isPublic'],
        'participantLimit': eventData['participantLimit'],
        'category': eventData['category'], // Add category field
        'createdAt': DateTime.now().toIso8601String(),
      };

      final result = await eventsCollection.insertOne(eventDoc);
      return result.isSuccess;
    } catch (e) {
      print("Error saving event to MongoDB: $e");
      return false;
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _closeMongoDBConnection();
    super.dispose();
  }

  // Close MongoDB connection
  Future<void> _closeMongoDBConnection() async {
    try {
      if (_db != null && _db!.isConnected) {
        await _db!.close();
        print("Closed MongoDB connection");
      }
    } catch (e) {
      print("Error closing MongoDB connection: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8E77AC), // Purple gradient background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Create Event',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Event Banner
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.pink[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pool with stars (simplified)
                        Positioned(
                          bottom: 40,
                          child: Container(
                            width: 180,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text(
                                'esc',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Ladder
                        Positioned(
                          right: 80,
                          bottom: 60,
                          child: Container(
                            width: 40,
                            height: 80,
                            color: Colors.transparent,
                            child: Column(
                              children: [
                                Container(height: 2, color: Colors.white),
                                const SizedBox(height: 10),
                                Container(height: 2, color: Colors.white),
                                const SizedBox(height: 10),
                                Container(height: 2, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                        // Camera icon
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[600],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Event Name Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextFormField(
                      controller: _eventNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Event Name',
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an event name';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Selection
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: Colors.white),
                        border: InputBorder.none,
                      ),
                      dropdownColor: const Color(0xFF8E77AC),
                      style: const TextStyle(color: Colors.white),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCategory = newValue!;
                        });
                      },
                      items:
                          _categories.map<DropdownMenuItem<String>>((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start Time
                  TimeSelectionTile(
                    title: 'Start',
                    time: _startTime,
                    onTap: () async {
                      // Get current date for the picker
                      final now = DateTime.now();

                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: now, // Use current date
                        firstDate: now, // Use current date
                        lastDate: DateTime(
                          now.year + 1,
                          now.month,
                          now.day,
                        ), // One year from now
                      );

                      if (picked != null) {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_startTime),
                        );

                        if (pickedTime != null) {
                          setState(() {
                            _startTime = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );

                            // Update end time to be after start time
                            if (_endTime.isBefore(_startTime)) {
                              _endTime = _startTime.add(
                                const Duration(hours: 1),
                              );
                            }
                          });
                        }
                      }
                    },
                  ),

                  // End Time
                  TimeSelectionTile(
                    title: 'End',
                    time: _endTime,
                    showDate: false,
                    onTap: () async {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_endTime),
                      );
                      if (pickedTime != null) {
                        setState(() {
                          // Make sure end time is on same day as start time
                          _endTime = DateTime(
                            _startTime.year,
                            _startTime.month,
                            _startTime.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );

                          // If end time is before start time, adjust it to the next day
                          if (_endTime.isBefore(_startTime)) {
                            _endTime = _endTime.add(const Duration(days: 1));
                          }
                        });
                      }
                    },
                  ),

                  // Location
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place, color: Colors.white),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _locationController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Choose Location',
                              hintStyle: TextStyle(color: Colors.white70),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _descriptionController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Description',
                              hintStyle: TextStyle(color: Colors.white70),
                              border: InputBorder.none,
                            ),
                            maxLines: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Choose',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Visibility
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.public, color: Colors.white),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Visibility',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        Text(
                          'public',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Participant Limit
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline, color: Colors.white),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Limit',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        Text(
                          _participantLimit,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Create Event Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(28),
                ),
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : TextButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                _isLoading = true;
                              });

                              // Process event creation
                              final eventData = {
                                'name': _eventNameController.text,
                                'startTime': _startTime,
                                'endTime': _endTime,
                                'location': _locationController.text,
                                'description': _descriptionController.text,
                                'isPublic': _isPublic,
                                'participantLimit': _participantLimit,
                                'category': _selectedCategory, // Add category
                              };

                              // Save to MongoDB
                              final success = await _saveEventToMongoDB(
                                eventData,
                              );

                              setState(() {
                                _isLoading = false;
                              });

                              if (success) {
                                // Show success message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Event created successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );

                                // Navigate back to the BottomNavBar with proper index
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const BottomNavBar(),
                                  ),
                                );
                              } else {
                                // Show error message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to create event. Please try again.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text(
                            'Create Event',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom widget for time selection
class TimeSelectionTile extends StatelessWidget {
  final String title;
  final DateTime time;
  final VoidCallback onTap;
  final bool showDate;

  const TimeSelectionTile({
    super.key,
    required this.title,
    required this.time,
    required this.onTap,
    this.showDate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Center(
                  child: Icon(Icons.circle, color: Colors.blue, size: 16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (showDate)
                      Text(
                        '${time.year}/${time.month}/${time.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    Text(
                      'Afternoon ${time.hour > 12 ? time.hour - 12 : time.hour}:${time.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
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
}
