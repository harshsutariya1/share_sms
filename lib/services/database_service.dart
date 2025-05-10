import 'package:firebase_database/firebase_database.dart';
import 'package:share_sms/models/keyword_rule_model.dart';
import 'package:share_sms/models/shared_sms_model.dart';
import 'package:share_sms/models/user_model.dart';
import 'package:uuid/uuid.dart';

class DatabaseService {
  final DatabaseReference _databaseReference;
  final Uuid _uuid = Uuid();

  DatabaseService(this._databaseReference);

  // User methods
  Future<void> createUser(UserModel user) async {
    await _databaseReference.child('users').child(user.uid).set(user.toJson());
  }

  Future<void> updateUser(UserModel user) async {
    await _databaseReference.child('users').child(user.uid).update(user.toJson());
  }

  Future<void> updateUserStatus(String uid, bool isOnline) async {
    await _databaseReference.child('users').child(uid).update({
      'isOnline': isOnline,
      'lastActive': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<UserModel?> getUserDetails(String uid) async {
    final snapshot = await _databaseReference.child('users').child(uid).get();
    if (snapshot.exists && snapshot.value != null) {
      return UserModel.fromJson(Map<String, dynamic>.from(snapshot.value as Map));
    }
    return null;
  }

  Stream<List<UserModel>> getAllUsers() {
    return _databaseReference.child('users').onValue.map((event) {
      final Map<dynamic, dynamic>? users = event.snapshot.value as Map?;
      if (users == null) return [];
      
      return users.entries.map((entry) {
        return UserModel.fromJson(Map<String, dynamic>.from(entry.value));
      }).toList();
    });
  }

  // Keyword rules methods
  Future<String> createKeywordRule(KeywordRuleModel rule) async {
    String id = rule.id.isEmpty ? _uuid.v4() : rule.id;
    final newRule = KeywordRuleModel(
      id: id,
      userId: rule.userId,
      receiverId: rule.receiverId,
      keywords: rule.keywords,
      isActive: rule.isActive,
    );
    
    await _databaseReference
        .child('keyword_rules')
        .child(newRule.userId)
        .child(id)
        .set(newRule.toJson());
    
    return id;
  }

  Future<void> updateKeywordRule(KeywordRuleModel rule) async {
    await _databaseReference
        .child('keyword_rules')
        .child(rule.userId)
        .child(rule.id)
        .update({
          ...rule.toJson(),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
  }

  Future<void> deleteKeywordRule(String userId, String ruleId) async {
    await _databaseReference
        .child('keyword_rules')
        .child(userId)
        .child(ruleId)
        .remove();
  }

  Stream<List<KeywordRuleModel>> getUserKeywordRules(String userId) {
    return _databaseReference
        .child('keyword_rules')
        .child(userId)
        .onValue
        .map((event) {
          final Map<dynamic, dynamic>? rules = event.snapshot.value as Map?;
          if (rules == null) return [];
          
          return rules.entries.map((entry) {
            return KeywordRuleModel.fromJson(Map<String, dynamic>.from(entry.value));
          }).toList();
        });
  }

  // Shared SMS methods
  Future<String> shareMessage(SharedSmsModel message) async {
    String id = message.id.isEmpty ? _uuid.v4() : message.id;
    
    // Get the sender's username from the database
    String? senderUserName;
    if (message.senderUserName == null) {
      final senderDetails = await getUserDetails(message.senderId);
      senderUserName = senderDetails?.username;
    } else {
      senderUserName = message.senderUserName;
    }
    
    final sharedMessage = SharedSmsModel(
      id: id,
      senderId: message.senderId,
      receiverId: message.receiverId,
      senderName: message.senderName,
      senderUserName: senderUserName, // Include the sender's username
      address: message.address,
      body: message.body,
      originalDate: message.originalDate,
      isRead: false,
      keywordMatched: message.keywordMatched,
    );
    
    // Store in sender's outbox
    await _databaseReference
        .child('shared_messages')
        .child(message.senderId)
        .child('outbox')
        .child(id)
        .set(sharedMessage.toJson());
    
    // Store in receiver's inbox
    await _databaseReference
        .child('shared_messages')
        .child(message.receiverId)
        .child('inbox')
        .child(id)
        .set(sharedMessage.toJson());
    
    return id;
  }

  Stream<List<SharedSmsModel>> getIncomingSharedMessages(String userId) {
    return _databaseReference
        .child('shared_messages')
        .child(userId)
        .child('inbox')
        .onValue
        .map((event) {
          final Map<dynamic, dynamic>? messages = event.snapshot.value as Map?;
          if (messages == null) return [];
          
          return messages.entries.map((entry) {
            return SharedSmsModel.fromJson(Map<String, dynamic>.from(entry.value));
          }).toList();
        });
  }

  Stream<List<SharedSmsModel>> getOutgoingSharedMessages(String userId) {
    return _databaseReference
        .child('shared_messages')
        .child(userId)
        .child('outbox')
        .onValue
        .map((event) {
          final Map<dynamic, dynamic>? messages = event.snapshot.value as Map?;
          if (messages == null) return [];
          
          return messages.entries.map((entry) {
            return SharedSmsModel.fromJson(Map<String, dynamic>.from(entry.value));
          }).toList();
        });
  }

  Future<void> markMessageAsRead(String userId, String messageId) async {
    await _databaseReference
        .child('shared_messages')
        .child(userId)
        .child('inbox')
        .child(messageId)
        .update({'isRead': true});
  }
}
