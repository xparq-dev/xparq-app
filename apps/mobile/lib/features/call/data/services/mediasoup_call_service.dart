// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:mediasoup_client_flutter/mediasoup_client_flutter.dart';
import 'package:mediasoup_client_flutter/src/handlers/handler_interface.dart';

class MediasoupCallService {
  Device? _device;
  Transport? _sendTransport;
  Transport? _recvTransport;
  Producer? _producer;
  Consumer? _consumer;
  MediaStream? _localStream;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  List<RTCIceServer> _iceServers = const <RTCIceServer>[];
  RTCIceTransportPolicy? _iceTransportPolicy;
  String? _policyToken;

  bool _rendererReady = false;

  Transport? get recvTransport => _recvTransport;
  String? get preferredTransportId => _sendTransport?.id ?? _recvTransport?.id;

  Map<String, dynamic> get rtpCapabilitiesMap =>
      _device?.rtpCapabilities.toMap() ?? const <String, dynamic>{};

  void applyIceConfiguration({
    required List<Map<String, dynamic>> iceServers,
    String? iceTransportPolicy,
    String? policyToken,
  }) {
    _iceServers = iceServers.map(_toIceServer).toList(growable: false);
    _iceTransportPolicy = _parseIceTransportPolicy(iceTransportPolicy);
    _policyToken = policyToken;
  }

  Future<void> prepareDevice(Map<String, dynamic> routerRtpCapabilities) async {
    _device = Device();
    await _device!.load(
      routerRtpCapabilities: RtpCapabilities.fromMap(routerRtpCapabilities),
    );
  }

  Future<void> configureAudioOutput({required bool speakerOn}) async {
    await Helper.setSpeakerphoneOn(speakerOn);
  }

  Future<void> openMicrophone() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
  }

  Future<void> createRecvTransport({
    required Map<String, dynamic> transportOptions,
    required Future<void> Function(
      String transportId,
      Map<String, dynamic> dtlsParameters,
    ) onConnect,
  }) async {
    final device = _device;
    if (device == null) {
      throw Exception('Mediasoup device is not ready');
    }

    _recvTransport = device.createRecvTransport(
      id: transportOptions['id']?.toString() ?? '',
      iceParameters: IceParameters.fromMap(
        Map<String, dynamic>.from(
          transportOptions['iceParameters'] as Map? ?? const {},
        ),
      ),
      iceCandidates: List<IceCandidate>.from(
        (transportOptions['iceCandidates'] as List? ?? const [])
            .map((iceCandidate) => IceCandidate.fromMap(iceCandidate as Map))
            .toList(),
      ),
      dtlsParameters: DtlsParameters.fromMap(
        Map<String, dynamic>.from(
          transportOptions['dtlsParameters'] as Map? ?? const {},
        ),
      ),
      sctpParameters: transportOptions['sctpParameters'] != null
          ? SctpParameters.fromMap(
              Map<String, dynamic>.from(
                transportOptions['sctpParameters'] as Map,
              ),
            )
          : null,
      iceServers: _iceServers,
      iceTransportPolicy: _iceTransportPolicy,
      appData: _transportAppData(transportOptions),
      proprietaryConstraints: _transportConstraints(),
      additionalSettings: _transportSettings(),
    );
    _recvTransport!.on('connect', (Map data) async {
      final callback = data['callback'] as Function;
      final errback = data['errback'] as Function;
      try {
        final dtlsParameters =
            (data['dtlsParameters'] as DtlsParameters).toMap();
        await onConnect(_recvTransport!.id, dtlsParameters);
        callback();
      } catch (error) {
        errback(error.toString());
      }
    });
  }

  Future<void> createSendTransport({
    required Map<String, dynamic> transportOptions,
    required Future<void> Function(
      String transportId,
      Map<String, dynamic> dtlsParameters,
    ) onConnect,
    required Future<String> Function(
      String transportId,
      String kind,
      Map<String, dynamic> rtpParameters,
    ) onProduce,
  }) async {
    final device = _device;
    if (device == null) {
      throw Exception('Mediasoup device is not ready');
    }

    _sendTransport = device.createSendTransport(
      id: transportOptions['id']?.toString() ?? '',
      iceParameters: IceParameters.fromMap(
        Map<String, dynamic>.from(
          transportOptions['iceParameters'] as Map? ?? const {},
        ),
      ),
      iceCandidates: List<IceCandidate>.from(
        (transportOptions['iceCandidates'] as List? ?? const [])
            .map((iceCandidate) => IceCandidate.fromMap(iceCandidate as Map))
            .toList(),
      ),
      dtlsParameters: DtlsParameters.fromMap(
        Map<String, dynamic>.from(
          transportOptions['dtlsParameters'] as Map? ?? const {},
        ),
      ),
      sctpParameters: transportOptions['sctpParameters'] != null
          ? SctpParameters.fromMap(
              Map<String, dynamic>.from(
                transportOptions['sctpParameters'] as Map,
              ),
            )
          : null,
      iceServers: _iceServers,
      iceTransportPolicy: _iceTransportPolicy,
      appData: _transportAppData(transportOptions),
      proprietaryConstraints: _transportConstraints(),
      additionalSettings: _transportSettings(),
    );
    _sendTransport!.on('connect', (Map data) async {
      final callback = data['callback'] as Function;
      final errback = data['errback'] as Function;
      try {
        final dtlsParameters =
            (data['dtlsParameters'] as DtlsParameters).toMap();
        await onConnect(_sendTransport!.id, dtlsParameters);
        callback();
      } catch (error) {
        errback(error.toString());
      }
    });

    _sendTransport!.on('produce', (Map data) async {
      final callback = data['callback'] as Function;
      final errback = data['errback'] as Function;
      try {
        final id = await onProduce(
          _sendTransport!.id,
          data['kind']?.toString() ?? 'audio',
          (data['rtpParameters'] as RtpParameters).toMap(),
        );
        callback(id);
      } catch (error) {
        errback(error.toString());
      }
    });
  }

  Future<void> startProducingAudio() async {
    final sendTransport = _sendTransport;
    final localStream = _localStream;
    if (sendTransport == null || localStream == null) {
      throw Exception('Send transport is not ready');
    }

    final audioTracks = localStream.getAudioTracks();
    if (audioTracks.isEmpty) {
      throw Exception('No local audio track available');
    }
    final track = audioTracks.first;

    final completer = Completer<void>();
    _sendTransport = sendTransport;
    sendTransport.producerCallback = (Producer producer) {
      _producer = producer;
      if (!completer.isCompleted) {
        completer.complete();
      }
    };
    sendTransport.produce(
      track: track,
      stream: localStream,
      source: 'microphone',
      stopTracks: false,
    );
    await completer.future.timeout(const Duration(seconds: 12));
  }

  Future<void> consumeRemoteProducer({
    required Map<String, dynamic> consumerOptions,
  }) async {
    final recvTransport = _recvTransport;
    if (recvTransport == null) {
      throw Exception('Receive transport is not ready');
    }

    if (!_rendererReady) {
      await _remoteRenderer.initialize();
      _rendererReady = true;
    }

    final completer = Completer<void>();
    recvTransport.consumerCallback = (Consumer consumer, Function? _) async {
      _consumer = consumer;
      _remoteRenderer.srcObject = consumer.stream;
      if (!completer.isCompleted) {
        completer.complete();
      }
    };
    recvTransport.consume(
      id: consumerOptions['id']?.toString() ?? '',
      producerId: consumerOptions['producerId']?.toString() ?? '',
      peerId: consumerOptions['peerId']?.toString() ??
          consumerOptions['producerId']?.toString() ??
          'remote-peer',
      kind: RTCRtpMediaTypeExtension.fromString(
        consumerOptions['kind']?.toString() ?? 'audio',
      ),
      rtpParameters: RtpParameters.fromMap(
        Map<String, dynamic>.from(
          consumerOptions['rtpParameters'] as Map? ?? const {},
        ),
      ),
    );
    await completer.future.timeout(const Duration(seconds: 12));
  }

  Future<void> setMuted(bool muted) async {
    final localStream = _localStream;
    if (localStream == null) {
      return;
    }

    final audioTracks = localStream.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      audioTracks.first.enabled = !muted;
    }
  }

  Future<Map<String, dynamic>> collectTransportMetrics() async {
    final reports = <dynamic>[];
    if (_sendTransport != null) {
      reports.addAll(await _sendTransport!.getState());
    }
    if (_recvTransport != null) {
      reports.addAll(await _recvTransport!.getState());
    }

    double? rttMs;
    double? packetLoss;
    double? jitterMs;
    double? availableOutgoingBitrate;

    for (final report in reports) {
      final type = report.type?.toString() ?? '';
      final values =
          Map<String, dynamic>.from(report.values as Map? ?? const {});

      if (type == 'candidate-pair' && _isSelectedCandidatePair(values)) {
        rttMs ??= _secondsToMilliseconds(
          _readDouble(values, const [
            'currentRoundTripTime',
            'googRtt',
            'roundTripTime',
          ]),
        );
        availableOutgoingBitrate ??= _readDouble(
          values,
          const ['availableOutgoingBitrate', 'googAvailableSendBandwidth'],
        );
      }

      if (type == 'remote-inbound-rtp' || type == 'inbound-rtp') {
        jitterMs ??= _secondsToMilliseconds(
          _readDouble(values, const ['jitter', 'googJitterReceived']),
        );
      }

      if (packetLoss == null &&
          (type == 'remote-inbound-rtp' ||
              type == 'inbound-rtp' ||
              type == 'outbound-rtp')) {
        final packetsLost =
            _readDouble(values, const ['packetsLost', 'googPacketsLost']);
        final packetsReceived = _readDouble(
          values,
          const [
            'packetsReceived',
            'packetsSent',
            'googPacketsReceived',
            'googPacketsSent',
          ],
        );

        if (packetsLost != null && packetsReceived != null) {
          final totalPackets = packetsLost + packetsReceived;
          if (totalPackets > 0) {
            packetLoss = packetsLost / totalPackets;
          }
        }
      }
    }

    final metricsMissing =
        rttMs == null && packetLoss == null && jitterMs == null;

    return {
      'metricsMissing': metricsMissing,
      'rttMs': (rttMs ?? 250).round(),
      'packetLoss': packetLoss ?? 0.08,
      'jitterMs': (jitterMs ?? 45).round(),
      if (availableOutgoingBitrate != null)
        'availableOutgoingBitrate': availableOutgoingBitrate.round(),
    };
  }

  Future<void> applyServerPolicy(Map<String, dynamic> policy) async {
    if (policy.isEmpty) {
      return;
    }

    // The SFU applies the adaptive policy server-side. Keeping this hook avoids
    // dropping policy acks on the floor without changing the local audio graph.
  }

  Future<void> dispose() async {
    await _consumer?.close();
    _producer?.close();
    _sendTransport?.close();
    _recvTransport?.close();

    for (final track
        in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      track.stop();
    }
    _localStream?.dispose();

    if (_rendererReady) {
      _remoteRenderer.srcObject = null;
      _remoteRenderer.dispose();
      _rendererReady = false;
    }

    _device = null;
    _sendTransport = null;
    _recvTransport = null;
    _producer = null;
    _consumer = null;
    _localStream = null;
    _iceServers = const <RTCIceServer>[];
    _iceTransportPolicy = null;
    _policyToken = null;
  }

  Map<String, dynamic> _transportAppData(
      Map<String, dynamic> transportOptions) {
    final appData = Map<String, dynamic>.from(
      transportOptions['appData'] as Map? ?? const {},
    );

    if (_policyToken != null && _policyToken!.isNotEmpty) {
      appData['policyToken'] = _policyToken;
    }

    return appData;
  }

  Map<String, dynamic> _transportConstraints() {
    return <String, dynamic>{
      'optional': [
        {'googDscp': true},
      ],
    };
  }

  Map<String, dynamic> _transportSettings() {
    return <String, dynamic>{
      'encodedInsertableStreams': false,
      if (_policyToken != null && _policyToken!.isNotEmpty)
        'icePolicyToken': _policyToken,
    };
  }

  RTCIceServer _toIceServer(Map<String, dynamic> rawServer) {
    final urls = rawServer['urls'];
    final normalizedUrls = urls is List
        ? urls.map((entry) => entry.toString()).toList(growable: false)
        : <String>[if (urls != null) urls.toString()];

    return RTCIceServer(
      credential: rawServer['credential'],
      credentialType: RTCIceCredentialType.password,
      urls: normalizedUrls,
      username: rawServer['username']?.toString() ?? '',
    );
  }

  RTCIceTransportPolicy? _parseIceTransportPolicy(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'relay':
        return RTCIceTransportPolicy.relay;
      case 'all':
        return RTCIceTransportPolicy.all;
      default:
        return null;
    }
  }

  bool _isSelectedCandidatePair(Map<String, dynamic> values) {
    final selected = values['selected'] == true ||
        values['selected']?.toString() == 'true' ||
        values['nominated'] == true ||
        values['nominated']?.toString() == 'true' ||
        values['googActiveConnection']?.toString() == 'true';

    final state = values['state']?.toString().toLowerCase();
    return selected || state == 'succeeded';
  }

  double? _readDouble(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final rawValue = values[key];
      if (rawValue == null) {
        continue;
      }

      final parsed = double.tryParse(rawValue.toString());
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  double? _secondsToMilliseconds(double? value) {
    if (value == null) {
      return null;
    }

    return value > 10 ? value : value * 1000;
  }
}
