import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reaction_controller.dart';

/// A global layer that displays chat reaction animations (hearts and sparks).
/// This should be placed at the root of the chat screen.
class ReactionOverlayLayer extends ConsumerWidget {
  final Widget child;
  const ReactionOverlayLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactions = ref.watch(reactionControllerProvider);
    
    return Stack(
      children: [
        // The actual chat UI
        child,
        
        // The reaction animations layer
        ...reactions.map((event) => _IndividualReaction(
          key: ValueKey(event.id),
          event: event,
        )),
      ],
    );
  }
}

class _IndividualReaction extends StatefulWidget {
  final ReactionEvent event;
  const _IndividualReaction({super.key, required this.event});

  @override
  State<_IndividualReaction> createState() => _IndividualReactionState();
}

class _IndividualReactionState extends State<_IndividualReaction> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final math.Random _random = math.Random();
  final List<Offset> _sparkOffsets = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
    
    // For sparks, generate unique random trajectories
    if (widget.event.type == ReactionType.spark) {
      for (int i = 0; i < 3; i++) {
        _sparkOffsets.add(Offset(
          (_random.nextDouble() - 0.5) * 120, // Wider horizontal spread
          -50 - _random.nextDouble() * 150    // Upward velocity
        ));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        if (widget.event.type == ReactionType.heart) {
          return _buildHeart(progress);
        } else {
          return _buildSparks(progress);
        }
      },
    );
  }

  Widget _buildHeart(double progress) {
    // Advanced math for physics-based movement
    final double opacity = (progress < 0.15 ? progress * 6.67 : (progress > 0.8 ? (1 - progress) * 5.0 : 1.0)).clamp(0.0, 1.0);
    final double scale = (progress < 0.25 ? progress * 4.0 : (progress > 0.6 ? 1.0 - (progress - 0.6) * 0.5 : 1.0));
    
    // Rise up and sway left/right
    final double dy = widget.event.position.dy + (-120 * progress) - (progress * 60);
    final double dx = widget.event.position.dx + (math.sin(progress * 10) * 20);

    return Positioned(
      left: dx - 25, // Centered (emoji size is ~50)
      top: dy - 25,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: const Text('❤️', style: TextStyle(fontSize: 40)),
          ),
        ),
      ),
    );
  }

  Widget _buildSparks(double progress) {
    final double opacity = (1.0 - progress).clamp(0.0, 1.0);
    
    return IgnorePointer(
      child: Stack(
        children: _sparkOffsets.asMap().entries.map((entry) {
          final i = entry.key;
          final offset = entry.value;
          
          // Each spark follows its own randomized trajectory
          final dx = widget.event.position.dx + (offset.dx * progress) + (math.sin(progress * 15 + i) * 15);
          final dy = widget.event.position.dy + (offset.dy * progress);
          
          return Positioned(
            left: dx - 16,
            top: dy - 16,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: 0.6 + progress * 0.8,
                child: const Icon(Icons.bolt, color: Colors.amber, size: 32),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
