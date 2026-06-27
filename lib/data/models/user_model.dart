// lib/data/models/user_model.dart

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isGuest;
  final String role; // 'host' or 'player'

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.isGuest = false,
    this.role = 'player',
  });

  bool get isHost => role == 'host';

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isGuest,
    String? role,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isGuest: isGuest ?? this.isGuest,
      role: role ?? this.role,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'],
      isGuest: map['isGuest'] ?? false,
      role: map['role'] ?? 'player',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isGuest': isGuest,
      'role': role,
    };
  }
}
