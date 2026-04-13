import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:xparq_app/features/social/screens/orbit_screen.dart';
import 'package:xparq_app/features/radar/screens/radar_screen.dart';
import 'package:xparq_app/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:xparq_app/features/profile/screens/user_profile_screen.dart';
import 'package:xparq_app/features/radar/providers/radar_providers.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class ControlDeckScreen extends ConsumerStatefulWidget {
  const ControlDeckScreen({super.key});

  @override
  ConsumerState<ControlDeckScreen> createState() => _ControlDeckScreenState();
}

class ControlDeckProvider extends InheritedWidget {
  final PageController pageController;

  const ControlDeckProvider({
    super.key,
    required this.pageController,
    required super.child,
  });

  static ControlDeckProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ControlDeckProvider>();
  }

  @override
  bool updateShouldNotify(ControlDeckProvider oldWidget) {
    return pageController != oldWidget.pageController;
  }
}

class _ControlDeckScreenState extends ConsumerState<ControlDeckScreen> {
  int _currentIndex = 1; // Default to Radar (at index 1)
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(radarNotifierProvider.notifier).refreshLocationIfPermitted();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<Widget> _screens = [
    const OrbitScreen(),
    const RadarScreen(),
    const ChatListScreen(),
    const UserProfileScreen(),
  ];

  void _onTabTapped(int index) {
    if ((index - _currentIndex).abs() > 1) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return ControlDeckProvider(
      pageController: _pageController,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
                Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 72, // Increased from 64 to 72 to prevent overflow
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _CustomNavItem(
                    icon: Icons.public_outlined,
                    activeIcon: Icons.public,
                    label: AppLocalizations.of(context)!.orbitTab,
                    isSelected: _currentIndex == 0,
                    onTap: () => _onTabTapped(0),
                  ),
                  _CustomNavItem(
                    icon: Icons.radar,
                    activeIcon: Icons.radar,
                    label: AppLocalizations.of(context)!.radarTab,
                    isSelected: _currentIndex == 1,
                    onTap: () => _onTabTapped(1),
                  ),
                  _CustomNavItem(
                    icon: Icons.chat_bubble_outline,
                    activeIcon: Icons.chat_bubble,
                    label: AppLocalizations.of(context)!.signalTab,
                    isSelected: _currentIndex == 2,
                    onTap: () => _onTabTapped(2),
                    badgeCount: ref.watch(totalUnreadCountProvider),
                  ),
                  _CustomNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: AppLocalizations.of(context)!.planetTab,
                    isSelected: _currentIndex == 3,
                    onTap: () => _onTabTapped(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  const _CustomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark
        ? theme.bottomNavigationBarTheme.selectedItemColor
        : theme.colorScheme.primary;
    final inactiveColor = theme.bottomNavigationBarTheme.unselectedItemColor;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.25 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      transform: isSelected
                          ? (Matrix4.identity()..translateByVector3(
                              Vector3(0.0, -2.0, 0.0),
                            )) // Slight lift
                          : Matrix4.identity(),
                      child: Icon(
                        isSelected ? activeIcon : icon,
                        color: isSelected ? activeColor : inactiveColor,
                        size: 26,
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (isSelected)
                AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
