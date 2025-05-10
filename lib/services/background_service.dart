import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_sms/firebase_options.dart';
import 'package:share_sms/models/shared_sms_model.dart';
import 'package:share_sms/models/sms_model.dart';
import 'package:share_sms/services/database_service.dart';
import 'package:uuid/uuid.dart';

// Import conditionally for Android-only packages
import 'package:another_telephony/telephony.dart' if (dart.library.html) 'package:share_sms/services/web_stubs.dart';

class BackgroundService {
  // Initialize the background service
  static Future<void> initialize() async {
    // Skip on web platform
    if (kIsWeb) {
      print("Background service not supported on web");
      return;
    }
    
    try {
      // Configure the background service
      final service = FlutterBackgroundService();
      
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: true, // Enable auto-start
          isForegroundMode: true,
          notificationChannelId: 'share_sms_channel',
          initialNotificationTitle: 'Share SMS Service',
          initialNotificationContent: 'Monitoring for messages',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true, // Enable auto-start
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
      
      print("Background service initialized successfully");
      
      // Load previous settings and auto-start if enabled
      final prefs = await SharedPreferences.getInstance();
      final shouldAutoStart = prefs.getBool('auto_start_service') ?? true;
      
      if (shouldAutoStart) {
        registerPeriodicTask();
      }
    } catch (e) {
      print("Error initializing background service: $e");
    }
  }

  // Start the background service
  static Future<void> registerPeriodicTask() async {
    // Skip on web platform
    if (kIsWeb) {
      print("Background service not supported on web");
      return;
    }
    
    try {
      final service = FlutterBackgroundService();
      
      // Store the database URL in shared preferences for background use
      final prefs = await SharedPreferences.getInstance();
      final dbUrl = FirebaseDatabase.instance.databaseURL;
      if (dbUrl != null) {
        await prefs.setString('firebase_db_url', dbUrl);
      }
      
      // Save setting for auto-start
      await prefs.setBool('auto_start_service', true);
      
      // Start the service
      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
        print("Background service started");
      } else {
        print("Background service is already running");
      }
    } catch (e) {
      print("Error starting background service: $e");
    }
  }
  
  // Stop the background service
  static Future<void> stopService() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      
      // Store preference to not auto-start
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_start_service', false);
      
      if (isRunning) {
        service.invoke('stopService');
        print("Background service stopped");
      } else {
        print("Background service is not running");
      }
    } catch (e) {
      print("Error stopping background service: $e");
    }
  }
  
  // Check if the service is running
  static Future<bool> isServiceRunning() async {
    try {
      final service = FlutterBackgroundService();
      return await service.isRunning();
    } catch (e) {
      print("Error checking if service is running: $e");
      return false;
    }
  }
}

// Background service entry point - runs in a separate isolate
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  try {
    // Background processing for Android
    if (service is AndroidServiceInstance) {
      service.on('stopService').listen((event) {
        service.stopSelf();
      });
      
      // Set up notification update listener
      service.on('updateNotification').listen((event) {
        if (event != null &&
            event.containsKey('title') &&
            event.containsKey('content')) {
          service.setForegroundNotificationInfo(
            title: event['title'],
            content: event['content'],
          );
        }
      });
      
      // Make the service foreground
      service.setAsForegroundService();
    }

    // Set up Firebase in the background isolate
    await _initializeFirebase();
    
    // Set initial notification
    service.invoke('updateNotification', {
      'title': 'Share SMS Service',
      'content': 'Service started, monitoring for messages',
    });
    
    // Process initial messages on startup
    await _processMessagesOnce(service);
    
    // Set up background SMS listener with error handling and retries
    _setupSmsListenerWithRetry(service);
    
    // More frequent checking for better reliability (every 5 minutes)
    Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        await _processMessagesOnce(service);
      } catch (e) {
        print("Error in periodic messages check: $e");
        // Still update notification but don't crash the service
        try {
          service.invoke('updateNotification', {
            'title': 'Share SMS Service',
            'content': 'Error checking messages. Will retry...',
          });
        } catch (_) {} // Ignore errors in notification update
      }
    });
    
    print("Background service started successfully");
  } catch (e) {
    print("Error in background service: $e");
    // Try to recover by restarting the service components
    try {
      _setupSmsListenerWithRetry(service);
    } catch (_) {}
  }
}

// Calculate the minimum of two numbers (helper function)
int min(int a, int b) => a < b ? a : b;

// Initialize Firebase in the background
Future<void> _initializeFirebase() async {
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isNotEmpty) {
      print("Firebase already initialized");
      return;
    }

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Get database URL from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final dbUrl = prefs.getString('firebase_db_url');

    if (dbUrl != null && dbUrl.isNotEmpty) {
      FirebaseDatabase.instance.databaseURL = dbUrl;
      print("Firebase initialized with URL: $dbUrl");
    } else {
      print("Firebase database URL not found in shared preferences");
    }
  } catch (e) {
    print('Error initializing Firebase in background: $e');
    throw Exception('Failed to initialize Firebase: $e');
  }
}

// Process SMS messages from the database
Future<void> _processMessagesOnce(ServiceInstance service) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('current_user_id');

    if (currentUserId == null) {
      service.invoke('updateNotification', {
        'title': 'Share SMS Service',
        'content': 'No user logged in',
      });
      return;
    }

    // Create database service
    final dbRef = FirebaseDatabase.instance.ref();
    final databaseService = DatabaseService(dbRef);

    // Get the Telephony instance
    final telephony = Telephony.instance;

    // Check SMS permission
    final permissionStatus = await telephony.requestPhoneAndSmsPermissions;
    if (permissionStatus ?? false) {
      // Get recent SMS messages
      final messages = await telephony.getInboxSms(
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.ID,
        ],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      if (messages.isNotEmpty) {
        int processedCount = 0;

        // Process each SMS
        for (final sms in messages) {
          if (sms.body != null && sms.body!.isNotEmpty) {
            await _processSingleSms(databaseService, currentUserId, sms);
            processedCount++;
          }
        }

        // Update notification
        service.invoke('updateNotification', {
          'title': 'Share SMS Service',
          'content': 'Processed $processedCount new messages',
        });

        print("Processed $processedCount SMS messages");
      } else {
        // No new messages
        service.invoke('updateNotification', {
          'title': 'Share SMS Service',
          'content': 'No new messages found',
        });
      }
    } else {
      // Permission not granted
      service.invoke('updateNotification', {
        'title': 'Share SMS Service',
        'content': 'SMS permission not granted',
      });

      print("SMS permission not granted");
    }
  } catch (e) {
    print("Error processing messages: $e");
    // Error occurred
    service.invoke('updateNotification', {
      'title': 'Share SMS Service',
      'content':
          'Error: ${e.toString().substring(0, min(50, e.toString().length))}',
    });

    throw Exception('Failed to process messages: $e');
  }
}

// Set up SMS listener
void _setupSmsListener(ServiceInstance service) {
  try {
    // Get the Telephony instance
    final telephony = Telephony.instance;
    
    // Listen for new SMS
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final currentUserId = prefs.getString('current_user_id');
          
          if (currentUserId != null && message.body != null) {
            // Create database service
            final dbRef = FirebaseDatabase.instance.ref();
            final databaseService = DatabaseService(dbRef);
            
            // Process the SMS
            await _processSingleSms(databaseService, currentUserId, message);
            
            // Update service notification instead of showing separate notification
            service.invoke('updateNotification', {
              'title': 'Share SMS Service',
              'content': 'New message from ${message.address ?? "Unknown"}',
            });
            
            print("Processed new SMS from ${message.address}");
          } else {
            print(
              "Can't process SMS: userId=$currentUserId, message.body=${message.body != null}",
            );
          }
        } catch (e) {
          print('Error processing incoming SMS: $e');
        }
      },
      listenInBackground: true,
    );
    
    print("SMS listener set up successfully");
  } catch (e) {
    print("Error setting up SMS listener: $e");
  }
}

// Set up SMS listener with retry mechanism for better reliability
void _setupSmsListenerWithRetry(ServiceInstance service, {int retryCount = 0}) {
  try {
    _setupSmsListener(service);
  } catch (e) {
    print("Error setting up SMS listener (attempt $retryCount): $e");
    
    // Retry up to 3 times with increasing delay
    if (retryCount < 3) {
      Future.delayed(Duration(seconds: (retryCount + 1) * 5), () {
        _setupSmsListenerWithRetry(service, retryCount: retryCount + 1);
      });
    }
  }
}

// Process a single SMS message
Future<void> _processSingleSms(
  DatabaseService databaseService,
  String userId,
  SmsMessage sms,
) async {
  try {
    // Skip if no message ID
    if (sms.id == null) {
      print("Skipping SMS with no ID");
      return;
    }
    
    // Check if this message has already been processed
    final prefs = await SharedPreferences.getInstance();
    final processedIds = prefs.getStringList('processed_message_ids_$userId') ?? [];
    
    if (processedIds.contains(sms.id.toString())) {
      print("Skipping already processed message in background: ${sms.id}");
      return;
    }
    
    // Get the timestamp of the last processed message
    final lastProcessedTimestamp = prefs.getInt('last_processed_time_$userId');
    
    // Skip if this message is older than the last processed time
    if (lastProcessedTimestamp != null && sms.date != null && 
        sms.date! <= lastProcessedTimestamp) {
      print("Skipping older message in background: ${sms.id}");
      return;
    }
    
    // Convert to SmsModel
    final smsModel = SmsModel(
      id: sms.id?.toString(),
      address: sms.address,
      body: sms.body,
      date:
          sms.date != null
              ? DateTime.fromMillisecondsSinceEpoch(sms.date!)
              : DateTime.now(),
    );

    // Get keyword rules
    final rulesSnapshot =
        await databaseService.getUserKeywordRules(userId).first;
    final activeRules = rulesSnapshot.where((rule) => rule.isActive).toList();

    if (activeRules.isEmpty) {
      print("No active keyword rules found for user $userId");
      return;
    }

    // Get user details for username
    final currentUser = await databaseService.getUserDetails(userId);
    print("Checking SMS from ${sms.address} against ${activeRules.length} rules");

    // Check each rule for keyword matches
    int matchCount = 0;
    for (var rule in activeRules) {
      final matchedKeyword = _findMatchingKeyword(
        smsModel.body!,
        rule.keywords,
      );

      if (matchedKeyword != null) {
        matchCount++;
        print("Keyword match found: $matchedKeyword");

        // Create shared message
        final uuid = const Uuid().v4();
        final sharedMessage = SharedSmsModel(
          id: uuid,
          senderId: userId,
          receiverId: rule.receiverId,
          senderUserName: currentUser?.username,
          address: smsModel.address,
          body: smsModel.body,
          originalDate: smsModel.date,
          keywordMatched: matchedKeyword,
        );

        // Use the proper API to share the message
        try {
          await databaseService.shareMessage(sharedMessage);
          print("Message shared with user ${rule.receiverId}, keyword: $matchedKeyword");
        } catch (e) {
          print("Error sharing message: $e");
        }
      }
    }
    
    if (matchCount == 0) {
      print("No keyword matches found for message from ${sms.address}");
    }
    
    // Mark message as processed and update last processed time
    processedIds.add(sms.id.toString());
    if (processedIds.length > 1000) {
      processedIds.removeAt(0); // Keep the list manageable
    }
    await prefs.setStringList('processed_message_ids_$userId', processedIds);
    
    if (sms.date != null) {
      await prefs.setInt('last_processed_time_$userId', sms.date!);
    }
  } catch (e) {
    print("Error processing single SMS: $e");
    throw Exception('Failed to process SMS: $e');
  }
}

// Find matching keyword in an SMS body
String? _findMatchingKeyword(String smsBody, List<String> keywords) {
  if (smsBody.isEmpty || keywords.isEmpty) return null;

  final lowercaseBody = smsBody.toLowerCase();

  for (String keyword in keywords) {
    final lowercaseKeyword = keyword.toLowerCase().trim();
    if (lowercaseKeyword.isNotEmpty &&
        lowercaseBody.contains(lowercaseKeyword)) {
      return keyword;
    }
  }

  return null;
}

// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
