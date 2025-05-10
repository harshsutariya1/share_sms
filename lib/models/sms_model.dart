class SmsModel {
  final String? id;
  final String? address; // Sender's address (phone number)
  final String? body;    // Message content
  final DateTime? date;  // Date message was sent/received
  final bool isRead;     // Whether the message has been read

  SmsModel({
    this.id,
    this.address,
    this.body,
    this.date,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'body': body,
      'date': date?.millisecondsSinceEpoch,
      'isRead': isRead,
    };
  }

  factory SmsModel.fromJson(Map<String, dynamic> json) {
    return SmsModel(
      id: json['id']?.toString(),
      address: json['address'] as String?,
      body: json['body'] as String?,
      date: json['date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['date']) 
          : null,
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}
