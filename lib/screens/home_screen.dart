import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/presence_toggle.dart';
import '../widgets/session_card.dart';
import '../theme.dart';

class HomeScreen extends StatelessWidget {
  final FirestoreService firestore;
  final AuthService auth;

  const HomeScreen({super.key, required this.firestore, required this.auth});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Claude Notify'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sign out',
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Presence toggle
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            decoration: BoxDecoration(
              color: AppColors.surface0,
              borderRadius: BorderRadius.circular(12),
            ),
            child: PresenceToggle(firestore: firestore),
          ),

          // UID banner
          _UidBanner(uid: uid),

          // Session list
          Expanded(
            child: StreamBuilder(
              stream: firestore.sessionsStream(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text('Error: ${snap.error}',
                        style: const TextStyle(color: AppColors.red)),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sessions = snap.data!;
                if (sessions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.terminal, size: 48,
                            color: AppColors.surface2),
                        const SizedBox(height: 12),
                        const Text('No Claude sessions yet',
                            style: TextStyle(color: AppColors.overlay0)),
                        const SizedBox(height: 4),
                        const Text('Run a Claude Code task to see it here',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.overlay0)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: sessions.length,
                  itemBuilder: (ctx, i) {
                    final s = sessions[i];
                    return Dismissible(
                      key: ValueKey(s.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            const Icon(Icons.delete_outline, color: AppColors.red),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete session?'),
                            content: Text(
                                'Remove "${s.project}" and all its events?'),
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
                      },
                      onDismissed: (_) => firestore.deleteSession(s.id),
                      child: SessionCard(
                        session: s,
                        onTap: () => context.go('/session/${s.id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UidBanner extends StatelessWidget {
  final String uid;
  const _UidBanner({required this.uid});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: uid));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('UID copied to clipboard')),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface0,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surface1),
        ),
        child: Row(
          children: [
            const Icon(Icons.fingerprint, size: 16, color: AppColors.overlay0),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                uid,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AppColors.subtext0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.copy, size: 14, color: AppColors.overlay0),
          ],
        ),
      ),
    );
  }
}
