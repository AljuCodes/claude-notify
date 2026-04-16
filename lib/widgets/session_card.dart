import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../theme.dart';

class SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;

  const SessionCard({super.key, required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _statusColor(), width: 3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _statusIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.project,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (session.workingDir.isNotEmpty)
                        Text(
                          session.workingDir,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.overlay0,
                            fontFamily: 'monospace',
                          ),
                        ),
                      if (session.lastActivity != null)
                        Text(
                          DateFormat('MMM d, HH:mm').format(session.lastActivity!),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.overlay0),
                        ),
                    ],
                  ),
                ),
                _statusBadge(),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.surface2, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusIcon() {
    IconData icon;
    Color color;
    switch (session.status) {
      case 'waiting_permission':
        icon = Icons.lock_outline;
        color = AppColors.peach;
        break;
      case 'waiting_input':
        icon = Icons.chat_bubble_outline;
        color = AppColors.blue;
        break;
      case 'finished':
        icon = Icons.check_circle_outline;
        color = AppColors.green;
        break;
      default:
        icon = Icons.play_circle_outline;
        color = AppColors.overlay1;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Color _statusColor() {
    switch (session.status) {
      case 'waiting_permission': return AppColors.peach;
      case 'waiting_input': return AppColors.blue;
      case 'finished': return AppColors.green;
      default: return AppColors.surface2;
    }
  }

  Widget _statusBadge() {
    Color color;
    String label;
    switch (session.status) {
      case 'waiting_permission':
        color = AppColors.peach;
        label = 'PERM';
        break;
      case 'waiting_input':
        color = AppColors.blue;
        label = 'ASK';
        break;
      case 'finished':
        color = AppColors.green;
        label = 'DONE';
        break;
      default:
        color = AppColors.overlay0;
        label = 'RUN';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          )),
    );
  }
}
