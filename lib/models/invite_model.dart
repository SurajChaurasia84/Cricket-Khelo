import 'package:cloud_firestore/cloud_firestore.dart';

class InviteModel {
  final String inviteId;
  final String createdBy;
  final int playersRequired;
  final String message;
  final String ageGroup;
  final double lat;
  final double lng;
  final DateTime timestamp;

  InviteModel({
    required this.inviteId,
    required this.createdBy,
    required this.playersRequired,
    required this.message,
    required this.ageGroup,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'playersRequired': playersRequired,
      'message': message,
      'ageGroup': ageGroup,
      'lat': lat,
      'lng': lng,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  factory InviteModel.fromMap(Map<String, dynamic> map, String id) {
    return InviteModel(
      inviteId: id,
      createdBy: map['createdBy'] ?? '',
      playersRequired: map['playersRequired'] ?? 0,
      message: map['message'] ?? '',
      ageGroup: map['ageGroup'] ?? '20+',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
