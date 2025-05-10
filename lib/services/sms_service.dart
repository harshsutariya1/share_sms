import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:another_telephony/telephony.dart';
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

  SmsService(this._databaseService, this._currentUserId);

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

    List<SmsMessage> messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE, SmsColumn.ID],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    return messages.map((sms) {
      return SmsModel(
        id: sms.id?.toString(),
        address: sms.address,
        body: sms.body,
        date: sms.date != null ? DateTime.fromMillisecondsSinceEpoch(sms.date!) : null,
      );
    }).toList();
  }

  // Start listening for new SMS messages
  Stream<SmsModel> startSmsListener() {
    _incomingSmsController = StreamController<SmsModel>.broadcast(
      onCancel: () {
        // When the last listener cancels, mark as not listening
        _isListening = false;
      },
    );
    
    if (!_isListening) {
      _isListening = true;
      
      // This method returns void, so we don't assign it to _smsSubscription
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          if (_incomingSmsController != null && !_incomingSmsController!.isClosed) {
            SmsModel smsModel = SmsModel(
              id: message.id?.toString(),
              address: message.address,
              body: message.body,
              date: message.date != null ? DateTime.fromMillisecondsSinceEpoch(message.date!) : DateTime.now(),
            );
            
            _incomingSmsController?.add(smsModel);
            _processSmsForSharing(smsModel);
          }
        },
        onBackgroundMessage: backgroundMessageHandler,
        listenInBackground: true,
      );
    }
    
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
    
    // Get current user's details for username
    final currentUser = await _databaseService.getUserDetails(_currentUserId);
    
    // Get all active keyword rules for the current user
    final rulesSnapshot = await _databaseService.getUserKeywordRules(_currentUserId).first;
    final activeRules = rulesSnapshot.where((rule) => rule.isActive).toList();
    
    for (var rule in activeRules) {
      // Check if any keyword from the rule is in the SMS body
      String? matchedKeyword = _findMatchingKeyword(sms.body!, rule.keywords);
      
      if (matchedKeyword != null) {
        // We found a match, create a shared message
        final sharedMessage = SharedSmsModel(
          id: _uuid.v4(),
          senderId: _currentUserId,
          receiverId: rule.receiverId,
          senderUserName: currentUser?.username, // Include the sender's username
          address: sms.address,
          body: sms.body,
          originalDate: sms.date,
          keywordMatched: matchedKeyword,
        );
        
        // Add to database
        await _databaseService.shareMessage(sharedMessage);
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
  // For background processing, we need to use a headless processing approach
  // This will require a separate isolate or background service to handle the processing
  
  // You can use either:
  // 1. Workmanager package for periodic background tasks
  // 2. android_alarm_manager_plus for more immediate execution
  // 3. A custom background service with platform-specific code
  
  // For simplicity, you can use a notification to alert the user:
  final smsBody = message.body;
  if (smsBody != null && smsBody.isNotEmpty) {
    // Create a notification that prompts the user to open the app
    // This requires platform-specific code or a plugin like flutter_local_notifications
  }
}
