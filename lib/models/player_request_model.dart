import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerRequestModel {
  final String requestId;
  final String playerId;
  final String playerName;
  final String? playerPhoto;
  final String message;
  final int playersAvailable;
  final String ageGroup;
  final String address;
  final double lat;
  final double lng;
  final DateTime timestamp;

  PlayerRequestModel({
    required this.requestId,
    required this.playerId,
    required this.playerName,
    this.playerPhoto,
    required this.message,
    this.playersAvailable = 1,
    required this.ageGroup,
    required this.address,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'playerPhoto': playerPhoto,
      'message': message,
      'playersAvailable': playersAvailable,
      'ageGroup': ageGroup,
      'address': address,
      'lat': lat,
      'lng': lng,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  factory PlayerRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return PlayerRequestModel(
      requestId: id,
      playerId: map['playerId'] ?? '',
      playerName: map['playerName'] ?? 'Player',
      playerPhoto: map['playerPhoto'],
      message: map['message'] ?? '',
      playersAvailable: map['playersAvailable'] ?? 1,
      ageGroup: map['ageGroup'] ?? 'Under20',
      address: map['address'] ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
