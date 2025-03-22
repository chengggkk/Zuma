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

    return Event(
      id: map['_id'].toString(),
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

  Attendee({required this.email, required this.role, required this.joinedAt});

  factory Attendee.fromMap(Map<String, dynamic> map) {
    return Attendee(
      email: map['email'] ?? '',
      role: map['role'] ?? 'attendee',
      joinedAt:
          map['joinedAt'] != null
              ? DateTime.parse(map['joinedAt'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
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

      // Clean the eventId string if it contains ObjectId wrapper
      String cleanId = eventId;
      if (cleanId.contains('ObjectId(') && cleanId.endsWith(')')) {
        cleanId = cleanId.replaceAll('ObjectId("', '').replaceAll('")', '');
      }

      print("Attempting to find event with cleaned ID: $cleanId");

      // Try different approaches to find the document
      Map<String, dynamic>? eventDoc;

      // Approach 1: Try with ObjectId
      try {
        ObjectId objectId = ObjectId.fromHexString(cleanId);
        eventDoc = await collection.findOne(where.id(objectId));
        print("Tried finding with ObjectId: ${objectId.toHexString()}");
      } catch (e) {
        print("Couldn't convert to ObjectId, trying string match: $e");
      }

      // Approach 2: If ObjectId failed or returned no results, try with string _id
      if (eventDoc == null) {
        print("Trying to find event with string _id");
        eventDoc = await collection.findOne(where.eq('_id', cleanId));
      }

      // Approach 3: Try with the original ID as is
      if (eventDoc == null) {
        print("Trying to find event with original ID");
        eventDoc = await collection.findOne(where.eq('_id', eventId));
      }

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

      // Clean the eventId string if needed
      String cleanId = eventId;
      if (cleanId.contains('ObjectId(') && cleanId.endsWith(')')) {
        cleanId = cleanId.replaceAll('ObjectId("', '').replaceAll('")', '');
      }

      ObjectId? objectId;
      try {
        objectId = ObjectId.fromHexString(cleanId);
      } catch (e) {
        print("Couldn't convert to ObjectId, will try string match");
      }

      // First check if the attendee is already in the event
      final selector =
          objectId != null ? where.id(objectId) : where.eq('_id', cleanId);

      // Add the "attendees.email" equals check to the selector
      final query = selector.and(where.eq('attendees.email', attendee.email));

      final existingAttendee = await collection.findOne(query);

      if (existingAttendee != null) {
        print("Attendee already exists for this event");
        return false;
      }

      // Update the document to add the new attendee
      final updateResult = await collection.update(
        objectId != null ? where.id(objectId) : where.eq('_id', cleanId),
        {
          '\$push': {'attendees': attendee.toMap()},
        },
      );

      print("Update result: $updateResult");
      return updateResult['nModified'] > 0;
    } catch (e) {
      print("Error adding attendee: $e");
      return false;
    }
  }

  // Check if user is already attending
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

      // Clean the eventId string if needed
      String cleanId = eventId;
      if (cleanId.contains('ObjectId(') && cleanId.endsWith(')')) {
        cleanId = cleanId.replaceAll('ObjectId("', '').replaceAll('")', '');
      }

      ObjectId? objectId;
      try {
        objectId = ObjectId.fromHexString(cleanId);
      } catch (e) {
        print("Couldn't convert to ObjectId, will try string match");
      }

      final selector =
          objectId != null ? where.id(objectId) : where.eq('_id', cleanId);

      // Add the "attendees.email" equals check to the selector
      final query = selector.and(where.eq('attendees.email', email));

      final event = await collection.findOne(query);

      return event != null;
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

      // Clean the eventId string if needed
      String cleanId = eventId;
      if (cleanId.contains('ObjectId(') && cleanId.endsWith(')')) {
        cleanId = cleanId.replaceAll('ObjectId("', '').replaceAll('")', '');
      }

      ObjectId? objectId;
      try {
        objectId = ObjectId.fromHexString(cleanId);
      } catch (e) {
        print("Couldn't convert to ObjectId, will try string match");
      }

      final selector =
          objectId != null ? where.id(objectId) : where.eq('_id', cleanId);

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
}
