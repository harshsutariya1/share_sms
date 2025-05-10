import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_sms/models/keyword_rule_model.dart';
import 'package:share_sms/models/shared_sms_model.dart';
import 'package:share_sms/models/user_model.dart';
import 'package:share_sms/providers/auth_providers.dart';
import 'package:share_sms/services/sharing_service.dart';

// Provider for SharingService
final sharingServiceProvider = Provider<SharingService?>((ref) {
  final currentUserId = ref.watch(currentUserIdProvider);
  final databaseService = ref.watch(databaseServiceProvider);
  
  if (currentUserId != null) {
    return SharingService(databaseService, currentUserId);
  }
  return null;
});

// Provider for incoming shared messages
final incomingSharedMessagesProvider = StreamProvider<List<SharedSmsModel>>((ref) {
  final sharingService = ref.watch(sharingServiceProvider);
  if (sharingService == null) {
    return Stream.value([]);
  }
  
  return sharingService.getIncomingSharedMessages();
});

// Provider for outgoing shared messages
final outgoingSharedMessagesProvider = StreamProvider<List<SharedSmsModel>>((ref) {
  final sharingService = ref.watch(sharingServiceProvider);
  if (sharingService == null) {
    return Stream.value([]);
  }
  
  return sharingService.getOutgoingSharedMessages();
});

// Provider for keyword rules
final keywordRulesProvider = StreamProvider<List<KeywordRuleModel>>((ref) {
  final sharingService = ref.watch(sharingServiceProvider);
  if (sharingService == null) {
    return Stream.value([]);
  }
  
  return sharingService.getUserKeywordRules();
});

// Provider for available users to share with
final availableUsersProvider = StreamProvider<List<UserModel>>((ref) {
  final sharingService = ref.watch(sharingServiceProvider);
  if (sharingService == null) {
    return Stream.value([]);
  }
  
  return sharingService.getAvailableUsers();
});

// State controller for managing keyword rules
class KeywordRuleState {
  final List<String> keywords;
  final String? selectedUserId;
  final bool isCreating;
  final String? errorMessage;

  KeywordRuleState({
    this.keywords = const [],
    this.selectedUserId,
    this.isCreating = false,
    this.errorMessage,
  });

  KeywordRuleState copyWith({
    List<String>? keywords,
    String? selectedUserId,
    bool? isCreating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return KeywordRuleState(
      keywords: keywords ?? this.keywords,
      selectedUserId: selectedUserId ?? this.selectedUserId,
      isCreating: isCreating ?? this.isCreating,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class KeywordRuleController extends StateNotifier<KeywordRuleState> {
  final SharingService _sharingService;

  KeywordRuleController(this._sharingService) : super(KeywordRuleState());

  void addKeyword(String keyword) {
    if (keyword.trim().isEmpty) return;
    if (!state.keywords.contains(keyword.trim())) {
      state = state.copyWith(
        keywords: [...state.keywords, keyword.trim()],
        clearError: true,
      );
    }
  }

  void removeKeyword(String keyword) {
    state = state.copyWith(
      keywords: state.keywords.where((k) => k != keyword).toList(),
      clearError: true,
    );
  }

  void setSelectedUser(String userId) {
    state = state.copyWith(selectedUserId: userId, clearError: true);
  }

  Future<bool> createRule() async {
    if (state.keywords.isEmpty) {
      state = state.copyWith(errorMessage: 'Please add at least one keyword');
      return false;
    }
    
    if (state.selectedUserId == null) {
      state = state.copyWith(errorMessage: 'Please select a user to share with');
      return false;
    }
    
    state = state.copyWith(isCreating: true, clearError: true);
    
    try {
      await _sharingService.createKeywordRule(
        state.selectedUserId!,
        state.keywords,
      );
      
      // Reset state after successful creation
      state = KeywordRuleState();
      return true;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: 'Failed to create rule: ${e.toString()}',
      );
      return false;
    }
  }
}

// Provider for keyword rule controller
final keywordRuleControllerProvider = StateNotifierProvider<KeywordRuleController, KeywordRuleState>((ref) {
  final sharingService = ref.watch(sharingServiceProvider);
  if (sharingService == null) {
    throw Exception('SharingService not available');
  }
  
  return KeywordRuleController(sharingService);
});
