// lib/features/radar/screens/radar_screen.dart
//
// Radar Screen: Shows nearby iXPARQs in online (GPS) or offline (BLE) mode.
// Theme: Orbital/galaxy view with distance in "light-years".

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/core/router/app_router.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';
import 'package:xparq_app/features/radar/models/radar_xparq_model.dart';
import 'package:xparq_app/features/radar/providers/radar_providers.dart';
import 'package:xparq_app/core/widgets/xparq_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _pulseController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedInterest = 'All';
  bool _isFilterExpanded = false; // State to track expansion

  @override
  bool get wantKeepAlive => true;

  final List<String> _interests = [
    'All',
    'Music',
    'Gaming',
    'Art',
    'Tech',
    'Sports',
    'Food',
    'Travel',
    'Finance',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Auto-scan on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(radarNotifierProvider.notifier).scanOnline();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(radarNotifierProvider);
    final notifier = ref.read(radarNotifierProvider.notifier);
    final currentUid = ref.read(authRepositoryProvider).currentUser?.id;
    final l10n = AppLocalizations.of(context)!;
    final orbitingStatusAsync = ref.watch(myOrbitingStatusProvider);
    final orbitingStatus = orbitingStatusAsync.valueOrNull ?? {};

    // X Theme Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final searchBarColor = isDark
        ? const Color(0xFF202327)
        : const Color(0xFFEFF3F4);
    final primaryColor = const Color(0xFF1D9BF0); // X Blue
    final secondaryColor = const Color(
      0xFFF91880,
    ); // X Pink (for offline/bluetooth distinction)
    final textSecondary = isDark
        ? const Color(0xFF71767B)
        : const Color(0xFF536471);

    // Filter lists
    final onlineFiltered = state.onlineXparqs.where((s) {
      final matchesSearch = s.planet.xparqName.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesInterest =
          _selectedInterest == 'All' ||
          s.planet.constellations.contains(_selectedInterest);
      return matchesSearch && matchesInterest;
    }).toList();

    final searchFiltered = state.searchResults.where((s) {
      final matchesSearch = s.planet.xparqName.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesInterest =
          _selectedInterest == 'All' ||
          s.planet.constellations.contains(_selectedInterest);
      return matchesSearch && matchesInterest;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(
            left: 16,
          ), // Left padding for search bar
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: searchBarColor,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search, color: textSecondary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                    ),
                    cursorColor: primaryColor,
                    textInputAction:
                        TextInputAction.search, // Show search button
                    decoration: InputDecoration(
                      hintText: l10n.radarSearchHint,
                      hintStyle: TextStyle(color: textSecondary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      // Local filter update
                      setState(() => _searchQuery = val);
                      // Clear global results if query cleared
                      if (val.isEmpty) {
                        notifier.searchUsers('');
                      }
                    },
                    onSubmitted: (val) {
                      // Trigger global search
                      if (val.isNotEmpty) {
                        notifier.searchUsers(val);
                      }
                    },
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      notifier.searchUsers(''); // Clear global results
                    },
                    child: Icon(Icons.close, color: textSecondary, size: 18),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          // Mode Switch Button (Consolidated) - Hidden on Web
          if (!kIsWeb)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: searchBarColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: state.mode == RadarMode.online
                      ? primaryColor.withOpacity(0.5)
                      : secondaryColor.withOpacity(0.5),
                ),
              ),
              child: IconButton(
                icon: Icon(
                  state.mode == RadarMode.online ? Icons.wifi : Icons.bluetooth,
                  color: state.mode == RadarMode.online
                      ? primaryColor
                      : secondaryColor,
                  size: 20,
                ),
                onPressed: () {
                  notifier.setMode(
                    state.mode == RadarMode.online
                        ? RadarMode.offline
                        : RadarMode.online,
                  );
                },
                tooltip: state.mode == RadarMode.online
                    ? l10n.radarModeMeshTooltip
                    : l10n.radarModeOnlineTooltip,
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                // 1. Collapsible/Expandable Core
                GestureDetector(
                  onTap: () =>
                      setState(() => _isFilterExpanded = !_isFilterExpanded),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _isFilterExpanded
                          ? Colors.transparent
                          : Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isFilterExpanded
                            ? primaryColor
                            : primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isFilterExpanded ? Icons.close : Icons.filter_list,
                          size: 16,
                          color: primaryColor,
                        ),
                        if (!_isFilterExpanded) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _selectedInterest,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // 2. The Expanding List
                Expanded(
                  child: AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Container(
                      height: 32,
                      margin: const EdgeInsetsDirectional.only(start: 8),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics:
                            const ClampingScrollPhysics(), // Prevents nested scroll issues
                        itemCount: _interests.length,
                        itemBuilder: (context, index) {
                          final interest = _interests[index];
                          final isSelected = _selectedInterest == interest;
                          return Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: FilterChip(
                              label: Text(
                                interest,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white
                                      : textSecondary,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (val) {
                                setState(() {
                                  _selectedInterest = interest;
                                  _isFilterExpanded =
                                      false; // Auto-collapse on select
                                });
                              },
                              backgroundColor: Colors.transparent,
                              selectedColor: primaryColor,
                              checkmarkColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? primaryColor
                                      : textSecondary.withOpacity(0.2),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    crossFadeState: _isFilterExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Radar Pulse Animation + Stats
          SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 2.5,
                panEnabled: false,
                boundaryMargin: const EdgeInsets.all(20),
                child: _RadarPulseHeader(
                  controller: _pulseController,
                  mode: state.mode,
                  count: state.mode == RadarMode.online
                      ? onlineFiltered.length
                      : 0,
                  radiusKm: state.radiusKm,
                  isLoading: state.isLoading,
                  xparqs: state.mode == RadarMode.online ? onlineFiltered : [],
                ),
              ),
            ),
          ),

          // Error Banner
          if (state.errorMessage != null)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                color: Colors.red.withOpacity(0.15),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  '⚠️ ${state.errorMessage}',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ),

          // iXPARQ List (Slivers)
          if (state.isLoading || state.isSearching)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1D9BF0)),
              ),
            )
          else if (_searchQuery.isNotEmpty && searchFiltered.isNotEmpty)
            _OnlineXparqSliverList(
              xparqs: searchFiltered,
              onExpand: () {},
              isSearchResult: true,
              currentUid: currentUid,
              orbitingStatus: orbitingStatus,
            )
          else if (state.mode == RadarMode.online)
            _OnlineXparqSliverList(
              xparqs: onlineFiltered,
              onExpand: notifier.expandRadius,
              currentUid: currentUid,
              orbitingStatus: orbitingStatus,
            )
          else
            SliverToBoxAdapter(
              child: _OfflineXparqList(xparqs: state.offlineXparqs),
            ),
        ],
      ),

      // Refresh FAB
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (state.mode == RadarMode.online) {
            notifier.scanOnline();
          } else {
            notifier.startOfflineScan();
          }
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}

// ── Radar Pulse Header ────────────────────────────────────────────────────────

class _RadarPulseHeader extends StatelessWidget {
  final AnimationController controller;
  final RadarMode mode;
  final int count;
  final double radiusKm;
  final bool isLoading;

  final List<RadarXparq> xparqs;

  const _RadarPulseHeader({
    required this.controller,
    required this.mode,
    required this.count,
    required this.radiusKm,
    required this.isLoading,
    this.xparqs = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse rings
          AnimatedBuilder(
            animation: controller,
            builder: (_, child) => CustomPaint(
              size: const Size(200, 200),
              painter: _PulsePainter(
                progress: controller.value,
                mode: mode,
                xparqs: xparqs,
                maxRadiusKm: radiusKm,
              ),
            ),
          ),
          // Center info
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mode == RadarMode.online ? '🛸' : '📡',
                style: TextStyle(fontSize: 28),
              ),
              Text(
                '$count ${AppLocalizations.of(context)!.radarXparqsCount}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                mode == RadarMode.online
                    ? '${radiusKm < 1000 ? "${radiusKm.toStringAsFixed(0)}km" : AppLocalizations.of(context)!.radarRadiusGlobal} ${AppLocalizations.of(context)!.radarRadiusLabel}'
                    : AppLocalizations.of(context)!.radarBluetoothRange,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.54),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;
  final RadarMode mode;
  final List<RadarXparq> xparqs;
  final double maxRadiusKm;

  _PulsePainter({
    required this.progress,
    required this.mode,
    this.xparqs = const [],
    required this.maxRadiusKm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = mode == RadarMode.online
        ? const Color(0xFF1D9BF0)
        : const Color(0xFFF91880);
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2;

    // 1. Draw Pulsing Rings
    for (int i = 0; i < 3; i++) {
      final r = baseRadius * ((i + progress) / 3);
      final opacity = (1 - (i + progress) / 3).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = color.withOpacity(opacity * 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // 2. Draw Xparq Particles (Icon Layer)
    if (mode == RadarMode.online && xparqs.isNotEmpty) {
      for (final xparq in xparqs) {
        // Deterministic angle based on UID
        final angle = xparq.planet.id.hashCode.toDouble();
        // Normalized distance (0.0 to 1.0)
        final distanceRatio = (xparq.distanceMeters / 1000 / maxRadiusKm).clamp(
          0.0,
          1.0,
        );
        final r = baseRadius * 0.3 + (distanceRatio * baseRadius * 0.6);

        final offset = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );

        // Particle shadow/glow
        canvas.drawCircle(
          offset,
          4,
          Paint()
            ..color = color.withOpacity(0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );

        // Particle core
        canvas.drawCircle(offset, 2.5, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.progress != progress || old.xparqs != xparqs;
}

// ── Online iXPARQ List ─────────────────────────────────────────────────────────

class _OnlineXparqSliverList extends StatelessWidget {
  final List<RadarXparq> xparqs;
  final VoidCallback onExpand;
  final bool isSearchResult;
  final String? currentUid;
  final Map<String, String> orbitingStatus;

  const _OnlineXparqSliverList({
    required this.xparqs,
    required this.onExpand,
    this.isSearchResult = false,
    this.currentUid,
    this.orbitingStatus = const {},
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF1D9BF0);

    if (xparqs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🌌', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.radarNoNearby,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              SizedBox(height: 16),
              OutlinedButton.icon(
                icon: Icon(Icons.expand_more, color: primaryColor),
                label: Text(
                  isSearchResult
                      ? AppLocalizations.of(context)!.radarNoUsersFound
                      : AppLocalizations.of(context)!.radarExpandRadius,
                  style: TextStyle(color: primaryColor),
                ),
                onPressed: isSearchResult ? null : onExpand,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor),
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
                  icon: Icon(Icons.expand_more, color: primaryColor),
                  label: Text(
                    'Expand Radius',
                    style: TextStyle(color: primaryColor),
                  ),
                ),
              ),
            );
          }
          return _OnlineXparqCard(
            xparq: xparqs[index],
            isMe: currentUid != null && xparqs[index].planet.id == currentUid,
            orbitStatus: orbitingStatus[xparqs[index].planet.id],
          );
        }, childCount: xparqs.length + 1),
      ),
    );
  }
}

class _OnlineXparqCard extends ConsumerStatefulWidget {
  final RadarXparq xparq;
  final bool isMe;
  final String? orbitStatus; // 'pending', 'accepted', or null

  const _OnlineXparqCard({
    required this.xparq,
    this.isMe = false,
    this.orbitStatus,
  });

  @override
  ConsumerState<_OnlineXparqCard> createState() => _OnlineXparqCardState();
}

class _OnlineXparqCardState extends ConsumerState<_OnlineXparqCard> {
  bool _isPendingOptimistic = false;

  @override
  void didUpdateWidget(covariant _OnlineXparqCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.orbitStatus != null &&
        widget.orbitStatus != oldWidget.orbitStatus) {
      _isPendingOptimistic = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use unified isOnline check (30 mins timeout)
    final isStrictlyOnline = widget.xparq.isOnline;

    // Merge real status with optimistic status
    final currentStatus = _isPendingOptimistic ? 'pending' : widget.orbitStatus;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.12);
    final textSecondary = isDark
        ? const Color(0xFF71767B)
        : const Color(0xFF536471);
    final primaryColor = const Color(0xFF1D9BF0);

    return Card(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          0,
        ), // X uses simpler lists, but keeping slight radius is fine or go 0 for pure list
        side: BorderSide(color: borderColor),
      ),
      margin: const EdgeInsets.only(bottom: 0), // X style lists usually touch
      child: InkWell(
        onTap: () =>
            context.push('${AppRoutes.otherProfile}/${widget.xparq.planet.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
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
              SizedBox(width: 14),
              // Info
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
                          SizedBox(width: 4),
                          Icon(Icons.verified, color: primaryColor, size: 14),
                        ],
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.xparq.galacticDistance,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    if (widget.xparq.planet.constellations.isNotEmpty) ...[
                      SizedBox(height: 6),
                      Text(
                        widget.xparq.planet.constellations.take(3).join('  '),
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              // Action / Indicator
              if (widget.isMe) ...[
                if (isStrictlyOnline)
                  // Me & Online: Show Green dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4CAF50),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
              ] else ...[
                // Not Me
                if (currentStatus == null)
                  // Not in orbit: Show Send Request button
                  IconButton(
                    icon: Icon(Icons.person_add, color: primaryColor, size: 20),
                    onPressed: () {
                      if (widget.isMe) return; // Safety check
                      setState(() => _isPendingOptimistic = true);
                      final myUid = ref
                          .read(authRepositoryProvider)
                          .currentUser
                          ?.id;
                      if (myUid != null) {
                        ref
                            .read(orbitRepositoryProvider)
                            .sendOrbitRequest(myUid, widget.xparq.planet.id);
                      }
                    },
                  )
                else if (currentStatus == 'pending')
                  // Pending Request
                  Padding(
                    padding: EdgeInsetsDirectional.only(end: 8),
                    child: Icon(
                      Icons.hourglass_empty,
                      color: textSecondary,
                      size: 20,
                    ),
                  )
                else if (currentStatus == 'accepted')
                  // Accepted (Friend)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isStrictlyOnline)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsetsDirectional.only(end: 8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      Icon(Icons.check_circle, color: primaryColor, size: 20),
                    ],
                  )
                else if (isStrictlyOnline)
                  // Me or Online Status only
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4CAF50),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Offline BLE iXPARQ List ────────────────────────────────────────────────────

class _OfflineXparqList extends StatelessWidget {
  final List<dynamic> xparqs;
  const _OfflineXparqList({required this.xparqs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? const Color(0xFF71767B)
        : const Color(0xFF536471);
    final accentColor = const Color(0xFFF91880); // Pink for Bluetooth

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📡', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.radarOfflineTitle,
            style: TextStyle(color: textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.radarOfflineSubtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.arrow_forward_rounded),
            label: Text(AppLocalizations.of(context)!.offlineDashboard),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              context.push('/offline/permission');
            },
          ),
        ],
      ),
    );
  }
}
