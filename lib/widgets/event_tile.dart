import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../theme.dart';

class EventTile extends StatelessWidget {
  final Event event;

  const EventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    if (event.type == 'activity') {
      return _activityTile();
    }
    return _standardTile();
  }

  Widget _activityTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.crust,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, color: AppColors.overlay0, size: 13),
              const SizedBox(width: 6),
              if (event.timestamp != null)
                Text(
                  DateFormat('HH:mm:ss').format(event.timestamp!),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.overlay0,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          MarkdownBody(
            data: event.message,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                color: AppColors.subtext1,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              strong: const TextStyle(
                color: AppColors.blue,
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
              code: const TextStyle(
                color: AppColors.green,
                fontSize: 12,
                fontFamily: 'monospace',
                backgroundColor: AppColors.surface0,
              ),
              codeblockDecoration: BoxDecoration(
                color: AppColors.mantle,
                borderRadius: BorderRadius.circular(6),
              ),
              codeblockPadding: const EdgeInsets.all(10),
            ),
            shrinkWrap: true,
          ),
        ],
      ),
    );
  }

  Widget _standardTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _typeColor().withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: _typeColor(), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _icon(),
              const SizedBox(width: 8),
              Text(
                _typeLabel(),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: _typeColor(),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (event.timestamp != null)
                Text(
                  DateFormat('HH:mm:ss').format(event.timestamp!),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.overlay0),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            event.message,
            style: const TextStyle(fontSize: 14, color: AppColors.text),
          ),
          if (event.type == 'permission_request') ...[
            const SizedBox(height: 6),
            Text('Tool: ${event.tool ?? ""}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.overlay1)),
            if (event.decision != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (event.decision == 'approved'
                          ? AppColors.green
                          : AppColors.red)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  event.decision!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: event.decision == 'approved'
                        ? AppColors.green
                        : AppColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          if (event.type == 'question' && event.response != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.reply, size: 14, color: AppColors.blue),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(event.response!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.blue)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _icon() {
    IconData icon;
    Color color;
    switch (event.type) {
      case 'finished':
        icon = Icons.check_circle;
        color = AppColors.green;
        break;
      case 'permission_request':
        icon = Icons.lock;
        color = AppColors.peach;
        break;
      case 'question':
        icon = Icons.chat_bubble;
        color = AppColors.blue;
        break;
      case 'notification':
        icon = Icons.campaign;
        color = AppColors.mauve;
        break;
      default:
        icon = Icons.notifications;
        color = AppColors.overlay0;
    }
    return Icon(icon, color: color, size: 16);
  }

  String _typeLabel() {
    switch (event.type) {
      case 'finished':
        return 'FINISHED';
      case 'permission_request':
        return 'PERMISSION';
      case 'question':
        return 'QUESTION';
      case 'notification':
        return 'NOTIFICATION';
      default:
        return event.type.toUpperCase();
    }
  }

  Color _typeColor() {
    switch (event.type) {
      case 'finished':
        return AppColors.green;
      case 'permission_request':
        return AppColors.peach;
      case 'question':
        return AppColors.blue;
      case 'notification':
        return AppColors.mauve;
      default:
        return AppColors.overlay0;
    }
  }
}
