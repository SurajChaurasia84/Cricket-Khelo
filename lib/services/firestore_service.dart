import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/invite_model.dart';
import '../models/request_model.dart';
import '../models/player_request_model.dart';
import 'fcm_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // User Operations
  Future<void> saveUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    var doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, uid);
    }
    return null;
  }

  Stream<List<UserModel>> getAllUsers() {
    return _db.collection('users').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList());
  }

  // Invite Operations
  Future<void> createInvite(InviteModel invite) async {
    await _db.collection('invites').add(invite.toMap());
    
    // Notify other users in the same age group
    var users = await _db.collection('users')
      .where('ageGroup', isEqualTo: invite.ageGroup)
      .get();

    List<String> tokens = users.docs
      .map((doc) => doc.data()['fcmToken'] as String)
      .where((token) => token.isNotEmpty && token != invite.creatorId) // Don't notify self
      .toList();

    FCMService.sendToMultiple(
      tokens: tokens,
      title: "New Match Invite! 🏏",
      body: "${invite.creatorName} is looking for players at ${invite.address}",
      data: {'type': 'match_invite', 'id': invite.inviteId},
    );
  }

  Stream<List<InviteModel>> getInvites(String ageGroup) {
    final DateTime todayMidnight = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    return _db
        .collection('invites')
        .where('ageGroup', isEqualTo: ageGroup)
        .where('timestamp', isGreaterThanOrEqualTo: todayMidnight)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => InviteModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> deleteInvite(String inviteId) async {
    await _db.collection('invites').doc(inviteId).delete();
  }

  // Request Operations
  Future<void> sendJoinRequest(RequestModel request) async {
    await _db.collection('requests').add(request.toMap());

    // Notify match creator
    // We need to fetch the invite to get the creatorId or fetch it from the request
    // Assuming the request has matchId, we fetch the invite first
    var inviteDoc = await _db.collection('invites').doc(request.matchId).get();
    if (inviteDoc.exists) {
      String creatorId = inviteDoc.data()!['creatorId'];
      var creatorDoc = await _db.collection('users').doc(creatorId).get();
      if (creatorDoc.exists) {
        String token = creatorDoc.data()!['fcmToken'] ?? '';
        if (token.isNotEmpty) {
          FCMService.sendNotification(
            toToken: token,
            title: "Join Request! 👋",
            body: "${request.requesterName} wants to join your match.",
            data: {'type': 'join_request', 'id': request.matchId},
          );
        }
      }
    }
  }

  Stream<List<RequestModel>> getRequestsForMatch(String matchId) {
    final DateTime todayMidnight = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    return _db
        .collection('requests')
        .where('matchId', isEqualTo: matchId)
        .where('timestamp', isGreaterThanOrEqualTo: todayMidnight)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RequestModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<RequestModel>> getRequestsForUser(String userId) {
    final DateTime todayMidnight = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    return _db
        .collection('requests')
        .where('requesterId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: todayMidnight)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RequestModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    await _db.collection('requests').doc(requestId).update({'status': status});

    // Notify requester
    var reqDoc = await _db.collection('requests').doc(requestId).get();
    if (reqDoc.exists) {
      String requesterId = reqDoc.data()!['requesterId'];
      String matchId = reqDoc.data()!['matchId'];
      var requesterDoc = await _db.collection('users').doc(requesterId).get();
      if (requesterDoc.exists) {
        String token = requesterDoc.data()!['fcmToken'] ?? '';
        if (token.isNotEmpty) {
          FCMService.sendNotification(
            toToken: token,
            title: status == 'accepted' ? "Request Accepted! ✅" : "Request Rejected ❌",
            body: status == 'accepted' 
              ? "Pack your bags! You are in for the match." 
              : "Sorry, your request was not accepted.",
            data: {'type': 'join_request', 'id': matchId},
          );
        }
      }
    }
  }

  // Player Availability Requests (Players looking for matches)
  Future<void> createPlayerRequest(PlayerRequestModel request) async {
    await _db.collection('player_requests').add(request.toMap());
  }

  Stream<List<PlayerRequestModel>> getPlayerRequests(String ageGroup) {
    final DateTime todayMidnight = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    return _db
        .collection('player_requests')
        .where('ageGroup', isEqualTo: ageGroup)
        .where('timestamp', isGreaterThanOrEqualTo: todayMidnight)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PlayerRequestModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> deletePlayerRequest(String requestId) async {
    await _db.collection('player_requests').doc(requestId).delete();
  }

  // Daily Reset Logic
  Future<void> checkAndPerformReset() async {
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final DocumentReference metadataRef = _db.collection('system').doc('metadata');
    
    var doc = await metadataRef.get();
    if (doc.exists && doc.get('last_reset_date') == today) {
      // Already reset today
      return;
    }

    print("Midnight Reset: Starting daily cleanup...");
    
    // 1. Clear Firestore Collections
    await _clearCollection('invites');
    await _clearCollection('requests');
    await _clearCollection('player_requests');

    // 2. Clear Realtime Database (Chats)
    await FirebaseDatabase.instance.ref('chats').remove();

    // 3. Update Reset Date
    await metadataRef.set({'last_reset_date': today});
    print("Midnight Reset: Cleanup complete!");
  }

  Future<void> _clearCollection(String collectionPath) async {
    var snapshot = await _db.collection(collectionPath).get();
    var batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
