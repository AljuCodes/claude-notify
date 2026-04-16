import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../services/firestore_service.dart';
import '../models/event.dart';
import '../theme.dart';

class PermissionRequestScreen extends StatefulWidget {
  final String sessionId;
  final String eventId;
  final FirestoreService firestore;

  const PermissionRequestScreen({
    super.key,
    required this.sessionId,
    required this.eventId,
    required this.firestore,
  });

  @override
  State<PermissionRequestScreen> createState() =>
      _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  bool _loading = false;
  bool _showingLiveFeed = false;
  String? _decision;
  int _countdown = 30;
  Timer? _timer;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _decide(String decision, {String? response}) async {
    setState(() => _loading = true);
    try {
      await widget.firestore.resolvePermission(
        widget.sessionId,
        widget.eventId,
        decision,
        response: response,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _showingLiveFeed = true;
          _decision = decision;
          _countdown = 30;
        });
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        if (mounted) context.go('/session/${widget.sessionId}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showingLiveFeed) return _liveFeedView();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Request'),
        leading: BackButton(
            onPressed: () => context.go('/session/${widget.sessionId}')),
      ),
      body: StreamBuilder<Event?>(
        stream: widget.firestore.eventStream(widget.sessionId, widget.eventId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final event = snap.data;
          if (event == null) {
            return const Center(
              child: Text('Event not found',
                  style: TextStyle(color: AppColors.overlay0)),
            );
          }

          if (!event.isPending) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: (event.decision == 'approved'
                              ? AppColors.green
                              : AppColors.red)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      event.decision == 'approved'
                          ? Icons.check_circle
                          : Icons.cancel,
                      size: 40,
                      color: event.decision == 'approved'
                          ? AppColors.green
                          : AppColors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    event.decision == 'approved' ? 'Approved' : 'Denied',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.peach.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline,
                      size: 28, color: AppColors.peach),
                ),
                const SizedBox(height: 16),
                const Text('Claude wants to run:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.overlay1)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.crust,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surface1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (event.tool != null)
                        Text('Tool: ${event.tool}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.blue,
                            )),
                      const SizedBox(height: 6),
                      Text(event.message,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: AppColors.text,
                          )),
                    ],
                  ),
                ),
                if (event.toolInput != null &&
                    event.toolInput!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Details',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.subtext0)),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.crust,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.toolInput.toString(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: AppColors.subtext0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _decide('denied'),
                          icon: const Icon(Icons.close, color: AppColors.red),
                          label: const Text('Deny',
                              style: TextStyle(color: AppColors.red)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                                color: AppColors.red.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _decide('approved'),
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.green,
                            foregroundColor: AppColors.crust,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: AppColors.surface1),
                  const SizedBox(height: 8),
                  const Text(
                    'Or send a custom instruction:',
                    style: TextStyle(fontSize: 12, color: AppColors.overlay0),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(
                              color: AppColors.text, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'e.g. use /tmp/safe_dir instead',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _decide('denied', response: val.trim());
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final val = _textController.text.trim();
                          if (val.isNotEmpty) {
                            _decide('denied', response: val);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        child: const Icon(Icons.send, size: 18),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _liveFeedView() {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text('Live'),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface0,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _decision == 'approved' ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: _decision == 'approved'
                      ? AppColors.green
                      : AppColors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  _decision == 'approved' ? 'Approved' : 'Denied',
                  style: TextStyle(
                    fontSize: 12,
                    color: _decision == 'approved'
                        ? AppColors.green
                        : AppColors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/session/${widget.sessionId}'),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_countdown}s',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.subtext0,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Event>>(
        stream: widget.firestore.eventsStream(widget.sessionId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data!;
          if (events.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(height: 12),
                  Text('Waiting for activity...',
                      style: TextStyle(color: AppColors.overlay0)),
                ],
              ),
            );
          }

          // Auto-scroll to bottom on new events
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: events.length,
            itemBuilder: (ctx, i) => _liveFeedTile(events[i]),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/session/${widget.sessionId}'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.surface0,
                foregroundColor: AppColors.text,
              ),
              child: const Text('Go to Session'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _liveFeedTile(Event event) {
    if (event.type == 'activity') {
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
                const Icon(Icons.terminal,
                    color: AppColors.overlay0, size: 13),
                const SizedBox(width: 6),
                if (event.timestamp != null)
                  Text(
                    '${event.timestamp!.hour.toString().padLeft(2, '0')}:${event.timestamp!.minute.toString().padLeft(2, '0')}:${event.timestamp!.second.toString().padLeft(2, '0')}',
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

    // Non-activity events: compact colored bar
    Color color;
    IconData icon;
    switch (event.type) {
      case 'finished':
        color = AppColors.green;
        icon = Icons.check_circle;
        break;
      case 'permission_request':
        color = AppColors.peach;
        icon = Icons.lock;
        break;
      case 'notification':
        color = AppColors.mauve;
        icon = Icons.campaign;
        break;
      default:
        color = AppColors.overlay0;
        icon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.message,
              style: const TextStyle(fontSize: 13, color: AppColors.text),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
