import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/invite_model.dart';

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
  }

  Stream<List<InviteModel>> getInvites(String ageGroup) {
    return _db
        .collection('invites')
        .where('ageGroup', isEqualTo: ageGroup)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => InviteModel.fromMap(doc.data(), doc.id)).toList());
  }
}
