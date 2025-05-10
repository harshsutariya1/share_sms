import 'package:share_sms/models/keyword_rule_model.dart';
import 'package:share_sms/models/shared_sms_model.dart';
import 'package:share_sms/models/user_model.dart';
import 'package:share_sms/services/database_service.dart';
import 'package:uuid/uuid.dart';

class SharingService {
  final DatabaseService _databaseService;
  final String _currentUserId;
  final Uuid _uuid = Uuid();

  SharingService(this._databaseService, this._currentUserId);

  // Get a stream of incoming shared messages
  Stream<List<SharedSmsModel>> getIncomingSharedMessages() {
    return _databaseService.getIncomingSharedMessages(_currentUserId);
  }

  // Get a stream of outgoing shared messages
  Stream<List<SharedSmsModel>> getOutgoingSharedMessages() {
    return _databaseService.getOutgoingSharedMessages(_currentUserId);
  }

  // Mark a message as read
  Future<void> markMessageAsRead(String messageId) async {
    await _databaseService.markMessageAsRead(_currentUserId, messageId);
  }

  // Create a new keyword rule
  Future<String> createKeywordRule(String receiverId, List<String> keywords) async {
    final rule = KeywordRuleModel(
      id: _uuid.v4(),
      userId: _currentUserId,
      receiverId: receiverId,
      keywords: keywords,
      isActive: true,
    );
    
    return await _databaseService.createKeywordRule(rule);
  }

  // Update an existing keyword rule
  Future<void> updateKeywordRule(KeywordRuleModel rule) async {
    if (rule.userId != _currentUserId) {
      throw Exception("Cannot update a rule that doesn't belong to the current user");
    }
    
    await _databaseService.updateKeywordRule(rule);
  }

  // Delete a keyword rule
  Future<void> deleteKeywordRule(String ruleId) async {
    await _databaseService.deleteKeywordRule(_currentUserId, ruleId);
  }

  // Get all rules for the current user
  Stream<List<KeywordRuleModel>> getUserKeywordRules() {
    return _databaseService.getUserKeywordRules(_currentUserId);
  }

  // Get all users for selection (excluding current user)
  Stream<List<UserModel>> getAvailableUsers() {
    return _databaseService.getAllUsers().map((users) {
      return users.where((user) => user.uid != _currentUserId).toList();
    });
  }

  // Manually share a specific message with a user
  Future<String> shareMessageManually(
    String receiverId,
    String address,
    String body, 
    DateTime? originalDate, 
    {String? keywordMatched}
  ) async {
    // Get current user's details for username
    final currentUser = await _databaseService.getUserDetails(_currentUserId);
    
    final sharedMessage = SharedSmsModel(
      id: _uuid.v4(),
      senderId: _currentUserId,
      receiverId: receiverId,
      senderUserName: currentUser?.username, // Include the sender's username
      address: address,
      body: body,
      originalDate: originalDate,
      keywordMatched: keywordMatched,
    );
    
    return await _databaseService.shareMessage(sharedMessage);
  }
}
