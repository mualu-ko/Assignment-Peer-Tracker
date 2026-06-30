import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/assignment.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Enable offline persistence
  FirestoreService() {
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // ── User ──────────────────────────────────────────

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Stream<AppUser> streamUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
          (doc) => AppUser.fromFirestore(doc.data()!, uid),
        );
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc.data()!, uid);
  }

Future<List<String>> getPairMembers(String pairId) async {
  final doc = await _db.collection('pairs').doc(pairId).get();
  if (!doc.exists) return [];
  return List<String>.from(doc.data()!['members']);
}

Future<String?> findExistingPairForUser(String uid) async {
  final query = await _db
      .collection('pairs')
      .where('members', arrayContains: uid)
      .limit(1)
      .get();

  if (query.docs.isEmpty) return null;
  return query.docs.first.id;
}

  // ── Pairing ───────────────────────────────────────

  Future<String> createPairCode(String uid) async {
    final code = _generateCode();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));

    await _db.collection('invites').doc(code).set({
      'code': code,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt.toIso8601String(),
      'consumedPairId': null,
    });
    return code;
  }

  Future<String?> joinWithCode(String code, String uid) async {
    final invite = await _db.collection('invites').doc(code).get();
    if (!invite.exists) return null;

    final data = invite.data()!;
    final createdBy = data['createdBy'] as String;
    final expiresAt = DateTime.parse(data['expiresAt']);

    if (createdBy == uid) return null;

    if (DateTime.now().isAfter(expiresAt)) {
      await _db.collection('invites').doc(code).delete();
      return null; // Expired — joinWithCode caller will show "invalid code"
    }

    final pairRef = _db.collection('pairs').doc();
    final pairId = pairRef.id;

    await pairRef.set({
      'pairId': pairId,
      'members': [createdBy, uid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(uid).update({'pairId': pairId});

    await _db.collection('invites').doc(code).update({
      'consumedPairId': pairId,
    });

    return pairId;
  }

  Stream<String?> watchInviteConsumed(String code) {
    return _db.collection('invites').doc(code).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      final data = doc.data();
      if (data == null) {
        return null;
      }
      return data['consumedPairId'] as String?;
    });
  }

  Future<void> deleteInvite(String code) async {
    await _db.collection('invites').doc(code).delete();
  }

  // ── Assignments ───────────────────────────────────

  Stream<List<Assignment>> streamAssignments(String pairId) {
    return _db
        .collection('assignments')
        .where('pairId', isEqualTo: pairId)
        .orderBy('dueDate')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Assignment.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> createAssignment(Assignment assignment) async {
    await _db
        .collection('assignments')
        .doc(assignment.assignmentId)
        .set(assignment.toFirestore());
  }

  Future<void> updateAssignmentField(
      String assignmentId, Map<String, dynamic> data) async {
    await _db
        .collection('assignments')
        .doc(assignmentId)
        .update(data);
  }

  Future<void> deleteAssignment(String assignmentId) async {
    await _db.collection('assignments').doc(assignmentId).delete();
  }

  // ── Helpers ───────────────────────────────────────

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().millisecondsSinceEpoch;
    return List.generate(6, (i) => chars[(rand >> (i * 4)) % chars.length])
        .join();
  }
}