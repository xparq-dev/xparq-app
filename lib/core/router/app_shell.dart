// lib/core/router/app_shell.dart
//
// The main application shell: bottom navigation bar + navigation rail.
// Extracted from app_router.dart for separation of concerns.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/core/theme/theme_provider.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const AppShell({required this.navigationShell, required this.children, super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.navigationShell.currentIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIndex = widget.navigationShell.currentIndex;
    if (_pageController.hasClients &&
        _pageController.page?.round() != currentIndex) {
      _pageController.animateToPage(
        currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    if (index != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(
        index,
        initialLocation: false,
      );
    }
  }

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);

    final theme = Theme.of(context);
    final navTheme = theme.bottomNavigationBarTheme;
    final isDark = theme.brightness == Brightness.dark;
    final navBackgroundColor = isDark
        ? theme.colorScheme.surface.withOpacity(0.7)
        : (navTheme.backgroundColor ?? theme.colorScheme.surface);
    final navBottomPadding =
        MediaQuery.paddingOf(context).bottom.clamp(0.0, 14.0).toDouble();

    final screenWidth = MediaQuery.of(context).size.width;
    final bool useRail = screenWidth > 600;

    final List<({IconData icon, IconData activeIcon, String label})> navItems = [
      (
        icon: Icons.public_outlined,
        activeIcon: Icons.public,
        label: AppLocalizations.of(context)!.orbitTab,
      ),
      (
        icon: Icons.radar,
        activeIcon: Icons.radar,
        label: AppLocalizations.of(context)!.radarTab,
      ),
      (
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: AppLocalizations.of(context)!.signalTab,
      ),
      (
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: AppLocalizations.of(context)!.planetTab,
      ),
    ];

    final totalUnread = ref.watch(totalUnreadCountProvider);

    Widget shell = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: Row(
        children: [
          if (useRail)
            NavigationRail(
              selectedIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: _onTap,
              backgroundColor: navBackgroundColor,
              labelType: NavigationRailLabelType.all,
              indicatorColor: theme.colorScheme.primary.withOpacity(0.2),
              selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
              unselectedIconTheme: IconThemeData(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              selectedLabelTextStyle: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 11,
              ),
              destinations: navItems.map((item) {
                Widget icon = Icon(item.icon);
                Widget activeIcon = Icon(item.activeIcon);

                if (item.label == AppLocalizations.of(context)!.signalTab) {
                  icon = Badge(
                    label: Text(totalUnread.toString()),
                    isLabelVisible: totalUnread > 0,
                    child: icon,
                  );
                  activeIcon = Badge(
                    label: Text(totalUnread.toString()),
                    isLabelVisible: totalUnread > 0,
                    child: activeIcon,
                  );
                }

                return NavigationRailDestination(
                  icon: icon,
                  selectedIcon: activeIcon,
                  label: Text(item.label),
                );
              }).toList(),
            ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: useRail
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              children: widget.children,
            ),
          ),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: navBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.onSurface.withOpacity(0.06),
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: navBottomPadding),
                child: BottomNavigationBar(
                  currentIndex: widget.navigationShell.currentIndex,
                  onTap: _onTap,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedItemColor: navTheme.selectedItemColor,
                  unselectedItemColor: navTheme.unselectedItemColor,
                  type: BottomNavigationBarType.fixed,
                  showSelectedLabels: false,
                  showUnselectedLabels: false,
                  iconSize: 24,
                  items: navItems.map((item) {
                    Widget icon = Icon(item.icon);
                    Widget activeIcon = Icon(item.activeIcon);

                    if (item.label == AppLocalizations.of(context)!.signalTab) {
                      icon = Badge(
                        label: Text(totalUnread.toString()),
                        isLabelVisible: totalUnread > 0,
                        child: icon,
                      );
                      activeIcon = Badge(
                        label: Text(totalUnread.toString()),
                        isLabelVisible: totalUnread > 0,
                        child: activeIcon,
                      );
                    }

                    return BottomNavigationBarItem(
                      icon: icon,
                      activeIcon: activeIcon,
                      label: item.label,
                    );
                  }).toList(),
                ),
              ),
            ),
    );

    return RepaintBoundary(child: shell);
  }
}
