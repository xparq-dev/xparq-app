import 'dart:async';
import 'dart:math';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:xparq_app/shared/constants/app_constants.dart';

class CallSocketException implements Exception {
  const CallSocketException(
    this.code,
    this.message, {
    this.details = const <String, dynamic>{},
  });

  final String code;
  final String message;
  final Map<String, dynamic> details;

  @override
  String toString() => '$code: $message';
}

class CallSocketService {
  io.Socket? _socket;
  String? _accessToken;
  String? _currentEndpoint;
  void Function(String reason)? _disconnectListener;
  final Random _random = Random.secure();
  bool _suppressDisconnectCallback = false;

  bool get isConnected => _socket?.connected == true;
  String? get currentEndpoint => _currentEndpoint;

  void onDisconnect(void Function(String reason) listener) {
    _disconnectListener = listener;
  }

  Future<void> connect({
    required String accessToken,
    String? endpointOverride,
    bool forceReconnect = false,
  }) async {
    final endpoint = _normalizeEndpoint(
      endpointOverride ?? _currentEndpoint ?? _voiceSocketUrl(),
    );

    if (!forceReconnect &&
        _socket?.connected == true &&
        _currentEndpoint == endpoint) {
      return;
    }

    _accessToken = accessToken;
    _currentEndpoint = endpoint;
    _disposeSocket();

    final completer = Completer<void>();
    final socket = io.io(
      endpoint,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .disableMultiplex()
          .setAuth({'token': accessToken})
          .disableReconnection()
          .build(),
    );

    _socket = socket;

    socket
      ..onConnect((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      })
      ..onDisconnect((reason) {
        if (identical(_socket, socket) && !_suppressDisconnectCallback) {
          _disconnectListener?.call(reason.toString());
        }
      })
      ..onConnectError((error) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Socket connect error: $error'));
        }
      })
      ..onError((error) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Socket error: $error'));
        }
      });

    socket.connect();

    try {
      await completer.future.timeout(const Duration(seconds: 12));
    } catch (_) {
      if (identical(_socket, socket)) {
        _disposeSocket();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> joinRoom({
    required String roomId,
    String? callId,
    String? policyToken,
    int maxAttempts = 4,
  }) async {
    CallSocketException? lastError;

    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      try {
        return await _emitAck('joinRoom', {
          'roomId': roomId,
          if (callId != null && callId.isNotEmpty) 'callId': callId,
          if (policyToken != null && policyToken.isNotEmpty)
            'policyToken': policyToken,
        });
      } on CallSocketException catch (error) {
        lastError = error;

        if (error.code == 'ROOM_PINNED_REMOTE') {
          final endpoint = _extractRedirectEndpoint(error.details);
          final accessToken = _accessToken;
          if (endpoint != null && accessToken != null) {
            await Future<void>.delayed(
              Duration(milliseconds: computeReconnectDelayMs(attempt)),
            );
            await connect(
              accessToken: accessToken,
              endpointOverride: endpoint,
              forceReconnect: true,
            );
            continue;
          }
        }

        if (attempt == maxAttempts - 1) {
          rethrow;
        }

        final accessToken = _accessToken;
        if (accessToken != null) {
          await Future<void>.delayed(
            Duration(milliseconds: computeReconnectDelayMs(attempt)),
          );
          await connect(
            accessToken: accessToken,
            endpointOverride: _currentEndpoint,
            forceReconnect: true,
          );
          continue;
        }

        rethrow;
      }
    }

    throw lastError ??
        const CallSocketException(
          'JOIN_FAILED',
          'Unable to join the voice room after multiple retries.',
        );
  }

  Future<Map<String, dynamic>> createTransport(
    String direction, {
    String? policyToken,
  }) {
    return _emitAck('createTransport', {
      'direction': direction,
      if (policyToken != null && policyToken.isNotEmpty)
        'policyToken': policyToken,
    });
  }

  Future<Map<String, dynamic>> connectTransport({
    required String transportId,
    required Map<String, dynamic> dtlsParameters,
    String? policyToken,
  }) {
    return _emitAck('connectTransport', {
      'transportId': transportId,
      'dtlsParameters': dtlsParameters,
      if (policyToken != null && policyToken.isNotEmpty)
        'policyToken': policyToken,
    });
  }

  Future<Map<String, dynamic>> transportHeartbeat({
    required String transportId,
    required Map<String, dynamic> metrics,
    String? policyToken,
  }) {
    return _emitAck('transportHeartbeat', {
      'transportId': transportId,
      'metrics': metrics,
      if (policyToken != null && policyToken.isNotEmpty)
        'policyToken': policyToken,
    });
  }

  Future<Map<String, dynamic>> produce({
    required String transportId,
    required String kind,
    required Map<String, dynamic> rtpParameters,
  }) {
    return _emitAck('produce', {
      'transportId': transportId,
      'kind': kind,
      'rtpParameters': rtpParameters,
    });
  }

  Future<Map<String, dynamic>> consume({
    required String transportId,
    required String producerId,
    required Map<String, dynamic> rtpCapabilities,
  }) {
    return _emitAck('consume', {
      'transportId': transportId,
      'producerId': producerId,
      'rtpCapabilities': rtpCapabilities,
    });
  }

  void onNewProducer(void Function(String producerId) listener) {
    _socket?.off('newProducer');
    _socket?.on('newProducer', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final producerId = map['producerId']?.toString();
      if (producerId != null && producerId.isNotEmpty) {
        listener(producerId);
      }
    });
  }

  Future<void> leaveRoom() async {
    if (_socket == null) {
      return;
    }

    final completer = Completer<void>();
    _socket!.emitWithAck('leaveRoom', const {}, ack: (_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    await completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );
  }

  void disconnect() {
    _disposeSocket();
  }

  int computeReconnectDelayMs(int attempt) {
    final exponentialDelay = 500 * (1 << attempt.clamp(0, 3));
    final jitter = _random.nextInt(700);
    return min(3000, exponentialDelay + jitter);
  }

  Future<Map<String, dynamic>> _emitAck(
    String event,
    Map<String, dynamic> payload,
  ) async {
    final socket = _socket;
    if (socket == null) {
      throw Exception('Voice socket is not connected');
    }

    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(
      event,
      payload,
      ack: (response) {
        try {
          if (response == null) {
            completer.completeError(
              const CallSocketException(
                'EMPTY_SOCKET_RESPONSE',
                'The signaling server returned an empty response.',
              ),
            );
            return;
          }

          final map = Map<String, dynamic>.from(response as Map);
          if (map['ok'] == true) {
            completer.complete(
              Map<String, dynamic>.from(map['data'] as Map? ?? const {}),
            );
            return;
          }

          final error = Map<String, dynamic>.from(
            map['error'] as Map? ?? const {},
          );
          completer.completeError(
            CallSocketException(
              error['code']?.toString() ?? '${event.toUpperCase()}_FAILED',
              error['message']?.toString() ?? '$event failed',
              details: Map<String, dynamic>.from(
                error['details'] as Map? ?? const {},
              ),
            ),
          );
        } catch (error) {
          completer.completeError(
            Exception('Invalid socket response for $event: $error'),
          );
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 12));
  }

  String? _extractRedirectEndpoint(Map<String, dynamic> details) {
    final endpoint =
        details['endpoint'] ?? details['signalingEndpoint'] ?? details['url'];
    final value = endpoint?.toString();
    if (value == null || value.isEmpty) {
      return null;
    }

    return _normalizeEndpoint(value);
  }

  String _normalizeEndpoint(String value) {
    final uri = Uri.parse(value);
    if (uri.hasScheme) {
      return uri.toString().replaceAll(RegExp(r'/$'), '');
    }

    return 'https://${value.replaceAll(RegExp(r'^/+'), '')}'.replaceAll(
      RegExp(r'/$'),
      '',
    );
  }

  void _disposeSocket() {
    final socket = _socket;
    _socket = null;
    _suppressDisconnectCallback = true;
    socket?.dispose();
    socket?.disconnect();
    _suppressDisconnectCallback = false;
  }

  String _voiceSocketUrl() {
    const override = String.fromEnvironment('XPARQ_VOICE_SOCKET_URL');
    if (override.isNotEmpty) {
      return override;
    }

    final apiUri = Uri.parse(AppConstants.platformApiBaseUrl);
    return '${apiUri.scheme}://${apiUri.host}${apiUri.hasPort ? ':${apiUri.port}' : ''}';
  }
}
