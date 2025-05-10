import 'dart:async';
import 'dart:ui';
import 'package:another_telephony/telephony.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_sms/firebase_options.dart';
import 'package:share_sms/models/shared_sms_model.dart';
import 'package:share_sms/models/sms_model.dart';
import 'package:share_sms/services/database_service.dart';
import 'package:uuid/uuid.dart';

class BackgroundService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // Initialize the background service and notifications
  static Future<void> initialize() async {
    try {
      // Initialize notifications
      await _initializeNotifications();
      
      // Configure the background service
      final service = FlutterBackgroundService();
      
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'share_sms_channel',
          initialNotificationTitle: 'Share SMS Service',
          initialNotificationContent: 'Monitoring for messages',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
      
      print("Background service initialized successfully");
    } catch (e) {
      print("Error initializing background service: $e");
    }
  }

  // Initialize notification channels and settings
  static Future<void> _initializeNotifications() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'share_sms_channel',
        'Share SMS Service',
        description: 'Background service for processing SMS messages',
        importance: Importance.high,
      );
      
      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
          
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
      }
      
      // Initialize notifications
      await _notificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
    } catch (e) {
      print("Error initializing notifications: $e");
    }
  }

  // Start the background service
  static Future<void> registerPeriodicTask() async {
    try {
      final service = FlutterBackgroundService();
      
      // Store the database URL in shared preferences for background use
      final prefs = await SharedPreferences.getInstance();
      final dbUrl = FirebaseDatabase.instance.databaseURL;
      if (dbUrl != null) {
        await prefs.setString('firebase_db_url', dbUrl);
      }
      
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
      
      if (isRunning) {
        await service.invoke('stopService');
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
        if (event != null && event.containsKey('title') && event.containsKey('content')) {
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
    
    // Set up background SMS listener
    _setupSmsListener(service);
    
    // Also set up periodic checking (as a backup)
    Timer.periodic(const Duration(minutes: 15), (_) async {
      try {
        await _processMessagesOnce(service);
      } catch (e) {
        print("Error in periodic messages check: $e");
        service.invoke('updateNotification', {
          'title': 'Share SMS Service',
          'content': 'Error checking messages: ${e.toString().substring(0, min(50, e.toString().length))}',
        });
      }
    });
    
    print("Background service started successfully");
  } catch (e) {
    print("Error in background service: $e");
    service.invoke('updateNotification', {
      'title': 'Share SMS Service Error',
      'content': 'Service error: ${e.toString().substring(0, min(50, e.toString().length))}',
    });
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
    final permissionStatus = await telephony.requestPhoneAndSmsPermissions();
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
        filter: const SmsFilter.where(
          SmsColumn.READ,
        ).equals(0), // Only unread messages
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
      'content': 'Error: ${e.toString().substring(0, min(50, e.toString().length))}',
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
            
            // Show notification
            await _showMessageNotification(message);
            
            // Update service notification
            service.invoke('updateNotification', {
              'title': 'Share SMS Service',
              'content': 'New message from ${message.address ?? "Unknown"}',
            });
            
            print("Processed new SMS from ${message.address}");
          } else {
            print("Can't process SMS: userId=$currentUserId, message.body=${message.body != null}");
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

// Process a single SMS message
Future<void> _processSingleSms(
  DatabaseService databaseService,
  String userId,
  SmsMessage sms,
) async {
  try {
    // Convert to SmsModel
    final smsModel = SmsModel(
      id: sms.id?.toString(),
      address: sms.address,
      body: sms.body,
      date: sms.date != null 
          ? DateTime.fromMillisecondsSinceEpoch(sms.date!)
          : DateTime.now(),
    );
    
    // Get keyword rules
    final rulesSnapshot = await databaseService.getUserKeywordRules(userId).first;
    final activeRules = rulesSnapshot.where((rule) => rule.isActive).toList();
    
    if (activeRules.isEmpty) {
      print("No active keyword rules found for user $userId");
      return;
    }
    
    // Get user details for username
    final currentUser = await databaseService.getUserDetails(userId);
    
    // Check each rule for keyword matches
    for (final rule in activeRules) {
      final matchedKeyword = _findMatchingKeyword(
        smsModel.body!,
        rule.keywords,
      );

      if (matchedKeyword != null) {
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
        await databaseService.shareMessage(sharedMessage);
        
        print("Message shared with user ${rule.receiverId}, keyword: $matchedKeyword");
      }
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
    if (lowercaseKeyword.isNotEmpty && lowercaseBody.contains(lowercaseKeyword)) {
      return keyword;
    }
  }
  
  return null;
}

// Show a notification for a new message
Future<void> _showMessageNotification(SmsMessage message) async {
  try {
    await FlutterLocalNotificationsPlugin().show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000), // Unique ID based on time
      'New Message from ${message.address ?? "Unknown"}',
      message.body ?? 'New message received',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'share_sms_messages_channel',
          'SMS Messages',
          channelDescription: 'Notifications about new SMS messages',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  } catch (e) {
    print('Error showing notification: $e');
  }
}

// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
