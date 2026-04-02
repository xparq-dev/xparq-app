import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/chat_signal/providers/chat_provider.dart';
import 'package:xparq_app/features/chat_signal/widgets/signal_event_tile.dart';

class ChatSignalScreen extends ConsumerWidget {
  const ChatSignalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ChatState>(chatSignalProvider, (previous, next) {
      if (previous?.errorMessage == next.errorMessage ||
          next.errorMessage == null) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
    });

    final state = ref.watch(chatSignalProvider);
    final notifier = ref.read(chatSignalProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Signal')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12,
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    label: Text('Status: ${state.status.name.toUpperCase()}'),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed:
                            state.status == ChatSignalStatus.connecting ||
                                state.status == ChatSignalStatus.connected
                            ? null
                            : notifier.connect,
                        child: const Text('Connect'),
                      ),
                      OutlinedButton(
                        onPressed: state.status == ChatSignalStatus.connected
                            ? notifier.disconnect
                            : null,
                        child: const Text('Disconnect'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: state.events.isEmpty
                    ? const Center(
                        child: Text(
                          'No signal events received yet.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.events.length,
                        itemBuilder: (context, index) {
                          final event = state.events[index];
                          return SignalEventTile(event: event);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
