import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  final String id;
  final String project;
  final String userId;
  final String status; // running | waiting_permission | waiting_input | finished
  final DateTime? lastActivity;
  final String workingDir;

  const Session({
    required this.id,
    required this.project,
    required this.userId,
    required this.status,
    this.lastActivity,
    this.workingDir = '',
  });

  factory Session.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Session(
      id: doc.id,
      project: d['project'] as String? ?? '',
      userId: d['userId'] as String? ?? '',
      status: d['status'] as String? ?? 'running',
      lastActivity: (d['lastActivity'] as Timestamp?)?.toDate(),
      workingDir: d['workingDir'] as String? ?? '',
    );
  }

  bool get isWaiting =>
      status == 'waiting_permission' || status == 'waiting_input';
}
