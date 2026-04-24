import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/call/domain/models/call_ui_state.dart';
import 'package:xparq_app/features/call/domain/models/call_status.dart';
import 'package:xparq_app/features/call/presentation/providers/call_providers.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';

class CallSessionArgs {
  final String chatId;
  final String peerUid;
  final String peerName;
  final String peerAvatarUrl;

  const CallSessionArgs({
    required this.chatId,
    required this.peerUid,
    required this.peerName,
    required this.peerAvatarUrl,
  });
}

class CallSessionScreen extends ConsumerStatefulWidget {
  const CallSessionScreen({
    super.key,
    this.args,
    this.showAppBar = false,
  });

  final CallSessionArgs? args;
  final bool showAppBar;

  @override
  ConsumerState<CallSessionScreen> createState() => _CallSessionScreenState();
}

class _CallSessionScreenState extends ConsumerState<CallSessionScreen> {
  bool _bootstrappedArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrappedArgs || widget.args == null) {
      return;
    }

    final state = ref.read(callControllerProvider);
    if (state.status != CallStatus.idle) {
      return;
    }

    _bootstrappedArgs = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(callControllerProvider.notifier)
          .startOutgoing(
            chatId: widget.args!.chatId,
            peerUid: widget.args!.peerUid,
            peerName: widget.args!.peerName,
            peerAvatarUrl: widget.args!.peerAvatarUrl,
          )
          .catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(callControllerProvider);

    final body = Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: SafeArea(
        child: Column(
          children: [
            if (!widget.showAppBar)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: state.isTerminal
                      ? ref.read(callControllerProvider.notifier).dismiss
                      : null,
                  icon: const Icon(Icons.close),
                ),
              )
            else
              const SizedBox(height: 12),
            const Spacer(),
            _Avatar(peerAvatarUrl: state.peerAvatarUrl),
            const SizedBox(height: 24),
            Text(
              state.peerName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              state.statusLabel,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (state.status == CallStatus.connected ||
                state.status == CallStatus.connecting)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _formatDuration(state.elapsedSeconds),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (state.errorMessage != null &&
                (state.status == CallStatus.failed ||
                    state.status == CallStatus.ended))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  state.errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const Spacer(),
            _buildActions(state),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) {
      return Material(child: body);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Call')),
      body: body,
    );
  }

  Widget _buildActions(CallUiState state) {
    switch (state.status) {
      case CallStatus.ringing:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CallActionButton(
              icon: Icons.call_end,
              label: 'Reject',
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              onTap: ref.read(callControllerProvider.notifier).rejectIncoming,
            ),
            _CallActionButton(
              icon: Icons.call,
              label: 'Accept',
              backgroundColor: const Color(0xFF34C759),
              foregroundColor: Colors.white,
              onTap: ref.read(callControllerProvider.notifier).acceptIncoming,
            ),
          ],
        );

      case CallStatus.calling:
        return _CallActionButton(
          icon: Icons.call_end,
          label: 'Cancel',
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
          onTap: ref.read(callControllerProvider.notifier).hangUp,
        );

      case CallStatus.connecting:
      case CallStatus.connected:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CallActionButton(
              icon: state.isMuted ? Icons.mic_off : Icons.mic_none,
              label: state.isMuted ? 'Unmute' : 'Mute',
              onTap: () {
                ref.read(callControllerProvider.notifier).toggleMute();
              },
            ),
            _CallActionButton(
              icon: state.isSpeakerOn ? Icons.volume_up : Icons.hearing,
              label: state.isSpeakerOn ? 'Speaker' : 'Earpiece',
              onTap: () {
                ref.read(callControllerProvider.notifier).toggleSpeaker();
              },
            ),
            _CallActionButton(
              icon: Icons.call_end,
              label: 'End',
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              onTap: ref.read(callControllerProvider.notifier).hangUp,
            ),
          ],
        );

      case CallStatus.ended:
      case CallStatus.failed:
        return _CallActionButton(
          icon: Icons.close,
          label: 'Close',
          onTap: ref.read(callControllerProvider.notifier).dismiss,
        );

      case CallStatus.idle:
        return const SizedBox.shrink();
    }
  }

  String _formatDuration(int elapsedSeconds) {
    final minutes = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.peerAvatarUrl});

  final String peerAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      height: 136,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF25A4F2), Color(0xFF5BE7FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF25A4F2).withValues(alpha: 0.25),
            blurRadius: 28,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipOval(
        child: peerAvatarUrl.isEmpty
            ? Container(
                color: Colors.white10,
                child: const Icon(
                  Icons.person,
                  size: 56,
                  color: Colors.white70,
                ),
              )
            : XparqImage(imageUrl: peerAvatarUrl, fit: BoxFit.cover),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg =
        backgroundColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.08);
    final fg = foregroundColor ?? theme.colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: fg),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: fg)),
      ],
    );
  }
}
