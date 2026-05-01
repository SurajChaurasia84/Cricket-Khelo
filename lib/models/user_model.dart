class UserModel {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String ageGroup;
  final double lat;
  final double lng;
  final String fcmToken;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.ageGroup,
    required this.lat,
    required this.lng,
    required this.fcmToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'ageGroup': ageGroup,
      'lat': lat,
      'lng': lng,
      'fcmToken': fcmToken,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      ageGroup: map['ageGroup'] ?? '20+',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      fcmToken: map['fcmToken'] ?? '',
    );
  }
}
