import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

// Attendee model class
class Attendee {
  final String email;
  final String role; // "host" or "attendee"
  final DateTime joinedAt;
  final String commitment;

  Attendee({required this.email, required this.role, required this.joinedAt, required this.commitment});

  factory Attendee.fromMap(Map<String, dynamic> map) {
    return Attendee(
      email: map['email'] ?? '',
      role: map['role'] ?? 'attendee',
      joinedAt:
          map['joinedAt'] != null
              ? DateTime.parse(map['joinedAt'])
              : DateTime.now(),
      commitment: map['commitment'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
      'commitment': commitment,
    };
  }
}

// Model class for Event
class Event {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String description;
  final bool isPublic;
  final String participantLimit;
  final String? category;
  final String? bannerImageId;
  final DateTime createdAt;
  final List<Attendee> attendees;
  final String hostEmail;

  Event({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.description,
    required this.isPublic,
    required this.participantLimit,
    this.category,
    this.bannerImageId,
    required this.createdAt,
    this.attendees = const [],
    required this.hostEmail,
  });

  factory Event.fromMap(Map<String, dynamic> map) {
    List<Attendee> attendeesList = [];
    if (map['attendees'] != null) {
      attendeesList = List<Attendee>.from(
        (map['attendees'] as List).map(
          (attendee) => Attendee.fromMap(attendee),
        ),
      );
    }

    // Properly handle ObjectId conversion to string
    String idString = '';
    if (map['_id'] is mongo.ObjectId) {
      idString = (map['_id'] as mongo.ObjectId).toHexString();
    } else {
      idString = map['_id'].toString();
    }

    return Event(
      id: idString,
      name: map['name'] ?? '',
      startTime:
          map['startTime'] != null
              ? DateTime.parse(map['startTime'])
              : DateTime.now(),
      endTime:
          map['endTime'] != null
              ? DateTime.parse(map['endTime'])
              : DateTime.now(),
      location: map['location'] ?? '',
      description: map['description'] ?? '',
      isPublic: map['isPublic'] ?? true,
      participantLimit: map['participantLimit'] ?? 'Unlimited',
      category: map['category'],
      bannerImageId: map['bannerImageId'],
      createdAt:
          map['createdAt'] != null
              ? DateTime.parse(map['createdAt'])
              : DateTime.now(),
      attendees: attendeesList,
      hostEmail: map['hostEmail'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'description': description,
      'isPublic': isPublic,
      'participantLimit': participantLimit,
      'category': category,
      'bannerImageId': bannerImageId,
      'createdAt': createdAt.toIso8601String(),
      'attendees': attendees.map((attendee) => attendee.toMap()).toList(),
      'hostEmail': hostEmail,
    };
  }
}

// MongoDB Service class
class MongoDBService {
  static mongo.Db? _db;
  static final GridFSService gridFSService = GridFSService();
  static bool _isInitialized = false;

  // Connect to MongoDB
  static Future<bool> connect() async {
    try {
      await dotenv.load();
      final mongoUri = dotenv.env['MONGODB_URI'] ?? '';

      if (mongoUri.isEmpty) {
        print("MongoDB URI is empty. Please check your .env file.");
        return false;
      }

      print("Attempting to connect to MongoDB...");

      _db = await mongo.Db.create(mongoUri);
      await _db!.open();

      print("Connected to MongoDB successfully!");

      // Initialize GridFS right after successful DB connection
      await gridFSService.initialize(_db!);
      print("GridFS initialized during MongoDB connection");

      return true;
    } catch (e) {
      print("Error connecting to MongoDB: $e");
      return false;
    }
  }

  // Initialize MongoDB and GridFS connections
  static Future<void> initialize() async {
    if (_isInitialized) {
      print("MongoDB Service already initialized");
      return;
    }

    try {
      final connected = await connect();
      if (!connected) {
        throw Exception("Failed to connect to MongoDB");
      }

      _isInitialized = true;
      print("MongoDB Service initialized successfully");
    } catch (e) {
      print("Error initializing MongoDB service: $e");
      throw Exception("Failed to initialize MongoDB: $e");
    }
  }

  // Standardized method to convert any id format to ObjectId if possible
  static dynamic _getObjectId(String id) {
    // Clean the id string if it contains ObjectId wrapper
    String cleanId = id;
    if (cleanId.contains('ObjectId(') && cleanId.endsWith(')')) {
      cleanId = cleanId.replaceAll('ObjectId("', '').replaceAll('")', '');
    }

    try {
      return mongo.ObjectId.fromHexString(cleanId);
    } catch (e) {
      print("Warning: Couldn't convert to ObjectId: $e");
      return id; // Return the original id if conversion fails
    }
  }

  // Get all events
  static Future<List<Event>> getAllEvents() async {
    try {
      if (_db == null || !_db!.isConnected) {
        final connected = await connect();
        if (!connected) {
          print("Failed to connect to MongoDB");
          return [];
        }
      }

      final collection = _db!.collection('events');
      final events = await collection.find().toList();

      return events.map((event) => Event.fromMap(event)).toList();
    } catch (e) {
      print("Error fetching events: $e");
      return [];
    }
  }

  // Get events by category
  static Future<List<Event>> getEventsByCategory(String category) async {
    try {
      if (_db == null || !_db!.isConnected) {
        final connected = await connect();
        if (!connected) {
          print("Failed to connect to MongoDB");
          return [];
        }
      }

      final collection = _db!.collection('events');
      final events =
          await collection.find(mongo.where.eq('category', category)).toList();

      return events.map((event) => Event.fromMap(event)).toList();
    } catch (e) {
      print("Error fetching events by category: $e");
      return [];
    }
  }

  // Find a specific event by ID
  static Future<Event?> findEventById(String eventId) async {
    try {
      if (_db == null || !_db!.isConnected) {
        final connected = await connect();
        if (!connected) {
          print("Failed to connect to MongoDB");
          return null;
        }
      }

      final collection = _db!.collection('events');
      print("Looking for event with ID: $eventId");

      // Try to convert to ObjectId
      final id = _getObjectId(eventId);

      // Create the selector based on the ID type
      final selector =
          id is mongo.ObjectId ? mongo.where.id(id) : mongo.where.eq('_id', id);
      final eventDoc = await collection.findOne(selector);

      if (eventDoc == null) {
        print("Event not found with ID: $eventId");
        return null;
      }

      print("Found event: ${eventDoc['name']}");
      return Event.fromMap(eventDoc);
    } catch (e) {
      print("Error finding event by ID: $e");
      throw Exception("Failed to fetch event details: $e");
    }
  }

  static Future<List<Attendee>> getAttendeeFromEvent(String eventId) async {
    try {
      if (_db == null || !_db!.isConnected) {
        final connected = await connect();
        if (!connected) {
          print("Failed to connect to MongoDB");
          return [];
        }
      }

      final collection = _db!.collection('events');
      final id = _getObjectId(eventId);
      final selector = id is ObjectId ? where.id(id) : where.eq('_id', id);
      final event = await collection.findOne(selector);
      print("event: $event");
      if (event == null) {
        print("Event not found with ID: $eventId");
        return [];
      }

      final attendees = event['attendees'] as List;
      return attendees.map<Attendee>((attendee) => Attendee.fromMap(attendee as Map<String, dynamic>)).toList();
    } catch (e) {
      print("Error getting attendee from event: $e");
      return [];
    }
  }

  // Add attendee to an event - improved implementation
  // Add attendee to an event
  static Future<bool> addAttendeeToEvent(
    String eventId,
    Attendee attendee,
  ) async {
    try {
      if (_db == null || !_db!.isConnected) {
        final connected = await connect();
        if (!connected) {
          print("Failed to connect to MongoDB");
          return false;
        }
      }

      final collection = _db!.collection('events');
      final id = _getObjectId(eventId);
      print("Adding attendee to event with ID: $id (original: $eventId)");

      // Create the selector based on the ID type
      final selector =
          id is mongo.ObjectId ? mongo.where.id(id) : mongo.where.eq('_id', id);

      // First check if the event exists
      final event = await collection.findOne(selector);
      if (event == null) {
        print("Event not found with ID: $eventId");
        return false;
      }

      // Check if the attendee already exists
      if (event['attendees'] != null) {
        bool attendeeExists = (event['attendees'] as List).any(
          (a) => a['email'] == attendee.email,
        );
        if (attendeeExists) {
          print("Attendee ${attendee.email} already exists for this event");
          return false;
        }
      }

      // Add the attendee
      final updateResult = await collection.update(selector, {
        '\$push': {'attendees': attendee.toMap()},
      });

      print("Update result: $updateResult");
      return updateResult != null &&
          (updateResult['ok'] == 1 ||
              (updateResult['nModified'] != null &&
                  updateResult['nModified'] > 0));
    } catch (e) {
      print("Error adding attendee: $e");
      return false;
    }
  }

  // Check if user is attending an event
  static Future<bool> isUserAttending(String eventId, String email) async {
    try {
      if (_db == null || !_db!.isConnected) {
        final connected = await connect();
        if (!connected) {
          print("Failed to connect to MongoDB");
          return false;
        }
      }

      final collection = _db!.collection('events');
      final id = _getObjectId(eventId);
      print(
        "Checking attendance for user $email in event $id (original: $eventId)",
      );

      // Create the selector based on the ID type
      final selector =
          id is mongo.ObjectId ? mongo.where.id(id) : mongo.where.eq('_id', id);

      final event = await collection.findOne(selector);
      if (event == null) {
        print("Event not found with ID: $eventId");
        return false;
      }

      // Check if attendee exists in the list
      if (event['attendees'] != null) {
        bool attendeeExists = (event['attendees'] as List).any(
          (a) => a['email'] == email,
        );
        print(
          "User $email is ${attendeeExists ? '' : 'not '}attending event $eventId",
        );
        return attendeeExists;
      }

      return false;
    } catch (e) {
      print("Error checking if user is attending: $e");
      return false;
    }
  }

  // Get user role for event
  static Future<String?> getUserRole(String eventId, String email) async {
    try {
      if (_db == null || !_db!.isConnected) {
        final connected = await connect();
        if (!connected) {
          print("Failed to connect to MongoDB");
          return null;
        }
      }

      final collection = _db!.collection('events');
      final id = _getObjectId(eventId);

      // Create the selector based on the ID type
      final selector =
          id is mongo.ObjectId ? mongo.where.id(id) : mongo.where.eq('_id', id);

      final event = await collection.findOne(selector);
      if (event == null) {
        return null;
      }

      // Check if user is host
      if (event['hostEmail'] == email) {
        return 'host';
      }

      // Check if user is in attendees
      if (event['attendees'] != null) {
        for (final attendee in event['attendees']) {
          if (attendee['email'] == email) {
            return attendee['role'];
          }
        }
      }

      return null;
    } catch (e) {
      print("Error getting user role: $e");
      return null;
    }
  }

  // Get events for a specific user
  static Future<List<Event>> getEventsForUser(String userEmail) async {
    try {
      if (_db == null || !_db!.isConnected) {
        final connected = await connect();
        if (!connected) {
          print("Failed to connect to MongoDB");
          return [];
        }
      }

      final collection = _db!.collection('events');
      print("Finding events for user: $userEmail");

      // Use a more compatible approach with mongo_dart
      // Find events where attendees array contains an object with matching email
      final events =
          await collection.find({
            'attendees': {
              '\$elemMatch': {'email': userEmail},
            },
          }).toList();

      print(
        "Found ${events.length} events where user $userEmail is an attendee",
      );

      return events.map((event) => Event.fromMap(event)).toList();
    } catch (e) {
      print("Error fetching events for user: $e");
      return [];
    }
  }

  // Create a new event
  static Future<bool> createEvent(
    Map<String, dynamic> eventData,
    String userEmail,
    File? bannerImage,
  ) async {
    try {
      if (_db == null || !_db!.isConnected) {
        final connected = await connect();
        if (!connected) {
          print("Failed to connect to MongoDB");
          return false;
        }
      }

      final eventsCollection = _db!.collection('events');

      // Upload image if available and get ID
      String? imageId;
      if (bannerImage != null) {
        imageId = await gridFSService.uploadImage(bannerImage);
      }

      // Create attendee for the host
      final hostAttendee = {
        'email': userEmail,
        'role': 'host',
        'joinedAt': DateTime.now().toIso8601String(),
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
        'hostEmail': userEmail,
        'attendees': [hostAttendee],
      };

      final result = await eventsCollection.insertOne(eventDoc);
      return result.isSuccess;
    } catch (e) {
      print("Error creating event: $e");
      return false;
    }
  }

  // Close MongoDB connection
  static Future<void> close() async {
    try {
      if (_db != null && _db!.isConnected) {
        await _db!.close();
        _isInitialized = false;
        print("Closed MongoDB connection");
      }
    } catch (e) {
      print("Error closing MongoDB connection: $e");
    }
  }
}

// GridFS Service Class - handles image storage in MongoDB
class GridFSService {
  mongo.Db? _db;
  mongo.GridFS? _gridFS;
  final Uuid _uuid = Uuid();
  bool _isInitialized = false;

  // Check if GridFS is initialized
  bool get isInitialized => _isInitialized;

  // Initialize GridFS connection using existing DB connection
  Future<void> initialize(mongo.Db db) async {
    if (_isInitialized) {
      print("GridFS already initialized");
      return;
    }

    _db = db;
    if (_db != null && _db!.isConnected) {
      try {
        _gridFS = mongo.GridFS(_db!, 'eventImages');
        _isInitialized = true;
        print("GridFS initialized successfully");
      } catch (e) {
        print("Error initializing GridFS: $e");
        _isInitialized = false;
        throw Exception("Failed to initialize GridFS: $e");
      }
    } else {
      print("Cannot initialize GridFS: Database not connected");
      throw Exception("Failed to initialize GridFS: Database not connected");
    }
  }

  // Upload an image file to GridFS and return its ID
  Future<String> uploadImage(File imageFile) async {
    try {
      if (!_isInitialized) {
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

      print(
        "Successfully uploaded image to GridFS with ID: ${id.toHexString()}",
      );
      return id.toHexString();
    } catch (e) {
      print("Error uploading image to GridFS: $e");
      rethrow;
    }
  }

  // Get an image by its ID
  Future<Uint8List?> getImageBytes(String id) async {
    try {
      if (!_isInitialized) {
        print("GridFS not initialized for image ID: $id");

        // Try to re-initialize if we have a DB connection
        if (_db != null && _db!.isConnected) {
          try {
            await initialize(_db!);
            print("Re-initialized GridFS for image retrieval");
          } catch (e) {
            print("Failed to re-initialize GridFS: $e");
            return null;
          }
        } else {
          return null;
        }
      }

      print("Attempting to retrieve image with ID: $id");

      final objectId = mongo.ObjectId.fromHexString(id);

      // Get the files collection
      final filesCollection = _db!.collection('eventImages.files');
      final file = await filesCollection.findOne(mongo.where.id(objectId));

      if (file == null) {
        print("File not found with ID: $id");
        return null;
      }

      // Get the chunks collection
      final chunksCollection = _db!.collection('eventImages.chunks');

      // Query for all chunks belonging to this file
      final chunks =
          await chunksCollection
              .find(mongo.where.eq('files_id', objectId))
              .toList();

      if (chunks.isEmpty) {
        print("No chunks found for file ID: $id");
        return null;
      }

      print("Found ${chunks.length} chunks for image ID: $id");

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

      print(
        "Successfully retrieved image with ID: $id, size: ${allBytes.length} bytes",
      );
      return Uint8List.fromList(allBytes);
    } catch (e) {
      print("Error retrieving image from GridFS: $e");
      return null;
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

// GridFS Image Widget - reusable component for displaying images
class GridFSImage extends StatelessWidget {
  final String imageId;
  final BoxFit fit;
  final double? width;
  final double? height;

  const GridFSImage({
    Key? key,
    required this.imageId,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _getImageData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          print("Error loading image: ${snapshot.error}");
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.error_outline, size: 40, color: Colors.red),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data == null) {
          print("No image data found for ID: $imageId");
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                size: 40,
                color: Colors.grey,
              ),
            ),
          );
        } else {
          print(
            "Rendering image with ID: $imageId, size: ${snapshot.data!.length} bytes",
          );
          return Image.memory(
            snapshot.data!,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) {
              print("Error rendering image: $error");
              return Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.broken_image, size: 40, color: Colors.red),
                ),
              );
            },
          );
        }
      },
    );
  }

  // Separate method to get image data with retry logic
  Future<Uint8List?> _getImageData() async {
    // First try
    var imageData = await MongoDBService.gridFSService.getImageBytes(imageId);

    // If failed, ensure MongoDB service is initialized and retry
    if (imageData == null) {
      print("First attempt to get image failed, reinitializing MongoDB...");
      try {
        await MongoDBService.initialize();
        // Wait a moment for initialization to complete
        await Future.delayed(const Duration(milliseconds: 500));
        imageData = await MongoDBService.gridFSService.getImageBytes(imageId);
      } catch (e) {
        print("Error during MongoDB reinitialization: $e");
      }
    }

    return imageData;
  }
}
