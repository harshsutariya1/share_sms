class UserModel {
  final String uid;
  final String email;
  final String? username;
  final String? profileImage;
  final DateTime createdAt;
  final DateTime lastActive;
  final bool isOnline;

  UserModel({
    required this.uid,
    required this.email,
    this.username,
    this.profileImage,
    DateTime? createdAt,
    DateTime? lastActive,
    this.isOnline = false,
  }) : 
    this.createdAt = createdAt ?? DateTime.now(),
    this.lastActive = lastActive ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'profileImage': profileImage,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastActive': lastActive.millisecondsSinceEpoch,
      'isOnline': isOnline,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      username: json['username'] as String?,
      profileImage: json['profileImage'] as String?,
      createdAt: json['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt']) 
          : null,
      lastActive: json['lastActive'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastActive']) 
          : null,
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }
}
