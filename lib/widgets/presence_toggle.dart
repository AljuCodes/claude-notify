import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../theme.dart';

class PresenceToggle extends StatelessWidget {
  final FirestoreService firestore;

  const PresenceToggle({super.key, required this.firestore});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: firestore.presenceStream(uid),
      builder: (context, snap) {
        final isAtDesk = snap.data ?? false;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: SwitchListTile(
            title: Text(
              isAtDesk ? 'At my desk' : 'Away from desk',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isAtDesk ? AppColors.green : AppColors.peach,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              isAtDesk
                  ? 'Mobile notifications suppressed'
                  : 'Mobile notifications enabled',
              style: const TextStyle(fontSize: 12, color: AppColors.overlay0),
            ),
            secondary: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isAtDesk ? AppColors.green : AppColors.peach)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isAtDesk ? Icons.desktop_mac : Icons.phone_android,
                color: isAtDesk ? AppColors.green : AppColors.peach,
                size: 18,
              ),
            ),
            value: isAtDesk,
            onChanged: (val) => firestore.setPresence(uid, val),
          ),
        );
      },
    );
  }
}
