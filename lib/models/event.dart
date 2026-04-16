import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String type; // finished | notification | permission_request | question
  final String message;
  final String? tool;
  final Map<String, dynamic>? toolInput;
  final String? decision; // approved | denied | null
  final String? response;
  final String status; // pending | resolved
  final DateTime? timestamp;

  const Event({
    required this.id,
    required this.type,
    required this.message,
    this.tool,
    this.toolInput,
    this.decision,
    this.response,
    required this.status,
    this.timestamp,
  });

  factory Event.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      type: d['type'] as String? ?? 'notification',
      message: d['message'] as String? ?? '',
      tool: d['tool'] as String?,
      toolInput: d['toolInput'] as Map<String, dynamic>?,
      decision: d['decision'] as String?,
      response: d['response'] as String?,
      status: d['status'] as String? ?? 'resolved',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  bool get isPending => status == 'pending';
}
