// lib/features/radar/widgets/online_xparq_components.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/radar/models/radar_xparq_model.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';

class OnlineXparqSliverList extends StatelessWidget {
  final List<RadarXparq> xparqs;
  final VoidCallback onExpand;
  final bool isSearchResult;
  final String? currentUid;
  final Map<String, String> orbitingStatus;

  const OnlineXparqSliverList({
    super.key,
    required this.xparqs,
    required this.onExpand,
    this.isSearchResult = false,
    this.currentUid,
    this.orbitingStatus = const {},
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1D9BF0);

    if (xparqs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌌', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.radarNoNearby,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.expand_more, color: primaryColor),
                label: Text(
                  isSearchResult
                      ? AppLocalizations.of(context)!.radarNoUsersFound
                      : AppLocalizations.of(context)!.radarExpandRadius,
                  style: const TextStyle(color: primaryColor),
                ),
                onPressed: isSearchResult ? null : onExpand,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primaryColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == xparqs.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: TextButton.icon(
                  onPressed: onExpand,
                  icon: const Icon(Icons.expand_more, color: primaryColor),
                  label: const Text(
                    'Expand Radius',
                    style: TextStyle(color: primaryColor),
                  ),
                ),
              ),
            );
          }
          return OnlineXparqCard(
            xparq: xparqs[index],
            isMe: currentUid != null && xparqs[index].planet.id == currentUid,
            orbitStatus: orbitingStatus[xparqs[index].planet.id],
          );
        }, childCount: xparqs.length + 1),
      ),
    );
  }
}

class OnlineXparqCard extends ConsumerStatefulWidget {
  final RadarXparq xparq;
  final bool isMe;
  final String? orbitStatus;

  const OnlineXparqCard({
    super.key,
    required this.xparq,
    this.isMe = false,
    this.orbitStatus,
  });

  @override
  ConsumerState<OnlineXparqCard> createState() => _OnlineXparqCardState();
}

class _OnlineXparqCardState extends ConsumerState<OnlineXparqCard> {
  bool _isPendingOptimistic = false;

  @override
  void didUpdateWidget(covariant OnlineXparqCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.orbitStatus != null &&
        widget.orbitStatus != oldWidget.orbitStatus) {
      _isPendingOptimistic = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStrictlyOnline = widget.xparq.isOnline;
    final currentStatus = _isPendingOptimistic ? 'pending' : widget.orbitStatus;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
    final textSecondary = isDark
        ? const Color(0xFF71767B)
        : const Color(0xFF536471);
    const primaryColor = Color(0xFF1D9BF0);

    return Card(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: BorderSide(color: borderColor),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () =>
            context.push('${AppRoutes.otherProfile}/${widget.xparq.planet.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark
                    ? const Color(0xFF202327)
                    : const Color(0xFFEFF3F4),
                backgroundImage: widget.xparq.planet.photoUrl.isNotEmpty
                    ? XparqImage.getImageProvider(widget.xparq.planet.photoUrl)
                    : null,
                child: widget.xparq.planet.photoUrl.isEmpty
                    ? Icon(Icons.person, color: textSecondary)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.xparq.planet.xparqName,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (widget.isMe)
                          Text(
                            ' (Me)',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        if (widget.xparq.planet.blueOrbit) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: primaryColor,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.xparq.galacticDistance,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    if (widget.xparq.planet.constellations.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.xparq.planet.constellations.take(3).join('  '),
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.isMe) ...[
                if (isStrictlyOnline) const OnlineIndicator(),
              ] else ...[
                if (currentStatus == null)
                  IconButton(
                    icon: const Icon(
                      Icons.person_add,
                      color: primaryColor,
                      size: 20,
                    ),
                    onPressed: () => _sendOrbitRequest(ref),
                  )
                else if (currentStatus == 'pending')
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Icon(
                      Icons.hourglass_empty,
                      color: textSecondary,
                      size: 20,
                    ),
                  )
                else if (currentStatus == 'accepted')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isStrictlyOnline)
                        const OnlineIndicator(
                          margin: EdgeInsetsDirectional.only(end: 8),
                          size: 8,
                        ),
                      const Icon(
                        Icons.check_circle,
                        color: primaryColor,
                        size: 20,
                      ),
                    ],
                  )
                else if (isStrictlyOnline)
                  const OnlineIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _sendOrbitRequest(WidgetRef ref) {
    if (widget.isMe) return;
    setState(() => _isPendingOptimistic = true);
    final myUid = ref.read(authRepositoryProvider).currentUser?.id;
    if (myUid != null) {
      ref
          .read(orbitRepositoryProvider)
          .sendOrbitRequest(myUid, widget.xparq.planet.id);
    }
  }
}

class OnlineIndicator extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  final double size;

  const OnlineIndicator({super.key, this.margin, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF4CAF50),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

