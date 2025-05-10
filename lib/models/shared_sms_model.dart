class SharedSmsModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String? senderName;
  final String? senderUserName; // Added new property for sender's username
  final String? address;  // Original sender's phone number
  final String? body;     // Message content
  final DateTime? originalDate; // Date the original SMS was received
  final DateTime sharedDate;    // Date the SMS was shared
  final bool isRead;
  final String? keywordMatched;

  SharedSmsModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.senderName,
    this.senderUserName, // Added to constructor
    this.address,
    this.body,
    this.originalDate,
    DateTime? sharedDate,
    this.isRead = false,
    this.keywordMatched,
  }) : sharedDate = sharedDate ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'senderUserName': senderUserName, // Include in JSON
      'address': address,
      'body': body,
      'originalDate': originalDate?.millisecondsSinceEpoch,
      'sharedDate': sharedDate.millisecondsSinceEpoch,
      'isRead': isRead,
      'keywordMatched': keywordMatched,
    };
  }

  factory SharedSmsModel.fromJson(Map<String, dynamic> json) {
    return SharedSmsModel(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      senderName: json['senderName'] as String?,
      senderUserName: json['senderUserName'] as String?, // Parse from JSON
      address: json['address'] as String?,
      body: json['body'] as String?,
      originalDate: json['originalDate'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['originalDate']) 
          : null,
      sharedDate: json['sharedDate'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['sharedDate']) 
          : null,
      isRead: json['isRead'] as bool? ?? false,
      keywordMatched: json['keywordMatched'] as String?,
    );
  }
}
