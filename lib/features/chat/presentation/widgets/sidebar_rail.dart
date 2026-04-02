// lib/features/chat/widgets/sidebar_rail.dart

import 'package:flutter/material.dart';
import 'package:xparq_app/features/chat/presentation/widgets/signal_sidebar.dart';

class SidebarRail extends StatelessWidget {
  final String myUid;
  final bool isCollapsed;
  final VoidCallback onToggle;

  const SidebarRail({
    super.key,
    required this.myUid,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: isCollapsed ? 151.5 : 300,
          child: ClipRect(
            child: OverflowBox(
              minWidth: 300,
              maxWidth: 300,
              alignment: AlignmentDirectional.centerStart,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isCollapsed ? 0.4 : 1.0,
                child: SignalSidebar(myUid: myUid, isDrawer: false),
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VerticalDivider(
                width: 24,
                thickness: 1,
                color: Theme.of(context).dividerColor,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 2,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
