import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/call/domain/models/call_status.dart';
import 'package:xparq_app/features/call/domain/models/call_ui_state.dart';
import 'package:xparq_app/features/call/presentation/providers/call_controller.dart';
import 'package:xparq_app/features/call/presentation/providers/call_providers.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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
  const CallSessionScreen({super.key, this.args, this.showAppBar = false});

  final CallSessionArgs? args;
  final bool showAppBar;

  @override
  ConsumerState<CallSessionScreen> createState() => _CallSessionScreenState();
}

class _CallSessionScreenState extends ConsumerState<CallSessionScreen>
    with TickerProviderStateMixin {
  bool _bootstrappedArgs = false;
  late AnimationController _ringController;
  late AnimationController _orbController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _orbController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrappedArgs || widget.args == null) return;
    final state = ref.read(callControllerProvider);
    if (state.status != CallStatus.idle) return;
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
    final state = ref.watch(callControllerProvider);
    final peer = ref.watch(callPeerPresentationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          _GalacticBackground(isDark: isDark, orbController: _orbController),

          // Remote Video
          _VideoLayer(state: state, ref: ref),

          // Content
          SafeArea(
            child: Column(
              children: [
                _TopBar(state: state, isDark: isDark),
                const Spacer(flex: 2),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: state.isPeerCameraOn ? 0.0 : 1.0,
                  child: IgnorePointer(
                    ignoring: state.isPeerCameraOn,
                    child: _AvatarSection(
                      avatarUrl: peer.avatarUrl,
                      peerName: peer.displayName,
                      state: state,
                      isDark: isDark,
                      ringController: _ringController,
                      waveController: _waveController,
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                _ActionsSection(state: state, isDark: isDark, ref: ref),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // Local PIP
          if (state.isCameraOn && state.hasCameraPreview)
            Positioned(
              top: 80,
              right: 20,
              child: _LocalPIP(isDark: isDark, ref: ref),
            ),
        ],
      ),
    );
  }
}

// ─── Background ──────────────────────────────────────────────────────────────

class _GalacticBackground extends StatelessWidget {
  const _GalacticBackground({required this.isDark, required this.orbController});

  final bool isDark;
  final AnimationController orbController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: orbController,
      builder: (_, __) {
        final t = orbController.value;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF06060F) : const Color(0xFFF2EFFF),
          ),
          child: CustomPaint(
            painter: _OrbPainter(t: t, isDark: isDark),
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter({required this.t, required this.isDark});
  final double t;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    void drawOrb(Offset center, double radius, Color color, double opacity) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    final dx = math.sin(t * math.pi * 2) * 20;
    final dy = math.cos(t * math.pi * 2) * 15;

    if (isDark) {
      drawOrb(Offset(size.width * 0.2 + dx, size.height * 0.15 + dy), 220, const Color(0xFF4C1D95), 0.18);
      drawOrb(Offset(size.width * 0.85 - dx, size.height * 0.75 + dy), 180, const Color(0xFF0369A1), 0.14);
      drawOrb(Offset(size.width * 0.6 + dx * 0.5, size.height * 0.4), 100, const Color(0xFFBE185D), 0.08);
    } else {
      drawOrb(Offset(size.width * 0.2 + dx, size.height * 0.15 + dy), 220, const Color(0xFF7C3AED), 0.12);
      drawOrb(Offset(size.width * 0.85 - dx, size.height * 0.75 + dy), 180, const Color(0xFF0EA5E9), 0.10);
    }

    // Stars (dark only)
    if (isDark) {
      final starPaint = Paint()..color = Colors.white;
      final stars = [
        const Offset(60, 55), const Offset(280, 90), const Offset(40, 200),
        const Offset(300, 350), const Offset(80, 420), const Offset(310, 480),
      ];
      for (final s in stars) {
        final alpha = (0.3 + math.sin(t * math.pi * 2 + s.dx) * 0.2).clamp(0.1, 0.6);
        canvas.drawCircle(s, 1.0, starPaint..color = Colors.white.withOpacity(alpha));
      }
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}

// ─── Top Bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.isDark});
  final CallUiState state;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final pillColor = isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9);
    final pillBg = isDark ? const Color(0xFF1A1A3A) : const Color(0xFFEDE9FF);
    final dotColor = state.status == CallStatus.connected
        ? const Color(0xFF4ADE80)
        : const Color(0xFFFBBF24);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Consumer(
            builder: (_, ref, __) => GestureDetector(
              onTap: state.isTerminal
                  ? ref.read(callControllerProvider.notifier).dismiss
                  : null,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDark ? Colors.white38 : Colors.black26,
                size: 28,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: pillColor.withOpacity(0.25),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 5, height: 5, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(
                  _pillLabel(state.status),
                  style: TextStyle(color: pillColor, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),
        ],
      ),
    );
  }

  String _pillLabel(CallStatus s) {
    switch (s) {
      case CallStatus.calling: return 'Calling';
      case CallStatus.ringing: return 'Incoming';
      case CallStatus.connecting: return 'Connecting';
      case CallStatus.connected: return 'Connected';
      case CallStatus.ended: return 'Ended';
      case CallStatus.failed: return 'Failed';
      default: return 'iXPARQ';
    }
  }
}

// ─── Avatar Section ───────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.avatarUrl,
    required this.peerName,
    required this.state,
    required this.isDark,
    required this.ringController,
    required this.waveController,
  });

  final String avatarUrl;
  final String peerName;
  final CallUiState state;
  final bool isDark;
  final AnimationController ringController;
  final AnimationController waveController;

  @override
  Widget build(BuildContext context) {
    final nameColor = isDark ? Colors.white : const Color(0xFF1A0533);
    final subColor = isDark ? const Color(0xFF9B8FCC) : const Color(0xFF7C3AED);
    final timerBg = isDark ? const Color(0xFF0F0F25) : const Color(0xFFEDE9FF);
    final timerBorder = isDark ? const Color(0xFF2A2A4A) : const Color(0xFFCBC0F0);
    final timerColor = isDark ? const Color(0xFFE9D5FF) : const Color(0xFF4C1D95);

    return Column(
      children: [
        // Avatar with ripple rings
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple rings
              ...List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: ringController,
                  builder: (_, __) {
                    final offset = i / 3.0;
                    final progress = ((ringController.value + offset) % 1.0);
                    final scale = 0.7 + progress * 0.65;
                    final opacity = (1.0 - progress).clamp(0.0, 0.7);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF7C3AED).withOpacity(opacity),
                            width: 1,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),

              // Avatar
              _SpinningRingAvatar(
                avatarUrl: avatarUrl,
                size: 96,
                isDark: isDark,
                orbController: ringController,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Name
        Text(
          peerName,
          style: TextStyle(
            color: nameColor,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 5),

        // Status
        Text(
          state.statusLabel,
          style: TextStyle(color: subColor, fontSize: 12, letterSpacing: 0.2),
        ),

        const SizedBox(height: 12),

        // Timer (connected only)
        if (state.status == CallStatus.connected || state.status == CallStatus.connecting)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: timerBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: timerBorder, width: 0.5),
            ),
            child: Text(
              _formatDuration(state.elapsedSeconds),
              style: TextStyle(
                color: timerColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.8,
              ),
            ),
          ),

        // Wave bars (connected only)
        if (state.status == CallStatus.connected) ...[
          const SizedBox(height: 14),
          _WaveBars(isDark: isDark, controller: waveController),
        ],
      ],
    );
  }

  String _formatDuration(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}

class _SpinningRingAvatar extends StatelessWidget {
  const _SpinningRingAvatar({
    required this.avatarUrl,
    required this.size,
    required this.isDark,
    required this.orbController,
  });

  final String avatarUrl;
  final double size;
  final bool isDark;
  final AnimationController orbController;

  @override
  Widget build(BuildContext context) {
    final innerBg = isDark ? const Color(0xFF120A2E) : const Color(0xFFEDE9FE);
    final fallbackColor = isDark ? const Color(0xFFE9D5FF) : const Color(0xFF4C1D95);

    return AnimatedBuilder(
      animation: orbController,
      builder: (_, child) {
        return ShaderMask(
          shaderCallback: (bounds) => SweepGradient(
            colors: const [
              Color(0xFF7C3AED),
              Color(0xFFA78BFA),
              Color(0xFF38BDF8),
              Color(0xFF818CF8),
              Color(0xFF7C3AED),
            ],
            transform: GradientRotation(orbController.value * math.pi * 2),
          ).createShader(bounds),
          child: child,
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: innerBg),
          clipBehavior: Clip.antiAlias,
          child: avatarUrl.isNotEmpty
              ? XparqImage(imageUrl: avatarUrl, fit: BoxFit.cover)
              : Center(
                  child: Icon(Icons.person_rounded, size: size * 0.42, color: fallbackColor),
                ),
        ),
      ),
    );
  }
}

class _WaveBars extends StatelessWidget {
  const _WaveBars({required this.isDark, required this.controller});
  final bool isDark;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final barColor = isDark ? const Color(0xFF7C3AED) : const Color(0xFF7C3AED);
    final heights = [5.0, 10.0, 16.0, 20.0, 14.0, 8.0, 5.0];
    final delays = [0.0, 0.14, 0.28, 0.42, 0.56, 0.70, 0.84];

    return SizedBox(
      height: 22,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(heights.length, (i) {
          return AnimatedBuilder(
            animation: controller,
            builder: (_, __) {
              final t = ((controller.value + delays[i]) % 1.0);
              final scale = 0.4 + math.sin(t * math.pi) * 0.6;
              final opacity = 0.3 + scale * 0.7;
              return Container(
                width: 2.5,
                height: heights[i] * scale,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ─── Actions Section ──────────────────────────────────────────────────────────

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({required this.state, required this.isDark, required this.ref});
  final CallUiState state;
  final bool isDark;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(callControllerProvider.notifier);

    switch (state.status) {
      case CallStatus.ringing:
        return _IncomingActions(isDark: isDark, controller: controller);

      case CallStatus.calling:
        return _OutgoingActions(isDark: isDark, state: state, controller: controller);

      case CallStatus.connecting:
      case CallStatus.connected:
        return _ConnectedActions(isDark: isDark, state: state, controller: controller);

      case CallStatus.ended:
      case CallStatus.failed:
        return _EndedActions(state: state, isDark: isDark, controller: controller);

      default:
        return const SizedBox.shrink();
    }
  }
}

// Incoming: Accept + Decline
class _IncomingActions extends StatelessWidget {
  const _IncomingActions({required this.isDark, required this.controller});
  final bool isDark;
  final CallController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundBtn(
          icon: Icons.call_end_rounded,
          label: 'Decline',
          bg: const LinearGradient(colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)]),
          iconColor: Colors.white,
          labelColor: isDark ? const Color(0xFF9B8FCC) : const Color(0xFF7C3AED),
          onTap: controller.rejectIncoming,
        ),
        const SizedBox(width: 48),
        _RoundBtn(
          icon: Icons.call_rounded,
          label: 'Accept',
          bg: const LinearGradient(colors: [Color(0xFF14532D), Color(0xFF16A34A)]),
          iconColor: Colors.white,
          labelColor: isDark ? const Color(0xFF9B8FCC) : const Color(0xFF7C3AED),
          onTap: controller.acceptIncoming,
        ),
      ],
    );
  }
}

// Outgoing: Speaker + End
class _OutgoingActions extends StatelessWidget {
  const _OutgoingActions({required this.isDark, required this.state, required this.controller});
  final bool isDark;
  final CallUiState state;
  final CallController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GlassBtn(
              icon: state.isSpeakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
              label: 'Speaker',
              isDark: isDark,
              active: state.isSpeakerOn,
              onTap: controller.toggleSpeaker,
            ),
          ],
        ),
        const SizedBox(height: 28),
        _RoundBtn(
          icon: Icons.call_end_rounded,
          label: 'Cancel',
          bg: const LinearGradient(colors: [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFFF87171)]),
          iconColor: Colors.white,
          labelColor: isDark ? const Color(0xFF9B8FCC) : const Color(0xFF7C3AED),
          onTap: controller.hangUp,
        ),
      ],
    );
  }
}

// Connected: Mute + Speaker + Camera + End
class _ConnectedActions extends StatelessWidget {
  const _ConnectedActions({required this.isDark, required this.state, required this.controller});
  final bool isDark;
  final CallUiState state;
  final CallController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Control buttons row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GlassBtn(
              icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_none_rounded,
              label: state.isMuted ? 'Unmute' : 'Mute',
              isDark: isDark,
              active: state.isMuted,
              onTap: controller.toggleMute,
            ),
            const SizedBox(width: 20),
            _GlassBtn(
              icon: state.isSpeakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
              label: 'Speaker',
              isDark: isDark,
              active: state.isSpeakerOn,
              onTap: controller.toggleSpeaker,
            ),
            const SizedBox(width: 20),
            _GlassBtn(
              icon: state.isCameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              label: 'Camera',
              isDark: isDark,
              active: state.isCameraOn,
              onTap: controller.toggleCamera,
            ),
          ],
        ),

        const SizedBox(height: 28),

        // End call (centered circle)
        _RoundBtn(
          icon: Icons.call_end_rounded,
          label: 'End call',
          bg: const LinearGradient(colors: [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFFF87171)]),
          iconColor: Colors.white,
          labelColor: isDark ? const Color(0xFF9B8FCC) : const Color(0xFF7C3AED),
          onTap: controller.hangUp,
        ),
      ],
    );
  }
}

// Ended / Failed
class _EndedActions extends StatelessWidget {
  const _EndedActions({required this.state, required this.isDark, required this.controller});
  final CallUiState state;
  final bool isDark;
  final CallController controller;

  @override
  Widget build(BuildContext context) {
    final subColor = isDark ? const Color(0xFF9B8FCC) : const Color(0xFF7C3AED);
    return Column(
      children: [
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              state.errorMessage!,
              style: TextStyle(color: subColor.withOpacity(0.7), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        _GlassBtn(
          icon: Icons.close_rounded,
          label: 'Close',
          isDark: isDark,
          onTap: controller.dismiss,
        ),
      ],
    );
  }
}

// ─── Shared Button Widgets ────────────────────────────────────────────────────

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.icon,
    required this.label,
    required this.bg,
    required this.iconColor,
    required this.labelColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Gradient bg;
  final Color iconColor;
  final Color labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: bg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Shine
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: 29,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white.withOpacity(0.12), Colors.transparent],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(29)),
                    ),
                  ),
                ),
                Center(child: Icon(icon, color: iconColor, size: 24)),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(label, style: TextStyle(color: labelColor, fontSize: 11, letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  const _GlassBtn({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? const Color(0xFF7C3AED).withOpacity(0.28)
        : (isDark ? const Color(0xFF0F0F25) : const Color(0xFFEDE9FF));
    final border = active
        ? const Color(0xFF7C3AED).withOpacity(0.55)
        : (isDark ? const Color(0xFF2A2A4A) : const Color(0xFFCBC0F0));
    final iconColor = active
        ? const Color(0xFFA78BFA)
        : (isDark ? const Color(0xFF9B8FCC) : const Color(0xFF6D28D9));
    final labelColor = isDark ? const Color(0xFF9B8FCC) : const Color(0xFF6D28D9);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              border: Border.all(color: border, width: 0.5),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 7),
          Text(label, style: TextStyle(color: labelColor, fontSize: 11, letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

// ─── Video Components ───────────────────────────────────────────────────────

class _VideoLayer extends StatelessWidget {
  const _VideoLayer({required this.state, required this.ref});

  final CallUiState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (!state.isPeerCameraOn) return const SizedBox.shrink();

    final mediaService = ref.watch(mediasoupCallServiceProvider);
    final remoteRenderer = mediaService.remoteRenderer;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 800),
      opacity: state.remoteVideoAttached ? 1.0 : 0.0,
      child: Container(
        color: Colors.black,
        child: remoteRenderer != null
            ? RTCVideoView(
                remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white24),
              ),
      ),
    );
  }
}

class _LocalPIP extends StatelessWidget {
  const _LocalPIP({required this.isDark, required this.ref});

  final bool isDark;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final mediaService = ref.watch(mediasoupCallServiceProvider);
    final localRenderer = mediaService.localRenderer;

    return Container(
      width: 100,
      height: 150,
      decoration: BoxDecoration(
        color: isDark ? Colors.black45 : Colors.white38,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: localRenderer != null
            ? RTCVideoView(
                localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            : Container(
                color: Colors.black54,
                child: const Icon(Icons.videocam_off, color: Colors.white24),
              ),
      ),
    );
  }
}
