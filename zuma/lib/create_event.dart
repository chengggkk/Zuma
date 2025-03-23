import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mopro_flutter/mopro_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'navbar.dart'; // Import the bottom navigation bar

// GridFS Service Class - handles image storage in MongoDB
class GridFSService {
  mongo.Db? _db;
  mongo.GridFS? _gridFS;
  final Uuid _uuid = Uuid();

  // Initialize GridFS connection using existing DB connection
  Future<void> initialize(mongo.Db db) async {
    _db = db;
    if (_db != null && _db!.isConnected) {
      _gridFS = mongo.GridFS(_db!, 'eventImages');
      print("GridFS initialized successfully");
    } else {
      throw Exception("Failed to initialize GridFS: Database not connected");
    }
  }

  // Upload an image file to GridFS and return its ID
  Future<String> uploadImage(File imageFile) async {
    try {
      if (_gridFS == null || _db == null) {
        throw Exception("GridFS not initialized");
      }

      // Generate a unique filename
      final String fileName = '${_uuid.v4()}${path.extension(imageFile.path)}';

      // Read the file as bytes
      final Uint8List fileBytes = await imageFile.readAsBytes();

      // Generate a new ObjectId for the file
      final id = mongo.ObjectId();

      // Get file size
      final int fileSize = fileBytes.length;

      // Define chunk size (default is 255KB)
      final int chunkSize = 255 * 1024;

      // Calculate number of chunks
      final int numChunks = (fileSize / chunkSize).ceil();

      // Get the collections
      final filesCollection = _db!.collection('eventImages.files');
      final chunksCollection = _db!.collection('eventImages.chunks');

      // Create file document
      final fileDoc = {
        '_id': id,
        'length': fileSize,
        'chunkSize': chunkSize,
        'uploadDate': DateTime.now(),
        'filename': fileName,
        'contentType': _getContentType(imageFile.path),
        'md5': '', // You could calculate MD5 if needed
      };

      // Insert file document
      await filesCollection.insert(fileDoc);

      // Split file into chunks and insert them
      for (int i = 0; i < numChunks; i++) {
        final int start = i * chunkSize;
        final int end =
            (i + 1) * chunkSize > fileSize ? fileSize : (i + 1) * chunkSize;
        final Uint8List chunkData = fileBytes.sublist(start, end);

        final chunkDoc = {
          'files_id': id,
          'n': i,
          'data': mongo.BsonBinary.from(chunkData),
        };

        await chunksCollection.insert(chunkDoc);
      }

      return id.toHexString();
    } catch (e) {
      print("Error uploading image to GridFS: $e");
      rethrow;
    }
  }

  // Get an image by its ID
  Future<Uint8List?> getImageBytes(String id) async {
    try {
      if (_gridFS == null) {
        throw Exception("GridFS not initialized");
      }

      final objectId = mongo.ObjectId.fromHexString(id);
      final file = await _gridFS!.findOne(mongo.where.id(objectId));

      if (file == null) {
        return null;
      }

      // Get the chunks collection
      final chunksCollection = _db!.collection('eventImages.chunks');

      // Query for all chunks belonging to this file
      final chunks =
          await chunksCollection
              .find(mongo.where.eq('files_id', objectId))
              .toList();

      // Sort the chunks by n (order)
      chunks.sort((a, b) => a['n'] - b['n']);

      // Combine all chunks into a single Uint8List
      final List<int> allBytes = [];
      for (final chunk in chunks) {
        final binData = chunk['data'];
        if (binData is mongo.BsonBinary) {
          allBytes.addAll(binData.byteList);
        }
      }

      return Uint8List.fromList(allBytes);
    } catch (e) {
      print("Error retrieving image from GridFS: $e");
      rethrow;
    }
  }

  // Helper method to determine content type based on file extension
  String _getContentType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}

// Image Upload Component
class EventBannerUpload extends StatefulWidget {
  final Function(File) onImageSelected;
  final double height;

  const EventBannerUpload({
    Key? key,
    required this.onImageSelected,
    this.height = 220,
  }) : super(key: key);

  @override
  _EventBannerUploadState createState() => _EventBannerUploadState();
}

class _EventBannerUploadState extends State<EventBannerUpload> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? selected = await _picker.pickImage(source: source);

      if (selected != null) {
        setState(() {
          _imageFile = File(selected.path);
        });

        // Call the callback function to notify parent
        widget.onImageSelected(_imageFile!);
      }
    } catch (e) {
      // Handle any errors
      print("Error picking image: $e");
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.pink[200],
        borderRadius: BorderRadius.circular(16),
        image:
            _imageFile != null
                ? DecorationImage(
                  image: FileImage(_imageFile!),
                  fit: BoxFit.cover,
                )
                : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Only show placeholder content when no image is selected
          if (_imageFile == null) ...[
            // Upload instruction when no image
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.add_photo_alternate,
                    color: Colors.white,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Tap to upload event banner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Camera icon always visible
          Positioned(
            bottom: 10,
            right: 10,
            child: InkWell(
              onTap: _showImageSourceOptions,
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
          ),

          // Make the entire container tappable
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _showImageSourceOptions,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Main CreateEventPage Widget
class CreateEventPage extends StatefulWidget {
  final String? userEmail; // Make it optional for backward compatibility

  const CreateEventPage({Key? key, this.userEmail}) : super(key: key);

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

  // Image upload
  File? _eventBannerImage;

  // MongoDB connection
  mongo.Db? _db;
  final GridFSService _gridFSService = GridFSService();
  final MoproFlutter _moproFlutterPlugin = MoproFlutter();

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

      // Initialize GridFS after connecting to MongoDB
      await _initializeGridFS();
    } catch (e) {
      print("Error connecting to MongoDB: $e");
    }
  }

  // Initialize GridFS
  Future<void> _initializeGridFS() async {
    try {
      if (_db != null && _db!.isConnected) {
        await _gridFSService.initialize(_db!);
      }
    } catch (e) {
      print("Error initializing GridFS: $e");
    }
  }

  // Modified to use the userEmail passed to the widget
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

      // Upload image if available and get ID
      String? imageId;
      if (eventData['bannerImage'] != null) {
        imageId = await _gridFSService.uploadImage(eventData['bannerImage']);
      }

      // Get current user email
      final String userEmail = await _getCurrentUserEmail();

      // Get commitment for the host
      final commitment = await _moproFlutterPlugin.getIdCommitment(userEmail);

      // Create attendee for the host
      final hostAttendee = {
        'email': userEmail,
        'role': 'host',
        'joinedAt': DateTime.now().toIso8601String(),
        'commitment': commitment,
      };

      // Convert DateTime objects to ISO strings for MongoDB
      final Map<String, dynamic> eventDoc = {
        'name': eventData['name'],
        'startTime': eventData['startTime'].toIso8601String(),
        'endTime': eventData['endTime'].toIso8601String(),
        'location': eventData['location'],
        'description': eventData['description'],
        'isPublic': eventData['isPublic'],
        'participantLimit': eventData['participantLimit'],
        'category': eventData['category'],
        'bannerImageId': imageId,
        'createdAt': DateTime.now().toIso8601String(),
        'hostEmail': userEmail, // Add hostEmail field
        'attendees': [
          hostAttendee,
        ], // Initialize attendees array with host as first attendee
      };

      final result = await eventsCollection.insertOne(eventDoc);
      return result.isSuccess;
    } catch (e) {
      print("Error saving event to MongoDB: $e");
      return false;
    }
  }

  // Updated method to get the current user's email
  Future<String> _getCurrentUserEmail() async {
    // Use the email passed to the widget if available
    if (widget.userEmail != null && widget.userEmail!.isNotEmpty) {
      return widget.userEmail!;
    }

    // If no email is provided, throw an error or handle it appropriately
    // You could get the email from a local storage or authentication service instead
    throw Exception("User email not provided to CreateEventPage");

    // Alternatively, you could get the email from Firebase Auth if you're using it:
    // return FirebaseAuth.instance.currentUser?.email ?? throw Exception("No authenticated user found");
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
                  // Event Banner with image upload
                  EventBannerUpload(
                    onImageSelected: (File file) {
                      setState(() {
                        _eventBannerImage = file;
                      });
                    },
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

                              // Process event creation with image
                              final eventData = {
                                'name': _eventNameController.text,
                                'startTime': _startTime,
                                'endTime': _endTime,
                                'location': _locationController.text,
                                'description': _descriptionController.text,
                                'isPublic': _isPublic,
                                'participantLimit': _participantLimit,
                                'category': _selectedCategory,
                                'bannerImage':
                                    _eventBannerImage, // Add the image file
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
                                // Get the current user's email
                                final userEmail = await _getCurrentUserEmail();

                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => BottomNavBarWithUser(
                                          userEmail: userEmail,
                                          username:
                                              'User', // You can replace this with actual username if available
                                        ),
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

// Add this widget to display an image from GridFS elsewhere in your app
class GridFSImage extends StatelessWidget {
  final String imageId;
  final GridFSService gridFSService;
  final BoxFit fit;
  final double? width;
  final double? height;

  const GridFSImage({
    Key? key,
    required this.imageId,
    required this.gridFSService,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: gridFSService.getImageBytes(imageId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data == null) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.error_outline, size: 40, color: Colors.red),
            ),
          );
        } else {
          return Image.memory(
            snapshot.data!,
            fit: fit,
            width: width,
            height: height,
          );
        }
      },
    );
  }
}
