import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ReactionType { heart, spark }

class ReactionEvent {
  final String id;
  final Offset position;
  final ReactionType type;
  final DateTime timestamp;

  ReactionEvent({
    required this.id,
    required this.position,
    required this.type,
    required this.timestamp,
  });
}

class ReactionController extends Notifier<List<ReactionEvent>> {
  @override
  List<ReactionEvent> build() => [];

  void addReaction(Offset position, ReactionType type) {
    debugPrint('[REACTION_DEBUG] Adding global reaction: $type at $position');
    final event = ReactionEvent(
      id: '${DateTime.now().millisecondsSinceEpoch}_${position.dx}_${position.dy}',
      position: position,
      type: type,
      timestamp: DateTime.now(),
    );
    
    state = [...state, event];

    // Auto-remove the event after the animation completes (2.5 seconds)
    // This keeps the state clean and prevents memory leaks.
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (state.any((e) => e.id == event.id)) {
        state = state.where((e) => e.id != event.id).toList();
      }
    });
  }
}

final reactionControllerProvider = NotifierProvider<ReactionController, List<ReactionEvent>>(ReactionController.new);
