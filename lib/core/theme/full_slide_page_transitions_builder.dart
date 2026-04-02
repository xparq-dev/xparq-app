import 'package:flutter/material.dart';

class FullSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FullSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // slide in from right
    final inAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.fastLinearToSlowEaseIn,
            reverseCurve: Curves.fastOutSlowIn,
          ),
        );

    // slide out to left
    final outAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-1.0, 0.0)).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.fastLinearToSlowEaseIn,
            reverseCurve: Curves.fastOutSlowIn,
          ),
        );

    return _SwipeBackRecognizer(
      route: route,
      child: SlideTransition(
        position: outAnimation,
        child: SlideTransition(position: inAnimation, child: child),
      ),
    );
  }
}

class _SwipeBackRecognizer<T> extends StatelessWidget {
  final PageRoute<T> route;
  final Widget child;

  const _SwipeBackRecognizer({required this.route, required this.child});

  @override
  Widget build(BuildContext context) {
    // Only apply the completely manual swipe back behavior if we are on iOS
    // or if we explicitly want to support it. Using right swipe on left edge.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        // Detect swiping right from the left edge (e.g. within 50 pixels)
        if (details.globalPosition.dx < 50 && details.primaryDelta! > 5) {
          if (route.navigator?.canPop() ?? false) {
            route.navigator?.pop();
          }
        }
      },
      child: child,
    );
  }
}
