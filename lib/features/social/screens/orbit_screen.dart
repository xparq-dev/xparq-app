import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';
import 'package:xparq_app/features/social/providers/pulse_providers.dart';
import 'package:xparq_app/features/social/widgets/pulse_card.dart';
import 'package:xparq_app/features/social/widgets/supernova_bar.dart';
import 'package:xparq_app/features/social/screens/orbit_requests_screen.dart';

class OrbitScreen extends ConsumerStatefulWidget {
  const OrbitScreen({super.key});

  @override
  ConsumerState<OrbitScreen> createState() => _OrbitScreenState();
}

class _OrbitScreenState extends ConsumerState<OrbitScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isFabVisible = true;
  double _overscroll = 0;

  // Speed Dial Menu
  late AnimationController _menuController;
  bool _isMenuOpen = false; // intent — flips immediately on tap
  bool _isMenuVisible =
      false; // visibility — stays true until animation dismisses

  // Draggable FAB position
  bool _fabOnLeft = false; // false = right side (default)
  double _fabDragDx = 0; // live horizontal drag offset

  static const String _kFabSidePref = 'fab_on_left';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _menuController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() => _isMenuVisible = false);
      }
    });
    // Load saved FAB side preference
    _loadFabSide();
  }

  Future<void> _loadFabSide() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final onLeft = prefs.getBool(_kFabSidePref) ?? false;
      if (mounted) setState(() => _fabOnLeft = onLeft);
    } catch (_) {}
  }

  Future<void> _saveFabSide(bool onLeft) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(_kFabSidePref, onLeft);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _menuController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_isFabVisible) setState(() => _isFabVisible = false);
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!_isFabVisible) setState(() => _isFabVisible = true);
    }
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _isMenuVisible = true; // show immediately before animation starts
        _menuController.forward();
      } else {
        _menuController
            .reverse(); // hide only after animation ends (via listener)
      }
    });
  }

  // Keep BottomSheet for landscape only
  void _showSupernovaMenuLandscape(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: 12,
                left: 24,
                right: 24,
                bottom: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.orbitSupernovaMenuTitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _buildMenuItems(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<_LaunchMenuItem> _buildMenuItems(BuildContext context) {
    return [
      _LaunchMenuItem(
        icon: Icons.edit,
        label: AppLocalizations.of(context)!.orbitNewPulse,
        color: const Color(0xFF4FC3F7),
        onTap: () {
          if (_isMenuOpen) _toggleMenu();
          Navigator.pop(context);
          context.pushNamed('createPulse', extra: {'isSupernova': false});
        },
      ),
      _LaunchMenuItem(
        icon: Icons.camera_alt,
        label: AppLocalizations.of(context)!.orbitQuickPhoto,
        color: const Color(0xFF81C784),
        onTap: () {
          if (_isMenuOpen) _toggleMenu();
          Navigator.pop(context);
          context.pushNamed('camera', extra: {'mode': 'photo'});
        },
      ),
      _LaunchMenuItem(
        icon: Icons.videocam,
        label: AppLocalizations.of(context)!.orbitQuickVideo,
        color: const Color(0xFFFFA726),
        onTap: () {
          if (_isMenuOpen) _toggleMenu();
          Navigator.pop(context);
          context.pushNamed('camera', extra: {'mode': 'video'});
        },
      ),
      _LaunchMenuItem(
        icon: Icons.photo_library,
        label: AppLocalizations.of(context)!.orbitStarlight,
        color: const Color(0xFFCE93D8),
        onTap: () async {
          if (_isMenuOpen) _toggleMenu();
          final result =
              await context.pushNamed('nebulaPicker') as Map<String, dynamic>?;
          if (result != null && result['file'] != null && context.mounted) {
            final File file = result['file'] as File;
            final String mode = result['mode'] as String? ?? 'POST';
            final isSupernovaFromMode = mode == 'STORY';

            final isVideo =
                file.path.toLowerCase().endsWith('.mp4') ||
                file.path.toLowerCase().endsWith('.mov');
            context.pushNamed(
              'createPulse',
              extra: {
                'isSupernova': isSupernovaFromMode,
                if (isVideo) 'video': file else 'image': file,
              },
            );
          }
        },
      ),
      _LaunchMenuItem(
        icon: Icons.auto_awesome,
        label: AppLocalizations.of(context)!.orbitSupernova,
        color: const Color(0xFFFFB74D),
        onTap: () async {
          if (_isMenuOpen) _toggleMenu();
          Navigator.pop(context); // Close the landscape BottomSheet
          context.pushNamed('nebulaPicker');
        },
      ),
      _LaunchMenuItem(
        icon: Icons.sensors,
        label: AppLocalizations.of(context)!.orbitPulseLive,
        color: const Color(0xFFE57373),
        onTap: () {
          if (_isMenuOpen) _toggleMenu();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.orbitComingSoon('Pulse Live'),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
      _LaunchMenuItem(
        icon: Icons.bolt,
        label: AppLocalizations.of(context)!.orbitFlash,
        color: const Color(0xFFBA68C8),
        onTap: () {
          if (_isMenuOpen) _toggleMenu();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.orbitComingSoon('Flash'),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    ];
  }

  // Build a single speed-dial item: [label pill] [icon circle] (mirrors when FAB is on left)
  Widget _buildSpeedDialItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required int index,
    required int total,
  }) {
    final reverseIndex = total - 1 - index;
    final start = (reverseIndex * 0.07).clamp(0.0, 0.55);
    final end = (start + 0.45).clamp(0.1, 1.0);
    final itemAnim = CurvedAnimation(
      parent: _menuController,
      curve: Interval(start, end, curve: Curves.easeOutQuint),
      reverseCurve: Interval(
        (index * 0.05).clamp(0.0, 0.5),
        ((index * 0.05) + 0.5).clamp(0.1, 1.0),
        curve: Curves.easeInCubic,
      ),
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tonedColor = isDark
        ? color
        : Color.lerp(color, const Color(0xFF1F2937), 0.18)!;

    // Icon widget
    final iconWidget = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: tonedColor.withValues(alpha: isDark ? 0.15 : 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: tonedColor.withValues(alpha: isDark ? 0.30 : 0.22),
            width: 1,
          ),
        ),
        child: Icon(icon, color: tonedColor, size: 20),
      ),
    );

    // Label widget
    final labelWidget = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: isDark
              ? null
              : Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: itemAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 28 * (1 - itemAnim.value)),
        child: Opacity(opacity: itemAnim.value.clamp(0.0, 1.0), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          // Mirror: when FAB is on left → icon on left, label on right
          children: _fabOnLeft
              ? [iconWidget, const SizedBox(width: 8), labelWidget]
              : [labelWidget, const SizedBox(width: 8), iconWidget],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feedAsync = ref.watch(orbitFeedProvider);

    final scaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: () => context.push(AppRoutes.qrScanner),
        ),
        title: Text(
          AppLocalizations.of(context)!.orbitTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 19,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // Requests Button with Badge
          Consumer(
            builder: (context, ref, child) {
              final requestsAsync = ref.watch(incomingRequestsProvider);
              final count = requestsAsync.value?.length ?? 0;
              return IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OrbitRequestsScreen(),
                    ),
                  );
                },
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: Icon(Icons.group_add),
                ),
              );
            },
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {
                Scaffold.of(ctx).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.5,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: const _NotificationsPanel(),
      ),
      body: RefreshIndicator(
        displacement: 20.0,
        onRefresh: () async {
          return ref.refresh(orbitFeedProvider.future);
        },
        color: const Color(0xFF4FC3F7),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Track overscroll amount specifically when pulling DOWN from the top
            if (notification is ScrollUpdateNotification) {
              if (notification.metrics.pixels < 0) {
                final newValue = notification.metrics.pixels.abs();
                if ((_overscroll - newValue).abs() > 2.0) {
                  setState(() => _overscroll = newValue);
                }
              } else if (_overscroll > 0) {
                setState(() => _overscroll = 0);
              }
            } else if (notification is ScrollEndNotification) {
              if (_overscroll > 0) {
                setState(() => _overscroll = 0);
              }
            }
            return false;
          },
          child: Stack(
            children: [
              // 1. The main content
              feedAsync.when(
                data: (pulses) {
                  if (pulses.isEmpty) {
                    return CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.rocket_launch,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.24),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  AppLocalizations.of(context)!.orbitEmptyTitle,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.54),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.orbitEmptySubtitle,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.38),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: pulses.length + 1, // +1 for SupernovaBar
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const SupernovaBar();
                      }
                      return PulseCard(pulse: pulses[index - 1]);
                    },
                  );
                },
                loading: () => const CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4FC3F7),
                        ),
                      ),
                    ),
                  ],
                ),
                error: (err, stack) => CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          AppLocalizations.of(
                            context,
                          )!.orbitSignalLost(err.toString()),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.54),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. The blur overlay for overscroll
              if (_overscroll > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: (_overscroll / 15).clamp(0.0, 15.0),
                        sigmaY: (_overscroll / 15).clamp(0.0, 15.0),
                      ),
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor
                            .withValues(alpha: (_overscroll / 200).clamp(0.0, 0.6)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // Build the radial fan overlay (portrait only)
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Stack(
      children: [
        scaffold,

        // Backdrop when menu is open
        if (_isMenuOpen && !isLandscape)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleMenu,
              child: AnimatedBuilder(
                animation: _menuController,
                builder: (context, child) => Container(
                  color: Colors.black.withValues(alpha: (_menuController.value * 0.4).clamp(0.0, 1.0)),
                ),
              ),
            ),
          ),

        // Speed Dial items — positioned on the same side as FAB
        if (_isMenuVisible && !isLandscape)
          Positioned(
            left: _fabOnLeft ? 8 : null,
            right: _fabOnLeft ? null : 8,
            bottom: 72,
            child: _buildSpeedDial(context),
          ),

        // The FAB layer — draggable left/right
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          left: _fabOnLeft ? 16 + _fabDragDx.clamp(-150.0, 150.0) : null,
          right: _fabOnLeft ? null : 16 + (-_fabDragDx).clamp(-150.0, 150.0),
          bottom: 8,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 300),
            offset: _isFabVisible ? Offset.zero : const Offset(0, 2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isFabVisible ? 1.0 : 0.0,
              child: GestureDetector(
                // Drag to snap left/right
                onHorizontalDragUpdate: (d) {
                  // Track raw screen-space movement
                  setState(() => _fabDragDx += d.delta.dx);
                },
                onHorizontalDragEnd: (d) {
                  // Snap: dragged far enough OR flicked to opposite side
                  final vx = d.velocity.pixelsPerSecond.dx;
                  final shouldFlipToLeft =
                      !_fabOnLeft && (_fabDragDx < -60 || vx < -300);
                  final shouldFlipToRight =
                      _fabOnLeft && (_fabDragDx > 60 || vx > 300);
                  final newOnLeft = shouldFlipToLeft
                      ? true
                      : shouldFlipToRight
                      ? false
                      : _fabOnLeft;
                  setState(() {
                    _fabOnLeft = newOnLeft;
                    _fabDragDx = 0;
                    if (_isMenuOpen) _toggleMenu();
                  });
                  _saveFabSide(newOnLeft);
                },
                onHorizontalDragCancel: () => setState(() => _fabDragDx = 0),
                // Tap to open menu
                onTap: () {
                  if (isLandscape) {
                    _showSupernovaMenuLandscape(context);
                  } else {
                    _toggleMenu();
                  }
                },
                child: FloatingActionButton(
                  onPressed: null, // handled by GestureDetector above
                  elevation: 0,
                  highlightElevation: 0,
                  focusElevation: 0,
                  hoverElevation: 0,
                  disabledElevation: 0,
                  backgroundColor: _isMenuOpen
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: AnimatedRotation(
                    turns: _isMenuOpen ? 0.125 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _isMenuOpen ? Icons.close : Icons.rocket_launch,
                      color: _isMenuOpen
                          ? Theme.of(context).colorScheme.onErrorContainer
                          : Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDial(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final launchColors = isDark
        ? const [
            Color(0xFF4FC3F7),
            Color(0xFF81C784),
            Color(0xFFFFA726),
            Color(0xFFCE93D8),
            Color(0xFFFFB74D),
            Color(0xFFE57373),
            Color(0xFFBA68C8),
          ]
        : const [
            Color(0xFF3B9ED9),
            Color(0xFF6FAE7D),
            Color(0xFFD09553),
            Color(0xFFA98BC7),
            Color(0xFFC6A061),
            Color(0xFFC77A7A),
            Color(0xFF9D80C2),
          ];

    final items = [
      {
        'icon': Icons.edit,
        'label': AppLocalizations.of(context)!.orbitNewPulse,
        'color': launchColors[0],
      },
      {
        'icon': Icons.camera_alt,
        'label': AppLocalizations.of(context)!.orbitQuickPhoto,
        'color': launchColors[1],
      },
      {
        'icon': Icons.videocam,
        'label': AppLocalizations.of(context)!.orbitQuickVideo,
        'color': launchColors[2],
      },
      {
        'icon': Icons.photo_library,
        'label': AppLocalizations.of(context)!.orbitStarlight,
        'color': launchColors[3],
      },
      {
        'icon': Icons.auto_awesome,
        'label': AppLocalizations.of(context)!.orbitSupernova,
        'color': launchColors[4],
      },
      {
        'icon': Icons.sensors,
        'label': AppLocalizations.of(context)!.orbitPulseLive,
        'color': launchColors[5],
      },
      {
        'icon': Icons.bolt,
        'label': AppLocalizations.of(context)!.orbitFlash,
        'color': launchColors[6],
      },
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      // Align rows from the icon edge: end when on right, start when on left
      crossAxisAlignment: _fabOnLeft
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: List.generate(items.length, (index) {
        final item = items[index];
        return _buildSpeedDialItem(
          context: context,
          icon: item['icon'] as IconData,
          label: item['label'] as String,
          color: item['color'] as Color,
          index: index,
          total: items.length,
          onTap: () => _onRadialItemTap(context, index),
        );
      }),
    );
  }

  Future<void> _onRadialItemTap(BuildContext context, int index) async {
    _toggleMenu();
    switch (index) {
      case 0: // New Pulse (Text Post)
        context.pushNamed('createPulse', extra: {'isSupernova': false});
        break;
      case 1: // Quick Photo
        context.pushNamed('camera', extra: {'mode': 'photo'});
        break;
      case 2: // Quick Video
        context.pushNamed('camera', extra: {'mode': 'video'});
        break;
      case 3: // Starlight (In-app Picker)
        _openNebulaPicker(context, isSupernova: false);
        break;
      case 4: // Supernova (In-app Picker)
        _openNebulaPicker(context, isSupernova: true);
        break;
      case 5: // Pulse Live
        _showComingSoon(context, AppLocalizations.of(context)!.orbitPulseLive);
        break;
      case 6: // Flash
        _showComingSoon(context, AppLocalizations.of(context)!.orbitFlash);
        break;
    }
  }

  Future<void> _openNebulaPicker(
    BuildContext context, {
    required bool isSupernova,
  }) async {
    final result = await context.pushNamed('nebulaPicker');
    if (result != null &&
        result is Map &&
        result['file'] != null &&
        context.mounted) {
      final file = result['file'] as File;
      final isVideo =
          file.path.toLowerCase().endsWith('.mp4') ||
          file.path.toLowerCase().endsWith('.mov');
      context.pushNamed(
        'createPulse',
        extra: {
          'isSupernova': isSupernova,
          if (isVideo) 'video': file else 'image': file,
        },
      );
    }
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.orbitComingSoon(feature)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Notifications Panel (Half-Screen Drawer) ──────────────────────────────────

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.settingsNotificationsTitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: 5, // Mock data
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.05),
              ),
              itemBuilder: (context, index) {
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.star,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    AppLocalizations.of(
                      context,
                    )!.orbitComingSoon('Notifications'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${index + 2}h',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Launch Menu Item ──────────────────────────────────────────────────────────

class _LaunchMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LaunchMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isLandscape ? 12 : 16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isLandscape ? 22 : 28),
          ),
          SizedBox(height: isLandscape ? 4 : 8),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: isLandscape ? 10 : 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

