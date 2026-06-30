class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String avatar;
  final String? pairId;
  final String? fcmToken;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.avatar,
    this.pairId,
    this.fcmToken,
  });

  bool get isPaired => pairId != null && pairId!.isNotEmpty;

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'User',
      avatar: data['avatar'] ?? '🙂',
      pairId: data['pairId'],
      fcmToken: data['fcmToken'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'avatar': avatar,
      'pairId': pairId,
      'fcmToken': fcmToken,
    };
  }

  AppUser copyWith({
    String? displayName,
    String? avatar,
    String? pairId,
    String? fcmToken,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      pairId: pairId ?? this.pairId,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}