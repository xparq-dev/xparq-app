import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'screen_mirroring_service.dart';

class WebSocketServerService {
  static final WebSocketServerService _instance = WebSocketServerService._internal();
  static WebSocketServerService get instance => _instance;
  
  WebSocketServerService._internal();

  HttpServer? _server;
  WebSocket? _webSocket;
  bool _isRunning = false;
  String _host = '0.0.0.0';
  int _port = 8080;

  // Stream controllers
  final _serverStatusController = StreamController<bool>.broadcast();
  final _clientConnectionController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<bool> get serverStatus => _serverStatusController.stream;
  Stream<bool> get clientConnection => _clientConnectionController.stream;
  Stream<String> get errors => _errorController.stream;

  bool get isRunning => _isRunning;
  String get host => _host;
  int get port => _port;

  Future<bool> startServer({String host = '0.0.0.0', int port = 8080}) async {
    if (_isRunning) {
      debugPrint('WebSocket Server: Already running on $_host:$_port');
      return true;
    }

    _host = host;
    _port = port;

    try {
      _server = await HttpServer.bind(_host, _port);
      _isRunning = true;
      _serverStatusController.add(true);
      
      debugPrint('WebSocket Server: Started on $_host:$_port');

      // Listen for WebSocket connections
      await for (HttpRequest request in _server!) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          _handleWebSocketConnection(request);
        } else {
          // Serve the HTML client
          _serveHtmlClient(request);
        }
      }

      return true;
    } catch (e) {
      debugPrint('WebSocket Server: Failed to start - $e');
      _errorController.add('Failed to start server: $e');
      _isRunning = false;
      _serverStatusController.add(false);
      return false;
    }
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;

    await _webSocket?.close();
    await _server?.close();
    _webSocket = null;
    _server = null;
    _isRunning = false;
    
    _serverStatusController.add(false);
    _clientConnectionController.add(false);
    
    debugPrint('WebSocket Server: Stopped');
  }

  Future<void> _handleWebSocketConnection(HttpRequest request) async {
    try {
      _webSocket = await WebSocketTransformer.upgrade(request);
      _clientConnectionController.add(true);
      
      debugPrint('WebSocket Server: Client connected');

      // Listen for client messages
      _webSocket!.listen(
        (message) {
          debugPrint('WebSocket Server: Received message: $message');
        },
        onError: (error) {
          debugPrint('WebSocket Server: Client error - $error');
          _errorController.add('Client error: $error');
        },
        onDone: () {
          debugPrint('WebSocket Server: Client disconnected');
          _clientConnectionController.add(false);
          _webSocket = null;
        },
      );

      // Start sending screen frames when client connects
      _startScreenStreaming();
      
    } catch (e) {
      debugPrint('WebSocket Server: WebSocket upgrade failed - $e');
      _errorController.add('WebSocket upgrade failed: $e');
    }
  }

  Future<void> _serveHtmlClient(HttpRequest request) async {
    try {
      // Read the HTML client file
      final file = File('web/screen_mirroring_client.html');
      if (await file.exists()) {
        final content = await file.readAsString();
        
        request.response
          ..headers.contentType = ContentType.html
          ..headers.set('Access-Control-Allow-Origin', '*')
          ..headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
          ..headers.set('Access-Control-Allow-Headers', 'Content-Type')
          ..write(content)
          ..close();
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('HTML client not found')
          ..close();
      }
    } catch (e) {
      debugPrint('WebSocket Server: Error serving HTML - $e');
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Internal server error')
        ..close();
    }
  }

  void _startScreenStreaming() {
    if (_webSocket == null) return;

    // Listen for screen frames from the mirroring service
    ScreenMirroringService.instance.frames.listen(
      (frameData) {
        if (_webSocket != null && _isRunning) {
          final base64Frame = 'FRAME:${base64Encode(frameData)}';
          _webSocket!.add(base64Frame);
        }
      },
      onError: (error) {
        debugPrint('WebSocket Server: Frame streaming error - $error');
        _errorController.add('Frame streaming error: $error');
      },
    );
  }

  Future<void> sendCustomMessage(String message) async {
    if (_webSocket != null && _isRunning) {
      try {
        _webSocket!.add(message);
        debugPrint('WebSocket Server: Sent custom message: $message');
      } catch (e) {
        debugPrint('WebSocket Server: Error sending message - $e');
        _errorController.add('Send message error: $e');
      }
    }
  }

  void dispose() {
    stopServer();
    _serverStatusController.close();
    _clientConnectionController.close();
    _errorController.close();
  }
}
