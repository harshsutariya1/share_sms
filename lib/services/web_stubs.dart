// This file provides stub implementations for platform-specific APIs
// to allow the app to compile and run on web

// Stub for Telephony
class Telephony {
  static final Telephony _instance = Telephony._internal();
  
  factory Telephony() {
    return _instance;
  }
  
  Telephony._internal();
  
  static Telephony get instance => _instance;
  
  // Stub methods that return empty results
  Future<List<SmsMessage>> getInboxSms({
    List<dynamic>? columns,
    List<dynamic>? sortOrder,
    dynamic filter,
  }) async {
    return [];
  }
  
  Future<bool?> get requestPhoneAndSmsPermissions async => false;
  
  void listenIncomingSms({
    required Function(SmsMessage) onNewMessage,
    Function? onBackgroundMessage,
    bool listenInBackground = false,
  }) {
    // No-op implementation
  }
}

class SmsMessage {
  final String? id;
  final String? address;
  final String? body;
  final int? date;
  
  SmsMessage({this.id, this.address, this.body, this.date});
}

// Add any other necessary stubs for platform-specific classes
class SmsColumn {
  static const String ADDRESS = 'address';
  static const String BODY = 'body';
  static const String DATE = 'date';
  static const String ID = 'id';
  static const String READ = 'read';
}

class OrderBy {
  final String column;
  final Sort sort;
  
  const OrderBy(this.column, {required this.sort});
}

enum Sort {
  ASC,
  DESC,
}

class SmsFilter {
  const SmsFilter.where(String column);
}
