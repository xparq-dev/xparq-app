import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/call/presentation/providers/call_providers.dart';
import 'package:xparq_app/features/call/presentation/screens/call_session_screen.dart';

class CallOverlayHost extends ConsumerWidget {
  const CallOverlayHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callControllerProvider);
    if (!state.isOverlayVisible || !state.hasActiveCall) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xF2070A0F)),
        child: const CallSessionScreen(),
      ),
    );
  }
}
