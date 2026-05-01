import 'package:cloud_firestore/cloud_firestore.dart';

class InviteModel {
  final String inviteId;
  final String createdBy;
  final String creatorName;
  final String? creatorPhoto;
  final int playersRequired;
  final String message;
  final String ageGroup;
  final String address;
  final double lat;
  final double lng;
  final DateTime timestamp;

  InviteModel({
    required this.inviteId,
    required this.createdBy,
    required this.creatorName,
    this.creatorPhoto,
    required this.playersRequired,
    required this.message,
    required this.ageGroup,
    required this.address,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'creatorName': creatorName,
      'creatorPhoto': creatorPhoto,
      'playersRequired': playersRequired,
      'message': message,
      'ageGroup': ageGroup,
      'address': address,
      'lat': lat,
      'lng': lng,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  factory InviteModel.fromMap(Map<String, dynamic> map, String id) {
    return InviteModel(
      inviteId: id,
      createdBy: map['createdBy'] ?? '',
      creatorName: map['creatorName'] ?? 'Player',
      creatorPhoto: map['creatorPhoto'],
      playersRequired: map['playersRequired'] ?? 0,
      message: map['message'] ?? '',
      ageGroup: map['ageGroup'] ?? '20+',
      address: map['address'] ?? 'Location not specified',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
