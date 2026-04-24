import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tcp_connection_service.dart';

class TcpConnectionScreen extends ConsumerStatefulWidget {
  const TcpConnectionScreen({super.key});

  @override
  ConsumerState<TcpConnectionScreen> createState() =>
      _TcpConnectionScreenState();
}

class _TcpConnectionScreenState extends ConsumerState<TcpConnectionScreen> {
  final TextEditingController _hostController =
      TextEditingController(text: '192.168.1.117');
  final TextEditingController _portController =
      TextEditingController(text: '41051');
  final TextEditingController _messageController = TextEditingController();

  bool _isConnecting = false;
  final List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    TcpConnectionService.instance.connectionStatus.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    });

    TcpConnectionService.instance.messages.listen((message) {
      if (mounted) {
        setState(() {
          _messages.add('Received: $message');
        });
      }
    });

    TcpConnectionService.instance.errors.listen((error) {
      if (mounted) {
        setState(() {
          _messages.add('Error: $error');
          _isConnecting = false;
        });
      }
    });
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
    });

    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text) ?? 41051;

    if (host.isEmpty) {
      setState(() {
        _messages.add('Error: Host cannot be empty');
        _isConnecting = false;
      });
      return;
    }

    final success = await TcpConnectionService.instance.connect(host, port);

    if (mounted) {
      setState(() {
        _messages
            .add(success ? 'Connected to $host:$port' : 'Connection failed');
        _isConnecting = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    await TcpConnectionService.instance.sendMessage(message);

    if (mounted) {
      setState(() {
        _messages.add('Sent: $message');
        _messageController.clear();
      });
    }
  }

  Future<void> _disconnect() async {
    await TcpConnectionService.instance.disconnect();
    if (mounted) {
      setState(() {
        _messages.add('Disconnected');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = TcpConnectionService.instance.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TCP Connection'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device Connection',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hostController,
                            decoration: const InputDecoration(
                              labelText: 'IP Address',
                              border: OutlineInputBorder(),
                            ),
                            enabled: !isConnected && !_isConnecting,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              border: OutlineInputBorder(),
                            ),
                            enabled: !isConnected && !_isConnecting,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (!isConnected)
                          ElevatedButton(
                            onPressed: _isConnecting ? null : _connect,
                            child: _isConnecting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Connect'),
                          ),
                        if (isConnected) ...[
                          ElevatedButton(
                            onPressed: _disconnect,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Disconnect'),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Connected',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Message input
            if (isConnected)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _sendMessage,
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Messages log
            Expanded(
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Messages',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (_messages.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _messages.clear();
                                });
                              },
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isReceived = message.startsWith('Received:');
                          final isError = message.startsWith('Error:');
                          final isSent = message.startsWith('Sent:');

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 4.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isReceived
                                    ? Colors.blue.shade50
                                    : isError
                                        ? Colors.red.shade50
                                        : isSent
                                            ? Colors.green.shade50
                                            : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isReceived
                                      ? Colors.blue.shade200
                                      : isError
                                          ? Colors.red.shade200
                                          : isSent
                                              ? Colors.green.shade200
                                              : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                message,
                                style: TextStyle(
                                  color: isError
                                      ? Colors.red.shade800
                                      : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
