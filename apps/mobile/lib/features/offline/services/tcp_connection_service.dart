import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class TcpConnectionService {
  static final TcpConnectionService _instance = TcpConnectionService._internal();
  static TcpConnectionService get instance => _instance;
  
  TcpConnectionService._internal();

  Socket? _socket;
  bool _isConnected = false;
  String? _host;
  int? _port;

  // Stream controllers
  final _connectionStatusController = StreamController<bool>.broadcast();
  final _messageController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  Stream<String> get messages => _messageController.stream;
  Stream<String> get errors => _errorController.stream;

  bool get isConnected => _isConnected;
  String? get host => _host;
  int? get port => _port;

  Future<bool> connect(String host, int port) async {
    if (_isConnected) {
      debugPrint('TCP: Already connected to $_host:$_port');
      return true;
    }

    try {
      debugPrint('TCP: Connecting to $host:$port...');
      _socket = await Socket.connect(host, port, timeout: Duration(seconds: 10));
      
      _host = host;
      _port = port;
      _isConnected = true;
      
      _connectionStatusController.add(true);
      debugPrint('TCP: Connected to $host:$port');

      // Start listening for messages
      _socket?.listen(
        (data) {
          try {
            final message = utf8.decode(data);
            _messageController.add(message);
            debugPrint('TCP: Received: $message');
          } catch (e) {
            debugPrint('TCP: Error decoding message: $e');
          }
        },
        onError: (error) {
          debugPrint('TCP: Socket error: $error');
          _errorController.add('Socket error: $error');
          disconnect();
        },
        onDone: () {
          debugPrint('TCP: Connection closed by server');
          disconnect();
        },
      );

      return true;
    } catch (e) {
      debugPrint('TCP: Connection failed: $e');
      _errorController.add('Connection failed: $e');
      return false;
    }
  }

  Future<void> sendMessage(String message) async {
    if (!_isConnected || _socket == null) {
      debugPrint('TCP: Cannot send message - not connected');
      _errorController.add('Not connected to server');
      return;
    }

    try {
      final data = utf8.encode(message);
      _socket!.add(data);
      await _socket!.flush();
      debugPrint('TCP: Sent: $message');
    } catch (e) {
      debugPrint('TCP: Send error: $e');
      _errorController.add('Send error: $e');
    }
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      try {
        await _socket!.close();
      } catch (e) {
        debugPrint('TCP: Error closing socket: $e');
      }
      _socket = null;
    }
    
    _isConnected = false;
    _connectionStatusController.add(false);
    debugPrint('TCP: Disconnected');
  }

  void dispose() {
    disconnect();
    _connectionStatusController.close();
    _messageController.close();
    _errorController.close();
  }
}
