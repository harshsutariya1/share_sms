import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:another_telephony/telephony.dart';
import 'package:share_sms/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_sms/models/shared_sms_model.dart';
import 'package:share_sms/models/sms_model.dart';
import 'package:share_sms/services/database_service.dart';
import 'package:uuid/uuid.dart';

class SmsService {
  final Telephony _telephony = Telephony.instance;
  final DatabaseService _databaseService;
  final String _currentUserId;
  final Uuid _uuid = Uuid();
  
  StreamController<SmsModel>? _incomingSmsController;
  bool _isListening = false;
  
  // Keep track of processed messages to avoid duplicates
  Set<String> _processedMessageIds = {};

  SmsService(this._databaseService, this._currentUserId) {
    // Initialize by loading the last processed time
    _loadLastProcessedTime();
  }

  // Save the timestamp of the most recent message processed
  Future<void> _saveLastProcessedTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_processed_time_$_currentUserId', time.millisecondsSinceEpoch);
      print("Saved last processed time: $time");
    } catch (e) {
      print("Error saving last processed time: $e");
    }
  }

  // Load the timestamp of the last message processing
  Future<DateTime> _loadLastProcessedTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('last_processed_time_$_currentUserId');
      
      if (timestamp != null) {
        final lastTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        print("Loaded last processed time: $lastTime");
        return lastTime;
      }
    } catch (e) {
      print("Error loading last processed time: $e");
    }
    
    // If no timestamp is found, default to 24 hours ago
    final defaultTime = DateTime.now().subtract(const Duration(hours: 24));
    print("Using default last processed time: $defaultTime");
    return defaultTime;
  }

  // Check if a message has already been processed
  Future<bool> _isMessageAlreadyProcessed(String messageId) async {
    // First check in memory
    if (_processedMessageIds.contains(messageId)) {
      return true;
    }
    
    try {
      // Then check in persistent storage
      final prefs = await SharedPreferences.getInstance();
      final processedIds = prefs.getStringList('processed_message_ids_$_currentUserId') ?? [];
      return processedIds.contains(messageId);
    } catch (e) {
      print("Error checking if message was processed: $e");
      return false;
    }
  }

  // Mark a message as processed
  Future<void> _markMessageAsProcessed(String messageId) async {
    // Add to in-memory set
    _processedMessageIds.add(messageId);
    
    try {
      // Add to persistent storage
      final prefs = await SharedPreferences.getInstance();
      final processedIds = prefs.getStringList('processed_message_ids_$_currentUserId') ?? [];
      
      // Add this ID if not already in the list
      if (!processedIds.contains(messageId)) {
        // Keep the list size manageable - only store last 1000 IDs
        if (processedIds.length >= 1000) {
          processedIds.removeAt(0); // Remove oldest ID
        }
        
        processedIds.add(messageId);
        await prefs.setStringList('processed_message_ids_$_currentUserId', processedIds);
      }
    } catch (e) {
      print("Error marking message as processed: $e");
    }
  }

  Future<PermissionStatus> checkSmsPermission() async {
    return await Permission.sms.status;
  }

  Future<PermissionStatus> requestSmsPermission() async {
    return await Permission.sms.request();
  }

  Future<List<SmsModel>> getSmsMessages({bool forceRequestPermission = false}) async {
    PermissionStatus status = await checkSmsPermission();
    
    if (status.isDenied && forceRequestPermission) {
        status = await requestSmsPermission();
    }

    if (!status.isGranted) {
      throw Exception("SMS permission not granted.");
    }

    final lastProcessedTime = await _loadLastProcessedTime();
    DateTime mostRecentMessageTime = lastProcessedTime;

    List<SmsMessage> messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE, SmsColumn.ID],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    final smsList = messages.map((sms) {
      final messageTime = sms.date != null 
          ? DateTime.fromMillisecondsSinceEpoch(sms.date!) 
          : DateTime.now();
          
      // Update most recent message time if needed
      if (messageTime.isAfter(mostRecentMessageTime)) {
        mostRecentMessageTime = messageTime;
      }
      
      return SmsModel(
        id: sms.id?.toString(),
        address: sms.address,
        body: sms.body,
        date: messageTime,
      );
    }).toList();
    
    // Process only messages received after the last processed time
    await _processRecentMessages(smsList, lastProcessedTime);
    
    // Update the last processed time
    if (mostRecentMessageTime.isAfter(lastProcessedTime)) {
      await _saveLastProcessedTime(mostRecentMessageTime);
    }
    
    return smsList;
  }

  // Process recent messages that haven't been processed yet
  Future<void> _processRecentMessages(List<SmsModel> messages, DateTime lastProcessedTime) async {
    // Filter to only process messages received after last check
    final recentMessages = messages.where((msg) => 
        msg.date != null && 
        msg.date!.isAfter(lastProcessedTime) &&
        msg.id != null).toList();
        
    if (recentMessages.isEmpty) {
      print('No new messages to process');
      return;
    }
        
    print('Processing ${recentMessages.length} recent messages');
    
    // Process each message and track which ones were actually shared
    DateTime newestTime = lastProcessedTime;
    for (var message in recentMessages) {
      if (message.id == null) continue;
      
      // Skip messages we've already processed
      if (await _isMessageAlreadyProcessed(message.id!)) {
        print("Skipping already processed message: ${message.id}");
        continue;
      }
      
      // Process this message
      await _processSmsForSharing(message);
      
      // Mark this message as processed
      await _markMessageAsProcessed(message.id!);
      
      // Update the newest message time if needed
      if (message.date != null && message.date!.isAfter(newestTime)) {
        newestTime = message.date!;
      }
    }
    
    // Update last processed time if we found newer messages
    if (newestTime.isAfter(lastProcessedTime)) {
      await _saveLastProcessedTime(newestTime);
    }
  }

  // Start listening for new SMS messages
  Stream<SmsModel> startSmsListener() {
    _incomingSmsController = StreamController<SmsModel>.broadcast(
      onCancel: () {
        // When the last listener cancels, we DON'T mark as not listening
        // to ensure background processing continues
      },
    );
    
    print("Starting SMS listener");
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        print("New SMS received: ${message.address}");
        final messageId = message.id?.toString();
        
        try {
          // Skip if we've already processed this message
          if (messageId != null && await _isMessageAlreadyProcessed(messageId)) {
            print("Skipping already processed incoming message: $messageId");
            return;
          }
          
          SmsModel smsModel = SmsModel(
            id: messageId,
            address: message.address,
            body: message.body,
            date: message.date != null ? 
                DateTime.fromMillisecondsSinceEpoch(message.date!) : 
                DateTime.now(),
          );
          
          // Always process the message for keyword matching, even if controller is closed
          // This ensures messages are processed even when app is in background
          await _processSmsForSharing(smsModel);
          
          // Mark as processed
          if (messageId != null) {
            await _markMessageAsProcessed(messageId);
            
            // Update last processed time
            if (smsModel.date != null) {
              await _saveLastProcessedTime(smsModel.date!);
            }
          }
          
          // Only add to stream if someone is listening
          if (_incomingSmsController != null && !_incomingSmsController!.isClosed) {
            _incomingSmsController?.add(smsModel);
          }
          
          print("Processed incoming SMS for keywords: ${smsModel.address}");
        } catch (e) {
          print("Error processing incoming SMS: $e");
        }
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );
    
    // Always mark as listening for reliability
    _isListening = true;
    
    return _incomingSmsController!.stream;
  }

  void stopSmsListener() {
    // We can't directly cancel the subscription since listenIncomingSms returns void
    // The best we can do is close the controller and set our flag
    _isListening = false;
    _incomingSmsController?.close();
    _incomingSmsController = null;
  }

  // Process an SMS for potential sharing based on keyword rules
  Future<void> _processSmsForSharing(SmsModel sms) async {
    if (sms.body == null || sms.body!.isEmpty) return;
    
    print("Processing SMS for keywords: ${sms.address}");
    
    // Get current user's details for username
    final currentUser = await _databaseService.getUserDetails(_currentUserId);
    
    // Get all active keyword rules for the current user
    final rulesSnapshot = await _databaseService.getUserKeywordRules(_currentUserId).first;
    final activeRules = rulesSnapshot.where((rule) => rule.isActive).toList();
    
    print("Found ${activeRules.length} active rules");
    
    if (activeRules.isEmpty) {
      print("No active rules found for user $_currentUserId");
      return;
    }
    
    for (var rule in activeRules) {
      // Check if any keyword from the rule is in the SMS body
      String? matchedKeyword = _findMatchingKeyword(sms.body!, rule.keywords);
      
      if (matchedKeyword != null) {
        print("Keyword match found: $matchedKeyword for rule ${rule.id}");
        
        // We found a match, create a shared message
        final sharedMessage = SharedSmsModel(
          id: _uuid.v4(),
          senderId: _currentUserId,
          receiverId: rule.receiverId,
          senderUserName: currentUser?.username,
          address: sms.address,
          body: sms.body,
          originalDate: sms.date,
          keywordMatched: matchedKeyword,
        );
        
        // Add to database
        try {
          final messageId = await _databaseService.shareMessage(sharedMessage);
          print("Message shared successfully. ID: $messageId");
        } catch (e) {
          print("Error sharing message: $e");
        }
      } else {
        print("No keyword match for rule ${rule.id}");
      }
    }
  }

  // Find the first keyword that matches in the SMS body
  String? _findMatchingKeyword(String smsBody, List<String> keywords) {
    final lowercaseBody = smsBody.toLowerCase();
    
    for (String keyword in keywords) {
      if (lowercaseBody.contains(keyword.toLowerCase())) {
        return keyword;
      }
    }
    
    return null;
  }

  // Check a list of SMS messages against keyword rules and share matches
  Future<void> processSmsMessagesForSharing(List<SmsModel> messages) async {
    for (var message in messages) {
      await _processSmsForSharing(message);
    }
  }
}

// Background message handler (required for Telephony)
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) {
  print("Background SMS received: ${message.address}");
  
  // We need to use shared preferences directly in this isolated context
  SharedPreferences.getInstance().then((prefs) async {
    final currentUserId = prefs.getString('current_user_id');
    final dbUrl = prefs.getString('firebase_db_url');
    
    if (currentUserId != null && dbUrl != null) {
      try {
        // Initialize Firebase directly
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        
        // Set database URL
        FirebaseDatabase.instance.databaseURL = dbUrl;
        
        // Create database service
        final dbRef = FirebaseDatabase.instance.ref();
        final databaseService = DatabaseService(dbRef);
        
        // Create a temporary SMS service for processing
        final smsService = SmsService(databaseService, currentUserId);
        
        // Convert to SMS model
        final smsModel = SmsModel(
          id: message.id?.toString(),
          address: message.address,
          body: message.body,
          date: message.date != null ? 
              DateTime.fromMillisecondsSinceEpoch(message.date!) : 
              DateTime.now(),
        );
        
        // Process the message
        await smsService._processSmsForSharing(smsModel);
        
        // Mark as processed if it has an ID
        if (message.id != null) {
          final messageId = message.id.toString();
          
          // Add to list of processed IDs
          final processedIds = prefs.getStringList('processed_message_ids_$currentUserId') ?? [];
          if (!processedIds.contains(messageId)) {
            if (processedIds.length >= 1000) {
              processedIds.removeAt(0);
            }
            processedIds.add(messageId);
            await prefs.setStringList('processed_message_ids_$currentUserId', processedIds);
          }
          
          // Update last processed time
          if (message.date != null) {
            await prefs.setInt('last_processed_time_$currentUserId', message.date!);
          }
        }
        
        print("Successfully processed background SMS");
      } catch (e) {
        print("Error processing background SMS: $e");
      }
    } else {
      print("Cannot process background SMS: missing user ID or database URL");
    }
  });
}
