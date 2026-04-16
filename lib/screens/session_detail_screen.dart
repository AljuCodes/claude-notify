import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/firestore_service.dart';
import '../models/session.dart';
import '../widgets/event_tile.dart';
import '../theme.dart';

class SessionDetailScreen extends StatelessWidget {
  final String sessionId;
  final FirestoreService firestore;

  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Session?>(
      stream: firestore.sessionStream(sessionId),
      builder: (context, sessionSnap) {
        final session = sessionSnap.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(session?.project ?? 'Session'),
            leading: BackButton(onPressed: () => context.go('/')),
            actions: [
              if (session != null) ...[
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(session.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statusLabel(session.status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(session.status),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete session',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete session?'),
                        content: Text(
                            'Remove "${session.project}" and all its events?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete',
                                style: TextStyle(color: AppColors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      final router = GoRouter.of(context);
                      await firestore.deleteSession(sessionId);
                      router.go('/');
                    }
                  },
                ),
              ],
            ],
          ),
          body: StreamBuilder(
            stream: firestore.eventsStream(sessionId),
            builder: (context, eventSnap) {
              if (!eventSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final events = eventSnap.data!;
              if (events.isEmpty) {
                return const Center(
                  child: Text('No events yet',
                      style: TextStyle(color: AppColors.overlay0)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: events.length,
                itemBuilder: (ctx, i) => EventTile(event: events[i]),
              );
            },
          ),
          floatingActionButton: session != null
              ? _actionButton(context, session)
              : null,
        );
      },
    );
  }

  Widget? _actionButton(BuildContext context, Session session) {
    if (session.status == 'waiting_permission') {
      return FloatingActionButton.extended(
        onPressed: () async {
          final eventId = await firestore.getPendingEventId(
              sessionId, 'permission_request');
          if (context.mounted) {
            context.go('/permission/$sessionId?eventId=${eventId ?? ""}');
          }
        },
        icon: const Icon(Icons.lock_open),
        label: const Text('Respond'),
        backgroundColor: AppColors.peach,
        foregroundColor: AppColors.crust,
      );
    }
    if (session.status == 'waiting_input') {
      return FloatingActionButton.extended(
        onPressed: () async {
          final eventId =
              await firestore.getPendingEventId(sessionId, 'question');
          if (context.mounted) {
            context.go('/question/$sessionId?eventId=${eventId ?? ""}');
          }
        },
        icon: const Icon(Icons.reply),
        label: const Text('Reply'),
        backgroundColor: AppColors.blue,
        foregroundColor: AppColors.crust,
      );
    }
    return null;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'waiting_permission': return 'PERMISSION';
      case 'waiting_input': return 'QUESTION';
      case 'finished': return 'DONE';
      default: return 'RUNNING';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'waiting_permission': return AppColors.peach;
      case 'waiting_input': return AppColors.blue;
      case 'finished': return AppColors.green;
      default: return AppColors.overlay0;
    }
  }
}
