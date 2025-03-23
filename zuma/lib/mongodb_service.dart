import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    if (map['_id'] is ObjectId) {
      idString = (map['_id'] as ObjectId).toHexString();
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
      'createdAt': createdAt.toIso8601String(),
      'attendees': attendees.map((attendee) => attendee.toMap()).toList(),
      'hostEmail': hostEmail,
    };
  }
}

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

// MongoDB Service class
class MongoDBService {
  static Db? _db;

  // Connect to MongoDB
  static Future<bool> connect() async {
    try {
      // Use your actual connection string here
      final mongoUri = dotenv.env['MONGODB_URI'] ?? '';
      if (mongoUri.isEmpty) {
        print("MongoDB URI is empty. Please check your .env file.");
        return false;
      }

      print("Attempting to connect to MongoDB...");

      _db = await Db.create(mongoUri);
      await _db!.open();

      print("Connected to MongoDB successfully!");
      return true;
    } catch (e) {
      print("Error connecting to MongoDB: $e");
      return false;
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
      return ObjectId.fromHexString(cleanId);
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
          await collection.find(where.eq('category', category)).toList();

      return events.map((event) => Event.fromMap(event)).toList();
    } catch (e) {
      print("Error fetching events by category: $e");
      return [];
    }
  }

  // Find a specific event by ID - improved implementation
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
      final selector = id is ObjectId ? where.id(id) : where.eq('_id', id);
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
      final selector = id is ObjectId ? where.id(id) : where.eq('_id', id);

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

  // Check if user is attending an event - improved implementation
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
      final selector = id is ObjectId ? where.id(id) : where.eq('_id', id);

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

  // Get user role for event - improved implementation
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
      final selector = id is ObjectId ? where.id(id) : where.eq('_id', id);

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

  // Close MongoDB connection
  static Future<void> close() async {
    try {
      if (_db != null && _db!.isConnected) {
        await _db!.close();
        print("Closed MongoDB connection");
      }
    } catch (e) {
      print("Error closing MongoDB connection: $e");
    }
  }

  // Fixed version of getEventsForUser method
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
}
