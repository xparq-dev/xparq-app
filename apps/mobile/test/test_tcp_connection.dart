import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

void main() async {
  debugPrint('Testing TCP connection to 192.168.1.117:41051...');
  
  try {
    final socket = await Socket.connect('192.168.1.117', 41051, timeout: Duration(seconds: 10));
    debugPrint('Connected successfully!');
    
    // Listen for responses
    socket.listen(
      (data) {
        final response = utf8.decode(data);
        debugPrint('Received: $response');
      },
      onError: (error) {
        debugPrint('Socket error: $error');
      },
      onDone: () {
        debugPrint('Connection closed');
        socket.destroy();
      },
    );
    
    // Send a test message
    final testMessage = 'Hello from XPARQ app\n';
    socket.write(testMessage);
    debugPrint('Sent: $testMessage');
    
    // Wait a bit for response
    await Future.delayed(Duration(seconds: 5));
    
    socket.destroy();
    debugPrint('Test completed');
    
  } catch (e) {
    debugPrint('Connection failed: $e');
  }
}
