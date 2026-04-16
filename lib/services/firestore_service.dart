import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session.dart';
import '../models/event.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Presence ──────────────────────────────────────────────────────────────

  Stream<bool> presenceStream(String uid) {
    return _db
        .doc('users/$uid/status/presence')
        .snapshots()
        .map((snap) => snap.exists ? (snap.data()?['isAtDesk'] as bool? ?? false) : false);
  }

  Future<void> setPresence(String uid, bool isAtDesk) {
    return _db.doc('users/$uid/status/presence').set({
      'isAtDesk': isAtDesk,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── FCM token ─────────────────────────────────────────────────────────────

  Future<void> saveFcmToken(String uid, String token) {
    return _db.doc('users/$uid').set({'fcmToken': token}, SetOptions(merge: true));
  }

  // ── Sessions ──────────────────────────────────────────────────────────────

  Stream<List<Session>> sessionsStream(String uid) {
    return _db
        .collection('sessions')
        .where('userId', isEqualTo: uid)
        .orderBy('lastActivity', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Session.fromDoc).toList());
  }

  Stream<Session?> sessionStream(String sessionId) {
    return _db
        .doc('sessions/$sessionId')
        .snapshots()
        .map((snap) => snap.exists ? Session.fromDoc(snap) : null);
  }

  // ── Events ────────────────────────────────────────────────────────────────

  Stream<List<Event>> eventsStream(String sessionId) {
    return _db
        .collection('sessions/$sessionId/events')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(Event.fromDoc).toList());
  }

  Future<Event?> getEvent(String sessionId, String eventId) async {
    final snap = await _db.doc('sessions/$sessionId/events/$eventId').get();
    return snap.exists ? Event.fromDoc(snap) : null;
  }

  Future<String?> getPendingEventId(String sessionId, String type) async {
    final snap = await _db
        .collection('sessions/$sessionId/events')
        .where('type', isEqualTo: type)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first.id;
  }

  Stream<Event?> eventStream(String sessionId, String eventId) {
    return _db
        .doc('sessions/$sessionId/events/$eventId')
        .snapshots()
        .map((snap) => snap.exists ? Event.fromDoc(snap) : null);
  }

  Future<void> deleteSession(String sessionId) async {
    final events =
        await _db.collection('sessions/$sessionId/events').get();
    for (final doc in events.docs) {
      await doc.reference.delete();
    }
    await _db.doc('sessions/$sessionId').delete();
  }

  // ── Decisions / Replies ───────────────────────────────────────────────────

  Future<void> resolvePermission(
      String sessionId, String eventId, String decision,
      {String? response}) {
    return _db.doc('sessions/$sessionId/events/$eventId').update({
      'decision': decision,
      'status': 'resolved',
      if (response != null && response.isNotEmpty) 'response': response,
    });
  }

  Future<void> sendReply(String sessionId, String eventId, String reply) {
    return _db.doc('sessions/$sessionId/events/$eventId').update({
      'response': reply,
      'status': 'resolved',
    });
  }
}
