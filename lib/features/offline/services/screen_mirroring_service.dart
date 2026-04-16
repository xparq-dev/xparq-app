import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'tcp_connection_service.dart';

class ScreenMirroringService {
  static final ScreenMirroringService _instance =
      ScreenMirroringService._internal();
  static ScreenMirroringService get instance => _instance;

  ScreenMirroringService._internal();

  final GlobalKey _captureKey = GlobalKey();
  Timer? _captureTimer;
  bool _isMirroring = false;
  int _fps = 30;
  double _quality = 0.8;
  Size? _screenSize;

  // Stream controllers
  final _mirroringStatusController = StreamController<bool>.broadcast();
  final _frameController = StreamController<Uint8List>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<bool> get mirroringStatus => _mirroringStatusController.stream;
  Stream<Uint8List> get frames => _frameController.stream;
  Stream<String> get errors => _errorController.stream;

  bool get isMirroring => _isMirroring;
  int get fps => _fps;
  double get quality => _quality;

  Future<void> initialize(BuildContext context) async {
    _screenSize = MediaQuery.of(context).size;
    debugPrint('Screen Mirroring: Initialized with screen size $_screenSize');
  }

  Future<void> startMirroring({
    int fps = 30,
    double quality = 0.8,
    bool useTcp = true,
    String? tcpHost,
    int? tcpPort,
  }) async {
    if (_isMirroring) {
      debugPrint('Screen Mirroring: Already active');
      return;
    }

    if (_screenSize == null) {
      _errorController
          .add('Screen mirroring not initialized. Call initialize() first.');
      return;
    }

    _fps = fps;
    _quality = quality;

    try {
      // Request necessary permissions
      await _requestPermissions();

      // Connect to TCP if specified
      if (useTcp && tcpHost != null && tcpPort != null) {
        final connected =
            await TcpConnectionService.instance.connect(tcpHost, tcpPort);
        if (!connected) {
          _errorController
              .add('Failed to connect to TCP server $tcpHost:$tcpPort');
          return;
        }
        debugPrint(
            'Screen Mirroring: Connected to TCP server $tcpHost:$tcpPort');
      }

      _isMirroring = true;
      _mirroringStatusController.add(true);

      // Start capturing frames
      _captureTimer = Timer.periodic(
        Duration(milliseconds: (1000 / _fps).round()),
        (_) => _captureFrame(useTcp: useTcp),
      );

      debugPrint('Screen Mirroring: Started at $_fps fps, quality: $_quality');
    } catch (e) {
      debugPrint('Screen Mirroring: Failed to start - $e');
      _errorController.add('Failed to start screen mirroring: $e');
      _isMirroring = false;
      _mirroringStatusController.add(false);
    }
  }

  Future<void> stopMirroring() async {
    if (!_isMirroring) return;

    _captureTimer?.cancel();
    _captureTimer = null;
    _isMirroring = false;
    _mirroringStatusController.add(false);

    // Disconnect TCP if connected
    if (TcpConnectionService.instance.isConnected) {
      await TcpConnectionService.instance.disconnect();
    }

    debugPrint('Screen Mirroring: Stopped');
  }

  Future<void> _requestPermissions() async {
    // For Android, we need to request overlay permission for screen capture
    if (Platform.isAndroid) {
      // Note: You'll need to implement proper permission handling
      debugPrint('Screen Mirroring: Requesting Android permissions...');
    }
  }

  Future<void> _captureFrame({bool useTcp = true}) async {
    if (!_isMirroring) return;

    try {
      // Capture screen using RepaintBoundary
      final RenderRepaintBoundary? boundary = _captureKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final Uint8List imageBytes = byteData.buffer.asUint8List();

          // Send to frame stream
          _frameController.add(imageBytes);

          // Send over TCP if enabled
          if (useTcp && TcpConnectionService.instance.isConnected) {
            await _sendFrameOverTcp(imageBytes);
          }
        }
      }
    } catch (e) {
      debugPrint('Screen Mirroring: Error capturing frame - $e');
      _errorController.add('Frame capture error: $e');
    }
  }

  Future<void> _sendFrameOverTcp(Uint8List frameData) async {
    try {
      // Convert frame to base64 for transmission
      final base64Frame = 'FRAME:${base64Encode(frameData)}';
      await TcpConnectionService.instance.sendMessage(base64Frame);
    } catch (e) {
      debugPrint('Screen Mirroring: TCP send error - $e');
      _errorController.add('TCP transmission error: $e');
    }
  }

  Future<Uint8List?> captureSingleFrame() async {
    try {
      final RenderRepaintBoundary? boundary = _captureKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          return byteData.buffer.asUint8List();
        }
      }
    } catch (e) {
      debugPrint('Screen Mirroring: Error capturing single frame - $e');
      _errorController.add('Single frame capture error: $e');
    }
    return null;
  }

  void updateSettings({int? fps, double? quality}) {
    if (fps != null) _fps = fps;
    if (quality != null) _quality = quality;

    // Restart mirroring with new settings if currently active
    if (_isMirroring) {
      stopMirroring();
      Future.delayed(Duration(milliseconds: 100), () {
        startMirroring(fps: _fps, quality: _quality);
      });
    }
  }

  void dispose() {
    stopMirroring();
    _mirroringStatusController.close();
    _frameController.close();
    _errorController.close();
  }
}

// Widget wrapper for screen capture
class ScreenCaptureWidget extends StatelessWidget {
  final Widget child;
  final ScreenMirroringService mirroringService;

  const ScreenCaptureWidget({
    super.key,
    required this.child,
    required this.mirroringService,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: mirroringService._captureKey,
      child: child,
    );
  }
}
