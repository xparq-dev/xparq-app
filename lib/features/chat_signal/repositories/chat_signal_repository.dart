import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/chat_signal/models/signal_event_model.dart';

class ChatSignalRepository {
  ChatSignalRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _channelName = 'chat_signal';
  static const String _eventName = 'signal';

  final SupabaseClient _client;
  final StreamController<SignalEvent> _controller =
      StreamController<SignalEvent>.broadcast();

  RealtimeChannel? _channel;

  Stream<SignalEvent> connect() {
    if (_channel != null) {
      return _controller.stream;
    }

    try {
      _channel = _client
          .channel(_channelName)
          .onBroadcast(
            event: _eventName,
            callback: (payload) {
              if (_controller.isClosed) {
                return;
              }

              _controller.add(_mapSignalEvent(payload));
            },
          )
          .subscribe();

      return _controller.stream;
    } catch (error) {
      throw NetworkException(
        'Failed to connect to the realtime signal channel.',
        cause: error,
      );
    }
  }

  Future<void> disconnect() async {
    final channel = _channel;
    _channel = null;

    if (channel == null) {
      return;
    }

    try {
      await _client.removeChannel(channel);
    } catch (error) {
      throw NetworkException(
        'Failed to disconnect from the realtime signal channel.',
        cause: error,
      );
    }
  }

  Future<void> dispose() async {
    await disconnect();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  SignalEvent _mapSignalEvent(Map<String, dynamic> payload) {
    final normalizedPayload = Map<String, dynamic>.from(payload);
    final type = normalizedPayload['type']?.toString();
    final rawEventPayload = normalizedPayload['payload'];

    return SignalEvent(
      type: (type == null || type.isEmpty) ? _eventName : type,
      payload: rawEventPayload is Map<String, dynamic>
          ? rawEventPayload
          : rawEventPayload is Map
          ? Map<String, dynamic>.from(rawEventPayload)
          : normalizedPayload,
    );
  }
}
