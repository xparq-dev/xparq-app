import 'dart:io';
import 'dart:convert';

void main() async {
  print('Testing TCP connection to 192.168.1.117:41051...');
  
  try {
    final socket = await Socket.connect('192.168.1.117', 41051, timeout: Duration(seconds: 10));
    print('Connected successfully!');
    
    // Listen for responses
    socket.listen(
      (data) {
        final response = utf8.decode(data);
        print('Received: $response');
      },
      onError: (error) {
        print('Socket error: $error');
      },
      onDone: () {
        print('Connection closed');
        socket.destroy();
      },
    );
    
    // Send a test message
    final testMessage = 'Hello from XPARQ app\n';
    socket.write(testMessage);
    print('Sent: $testMessage');
    
    // Wait a bit for response
    await Future.delayed(Duration(seconds: 5));
    
    socket.destroy();
    print('Test completed');
    
  } catch (e) {
    print('Connection failed: $e');
  }
}
