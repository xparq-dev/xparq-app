// lib/features/social/widgets/echo_bottom_sheet.dart
//
// Bottom sheet for viewing and adding Echo (comments) on a Pulse.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/social/models/echo_model.dart';
import 'package:xparq_app/features/social/models/pulse_model.dart';
import 'package:xparq_app/features/social/providers/pulse_providers.dart';

class EchoBottomSheet extends ConsumerStatefulWidget {
  final PulseModel pulse;

  const EchoBottomSheet({super.key, required this.pulse});

  @override
  ConsumerState<EchoBottomSheet> createState() => _EchoBottomSheetState();
}

class _EchoBottomSheetState extends ConsumerState<EchoBottomSheet> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendEcho() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final profile = ref.read(planetProfileProvider).valueOrNull;
    final uid = ref.read(authRepositoryProvider).currentUser?.id;
    if (profile == null || uid == null) return;

    setState(() => _isSending = true);
    try {
      await ref
          .read(pulseRepositoryProvider)
          .addEcho(
            pulseId: widget.pulse.id,
            uid: uid,
            content: text,
            authorProfile: profile,
          );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final echoStream = ref.watch(echoesProvider(widget.pulse.id));
    final currentUid = ref.read(authRepositoryProvider).currentUser?.id;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetBgColor = isDark
        ? const Color(0xFF0D1B2A)
        : theme.colorScheme.surface;
    final inputBarBgColor = isDark
        ? const Color(0xFF0A1628)
        : const Color(0xFFF8FAFC);
    final handleColor = theme.colorScheme.onSurface.withValues(alpha: 
      isDark ? 0.24 : 0.18,
    );
    final dividerColor = theme.colorScheme.onSurface.withValues(alpha: 
      isDark ? 0.12 : 0.08,
    );
    final headerTextColor = theme.colorScheme.onSurface.withValues(alpha: 
      isDark ? 0.70 : 0.78,
    );
    final inputFillColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.10)
        : const Color(0xFFEEF2F7);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBgColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: isDark
                ? null
                : Border(
                    top: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.mode_comment_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Echoes on "${widget.pulse.content.length > 40 ? '${widget.pulse.content.substring(0, 40)}…' : widget.pulse.content}"',
                        style: TextStyle(color: headerTextColor, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: dividerColor, height: 1),

              // Echoes list
              Expanded(
                child: echoStream.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.54),
                      ),
                    ),
                  ),
                  data: (echoes) {
                    if (echoes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mode_comment_outlined,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.24),
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No echoes yet.\nBe the first to resonate!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.38),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: echoes.length,
                      itemBuilder: (context, i) => _EchoTile(
                        echo: echoes[i],
                        pulseId: widget.pulse.id,
                        currentUid: currentUid,
                      ),
                    );
                  },
                ),
              ),

              // Input bar
              Container(
                padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                decoration: BoxDecoration(
                  color: inputBarBgColor,
                  border: Border(top: BorderSide(color: dividerColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Send an echo...',
                          hintStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                          filled: true,
                          fillColor: inputFillColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    _isSending
                        ? SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4FC3F7),
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              Icons.send_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: _sendEcho,
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EchoTile extends ConsumerWidget {
  final EchoModel echo;
  final String pulseId;
  final String? currentUid;

  const _EchoTile({
    required this.echo,
    required this.pulseId,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = currentUid == echo.uid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: echo.authorAvatar.isNotEmpty
                ? NetworkImage(echo.authorAvatar)
                : null,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.10),
            child: echo.authorAvatar.isEmpty
                ? Icon(
                    Icons.person,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                    size: 16,
                  )
                : null,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      echo.authorName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      timeago.format(echo.createdAt),
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.38),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  echo.content,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (isOwner)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.38),
                size: 18,
              ),
              onPressed: () async {
                await ref
                    .read(pulseRepositoryProvider)
                    .deleteEcho(pulseId: pulseId, echoId: echo.id);
              },
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
        ],
      ),
    );
  }
}
