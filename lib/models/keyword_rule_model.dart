class KeywordRuleModel {
  final String id;
  final String userId;       // Owner of the rule
  final String receiverId;   // Who to share with
  final List<String> keywords; // Keywords to monitor
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  KeywordRuleModel({
    required this.id,
    required this.userId,
    required this.receiverId,
    required this.keywords,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
  }) : this.createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'receiverId': receiverId,
      'keywords': keywords,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory KeywordRuleModel.fromJson(Map<String, dynamic> json) {
    return KeywordRuleModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      receiverId: json['receiverId'] as String,
      keywords: (json['keywords'] as List<dynamic>).map((e) => e as String).toList(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt']) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt']) 
          : null,
    );
  }
}
