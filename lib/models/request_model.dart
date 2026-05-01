import 'package:cloud_firestore/cloud_firestore.dart';

class RequestModel {
  final String requestId;
  final String matchId;
  final String requesterId;
  final String requesterName;
  final String? requesterPhoto;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime timestamp;

  RequestModel({
    required this.requestId,
    required this.matchId,
    required this.requesterId,
    required this.requesterName,
    this.requesterPhoto,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'matchId': matchId,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'requesterPhoto': requesterPhoto,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  factory RequestModel.fromMap(Map<String, dynamic> map, String id) {
    return RequestModel(
      requestId: id,
      matchId: map['matchId'] ?? '',
      requesterId: map['requesterId'] ?? '',
      requesterName: map['requesterName'] ?? 'Player',
      requesterPhoto: map['requesterPhoto'],
      status: map['status'] ?? 'pending',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
