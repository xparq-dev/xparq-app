// lib/features/social/widgets/pulse_card.dart

import 'dart:ui' as ui;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/block_report/widgets/report_bottom_sheet.dart';
import 'package:intl/intl.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/shared/enums/age_group.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/social/models/pulse_model.dart';
import 'package:xparq_app/features/social/providers/pulse_providers.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'echo_bottom_sheet.dart';

class PulseCard extends ConsumerStatefulWidget {
  final PulseModel pulse;

  /// Called after the pulse is deleted so the parent can refresh.
  final VoidCallback? onDeleted;

  const PulseCard({super.key, required this.pulse, this.onDeleted});

  @override
  ConsumerState<PulseCard> createState() => _PulseCardState();
}

class _PulseCardState extends ConsumerState<PulseCard> {
  // ── Local optimistic state ────────────────────────────────────────────────
  late bool _isSparked;
  late int _sparkCount;
  late bool _isWarped;
  late int _warpCount;
  bool _isRevealed = false; // Tap-to-reveal for Black Hole content
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _isSparked = false;
    _sparkCount = widget.pulse.sparkCount;
    _isWarped = false;
    _warpCount = widget.pulse.warpCount;

    // Check initial state from Firestore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hasSparkedProvider(widget.pulse.id).future).then((val) {
        if (mounted) setState(() => _isSparked = val);
      });
      ref.read(hasWarpedProvider(widget.pulse.id).future).then((val) {
        if (mounted) setState(() => _isWarped = val);
      });
    });

    if (widget.pulse.videoUrl != null && widget.pulse.videoUrl!.isNotEmpty) {
      if (kIsWeb) {
        // Defer video init on web to save resources
      } else {
        _initVideo();
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.pulse.videoUrl!),
    );
    try {
      await _videoController!.initialize();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Video init error: $e');
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _toggleSpark() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.id;
    if (uid == null) return;
    setState(() {
      _isSparked = !_isSparked;
      _sparkCount += _isSparked ? 1 : -1;
    });
    try {
      await ref.read(pulseRepositoryProvider).toggleSpark(widget.pulse.id, uid);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSparked = !_isSparked;
          _sparkCount += _isSparked ? 1 : -1;
        });
      }
    }
  }

  void _openEcho() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EchoBottomSheet(pulse: widget.pulse),
    );
  }

  void _warp() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.id;
    if (uid == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                _isWarped ? Icons.rocket_launch : Icons.rocket_launch_outlined,
                color: const Color(0xFF4FC3F7),
              ),
              title: Text(
                _isWarped
                    ? AppLocalizations.of(context)!.pulseUnwarp
                    : AppLocalizations.of(context)!.pulseWarp,
                style: const TextStyle(
                  color: Color(0xFF4FC3F7),
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                _isWarped
                    ? AppLocalizations.of(context)!.pulseUnwarp
                    : AppLocalizations.of(context)!.pulseWarp,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(modalContext);
                _toggleWarpState(uid);
              },
            ),
            Divider(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            ),
            ListTile(
              leading: Icon(
                Icons.send_outlined,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              title: Text(
                AppLocalizations.of(context)!.pulseSendInSignal,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.pulseShareFriendsDesc,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(modalContext);
                _showWarpToUsersSheet(uid);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _toggleWarpState(String uid) async {
    setState(() {
      _isWarped = !_isWarped;
      _warpCount += _isWarped ? 1 : -1;
    });

    try {
      final myProfile = ref.read(planetProfileProvider).value;
      if (myProfile == null) return;

      await ref.read(pulseRepositoryProvider).toggleWarp(
            pulseId: widget.pulse.id,
            uid: uid,
            authorProfile: myProfile,
            originalPulse: widget.pulse,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isWarped
                  ? AppLocalizations.of(context)!.pulseWarpedSuccess
                  : AppLocalizations.of(context)!.pulseWarpRemoved,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWarped = !_isWarped;
          _warpCount += _isWarped ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showWarpToUsersSheet(String currentUid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.pulseWarpToTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF1D9BF0),
                          child: Icon(Icons.bookmark, color: Colors.white),
                        ),
                        title: Text(
                          AppLocalizations.of(context)!.chatListSavedMe,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          AppLocalizations.of(context)!.pulseWarpMeMeDesc,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _sendWarpToChat(currentUid, currentUid);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          AppLocalizations.of(context)!.pulseWarpInviteFriends,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _sendWarpToChat(String myUid, String targetUid) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final chat = await repo.getOrCreateChat(
        myUid: myUid,
        otherUid: targetUid,
      );

      final myProfile = ref.read(planetProfileProvider).value;
      if (myProfile == null) return;

      // We need recipientAgeGroup for Guardian Shield isSpam check.
      // For now, we'll try to find it from the other user's table.
      final otherData = await Supabase.instance.client
          .from('users')
          .select('age_group')
          .eq('id', targetUid)
          .maybeSingle();
      final otherAgeGroup = otherData != null
          ? AgeGroup.values.firstWhere(
              (e) => e.name == (otherData['age_group'] as String?),
              orElse: () => AgeGroup.cadet,
            )
          : AgeGroup.cadet;

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final messageContent = l10n.pulseWarpMessage(
          widget.pulse.authorName,
          widget.pulse.content,
        );
        await repo.sendMessage(
          chatId: chat.chatId,
          senderProfile: myProfile,
          otherUid: targetUid,
          plaintext: messageContent,
          isSensitive: widget.pulse.isNsfw,
          recipientAgeGroup: otherAgeGroup,
        );
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pulseSentSignal)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showOptions() {
    final currentUid = ref.read(authRepositoryProvider).currentUser?.id;
    final isOwner = currentUid == widget.pulse.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // [DEBUG] Always show delete during this fix phase to see if RLS or UID mismatch exists
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text(
                'Delete Pulse (FORCE)',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                _deletePulse();
              },
            ),
            if (!isOwner)
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orangeAccent),
                title: Text(
                  AppLocalizations.of(context)!.pulseReportPulse,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showReportSheet(
                    context,
                    ref,
                    targetUid: widget.pulse.uid,
                    reportContext: 'orbit',
                  );
                },
              ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _deletePulse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          AppLocalizations.of(context)!.pulseDeleteConfirmTitle,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          AppLocalizations.of(context)!.pulseDeleteConfirmDesc,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final currentUid = ref.read(authRepositoryProvider).currentUser?.id;
      debugPrint('--- DELETE ATTEMPT START ---');
      debugPrint('Pulse ID: ${widget.pulse.id}');
      debugPrint('Post UID: ${widget.pulse.uid}');
      debugPrint('My UID: $currentUid');
      
      await ref.read(pulseRepositoryProvider).deletePulse(widget.pulse);
      
      debugPrint('--- DELETE SUCCESS ---');
      
      // TRIGGER GLOBAL PROVIDER RELOAD
      ref.read(pulseRefreshProvider.notifier).state++;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pulse removed from orbit 🚀'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      widget.onDeleted?.call();
    } catch (e, stack) {
      debugPrint('--- DELETE FAILED ---');
      debugPrint('Error: $e');
      debugPrint('Stacktrace: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete Failed: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _formatPulseDate(DateTime date) {
    var postDate = date.toLocal();
    var now = DateTime.now();
    var difference = now.difference(postDate);

    // EMERGENCY LEGACY FIX: Handle posts saved with +7h offset bug
    // if the post is in the future by 1-8 hours, we subtract 7 hours to fix it.
    if (difference.isNegative && difference.inHours.abs() >= 1 && difference.inHours.abs() < 8) {
      postDate = postDate.subtract(const Duration(hours: 7));
      difference = now.difference(postDate);
    }

    final timeStr = DateFormat('HH:mm').format(postDate);

    if (difference.isNegative) {
      return 'เมื่อครู่ • $timeStr';
    }

    if (difference.inHours < 24 && postDate.day == now.day) {
      if (difference.inMinutes < 1) return 'เมื่อครู่ • $timeStr';
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} นาทีที่แล้ว • $timeStr';
      }
      return '${difference.inHours} ชม. ที่แล้ว • $timeStr';
    } else if (difference.inDays < 7) {
      // After 24h, take the "ago" part out as requested and show date/time
      final dateStr = DateFormat('d MMM').format(postDate);
      return '$dateStr • $timeStr';
    } else if (now.year == postDate.year) {
      return '${DateFormat('d MMM').format(postDate)} • $timeStr';
    } else {
      return '${DateFormat('d MMM yyyy').format(postDate)} • $timeStr';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pulse = widget.pulse;
    final ageGroup = ref.watch(currentAgeGroupProvider);
    final hasBlackHoleUnlock =
        ref.watch(planetProfileProvider).valueOrNull?.nsfwOptIn ?? false;
    final isCadet = ageGroup == AgeGroup.cadet;
    // Content should be censored when NSFW and user hasn't unlocked / not yet revealed
    final isCensored =
        pulse.isNsfw && (isCadet || (!hasBlackHoleUnlock && !_isRevealed));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.zero,
        border: Border(
          bottom: BorderSide(
            color: pulse.isNsfw
                ? Colors.redAccent.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Warp Indicator ────────────────────────────────────────────
            if (pulse.originId != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.rocket_launch,
                      size: 14,
                      color: Color(0xFF4FC3F7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pulse.authorName} วาร์ปแล้ว',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final currentUid = ref
                          .read(authRepositoryProvider)
                          .currentUser
                          ?.id;
                      if (pulse.uid == currentUid) {
                        context.push(AppRoutes.profile);
                      } else {
                        context.push('${AppRoutes.otherProfile}/${pulse.uid}');
                      }
                    },
                    child: Consumer(
                      builder: (context, ref, child) {
                        final authorProfile = ref
                            .watch(planetProfileByUidProvider(pulse.uid))
                            .valueOrNull;
                        final avatarUrl =
                            authorProfile?.photoUrl ?? pulse.authorAvatar;
                        final displayName =
                            authorProfile?.xparqName ?? pulse.authorName;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? XparqImage.getImageProvider(avatarUrl)
                                  : null,
                              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
                              radius: 20,
                              child: avatarUrl.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.54),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        displayName,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified,
                                        color: Colors.grey,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${pulse.authorPlanetType} • ${_formatPulseDate(pulse.createdAt)}',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.54),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (pulse.isNsfw) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.redAccent.withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.nsfwTitle,
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (pulse.moodEmoji != null ||
                                      pulse.locationName != null) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (pulse.moodEmoji != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                pulse.moodEmoji!,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (pulse.moodLabel != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 4),
                                                  child: Text(
                                                    pulse.moodLabel!,
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        if (pulse.locationName != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.location_on_outlined,
                                                size: 13,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.5),
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                pulse.locationName!,
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.6),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                // ⋮ menu button
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                    size: 20,
                  ),
                  onPressed: _showOptions,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Content ───────────────────────────────────────────────────
            Builder(
              builder: (_) {
                // 1. Cadet: Permanent Mosaic Blur (Text Replacement)
                if (pulse.isNsfw && isCadet) {
                  return Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 110),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Simulated mosaic text
                        Text(
                          _generateMosaicText(pulse.content.length),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            fontSize: 15,
                            fontFeatures: const [
                              ui.FontFeature.tabularFigures(),
                            ],
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.lock,
                              color: Colors.redAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.sensitiveContentCadet,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                // 2. Explorer (No Opt-in): Blurred with Tap to Reveal
                if (isCensored) {
                  return GestureDetector(
                    onTap: () {
                      // Show confirmation dialog before revealing
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
                          title: Text(
                            AppLocalizations.of(context)!.pulseRevealTitle,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          content: Text(
                            AppLocalizations.of(context)!.pulseRevealDesc,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                AppLocalizations.of(context)!.cancel,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => _isRevealed = true);
                              },
                              child: Text(
                                AppLocalizations.of(context)!.reveal,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 80),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          // Blurred text layer
                          Opacity(
                            opacity: 0.5,
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: 8,
                                sigmaY: 8,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  pulse.content, // Real content blurred
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Overlay
                          Positioned.fill(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility_off,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.sensitiveTapToHide,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    pulse.content,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      letterSpacing: -0.1,
                    ),
                  ),
                );
              },
            ),

            // ── Image ─────────────────────────────────────────────────────
            // Cadet: NSFW images are completely hidden
            if (pulse.imageUrl != null &&
                pulse.imageUrl!.isNotEmpty &&
                !(pulse.isNsfw && isCadet)) ...[
              const SizedBox(height: 12),
              if (isCensored)
                // Explorer without unlock: blurred image + tap to reveal
                GestureDetector(
                  onTap: () => setState(() => _isRevealed = true),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 220,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: 30,
                              sigmaY: 30,
                            ),
                            child: XparqImage(
                              imageUrl: pulse.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Container(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_off,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  size: 40,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '⚠️ Tap to reveal\nBlack Hole content',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: XparqImage(
                    imageUrl: pulse.imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
            ],

            // ── Video ─────────────────────────────────────────────────────
            if (pulse.videoUrl != null &&
                pulse.videoUrl!.isNotEmpty &&
                !(pulse.isNsfw && isCadet)) ...[
              const SizedBox(height: 12),
              if (isCensored)
                GestureDetector(
                  onTap: () => setState(() => _isRevealed = true),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: 220,
                      color: Theme.of(context).colorScheme.surface,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_off,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              size: 40,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '⚠️ Tap to reveal\nBlack Hole video content',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else if (_isVideoInitialized && _videoController != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_videoController!),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _videoController!.value.isPlaying
                                  ? _videoController!.pause()
                                  : _videoController!.play();
                            });
                          },
                          child: Container(
                            color: Colors.transparent,
                            child: Center(
                              child: Icon(
                                _videoController!.value.isPlaying
                                    ? Icons.pause_circle_outline
                                    : Icons.play_circle_outline,
                                size: 50,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],

            const SizedBox(height: 16),
            Divider(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
            ),

            // ── Action Bar ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SparkButton(
                  isSparked: _isSparked,
                  sparkCount: _sparkCount,
                  onTap: _toggleSpark,
                ),
                _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: 'Echo',
                  count: pulse.echoCount,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                  onTap: _openEcho,
                ),
                _ActionButton(
                  icon: _isWarped
                      ? Icons.rocket_launch
                      : Icons.rocket_launch_outlined,
                  label: 'Warp',
                  count: _warpCount,
                  color: _isWarped
                      ? const Color(0xFF4FC3F7)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                  onTap: _warp,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _generateMosaicText(int length) {
    const chars = '█▓▒░';
    final buffer = StringBuffer();
    // Generate simulated length but cap it to avoid huge strings
    final displayLength = length > 280 ? 280 : length;
    for (var i = 0; i < displayLength; i++) {
      if (i > 0 && i % 5 == 0) buffer.write(' ');
      buffer.write(chars[(i * 7) % chars.length]);
    }
    return buffer.toString();
  }
}

// ── Reusable action button ────────────────────────────────────────────────────

class _SparkButton extends StatefulWidget {
  final bool isSparked;
  final int sparkCount;
  final VoidCallback onTap;

  const _SparkButton({
    required this.isSparked,
    required this.sparkCount,
    required this.onTap,
  });

  @override
  State<_SparkButton> createState() => _SparkButtonState();
}

class _SparkButtonState extends State<_SparkButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_SparkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSparked && !oldWidget.isSparked) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSparked
        ? const Color(0xFFFFD700)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                widget.isSparked ? Icons.bolt : Icons.bolt_outlined,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              widget.sparkCount > 0 ? '${widget.sparkCount}' : 'Spark',
              style: TextStyle(color: color, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              count > 0 ? '$count' : label,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

