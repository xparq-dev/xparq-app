import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/screen_mirroring_service.dart';
import '../services/websocket_server_service.dart';

class ScreenMirroringScreen extends ConsumerStatefulWidget {
  const ScreenMirroringScreen({super.key});

  @override
  ConsumerState<ScreenMirroringScreen> createState() =>
      _ScreenMirroringScreenState();
}

class _ScreenMirroringScreenState extends ConsumerState<ScreenMirroringScreen> {
  bool _isServerRunning = false;
  bool _isMirroring = false;
  bool _isClientConnected = false;
  String _serverHost = '0.0.0.0';
  int _serverPort = 8080;
  int _fps = 30;
  double _quality = 0.8;
  String _statusMessage = 'Ready to start';
  String _clientUrl = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    // Initialize screen mirroring service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenMirroringService.instance.initialize(context);
    });

    // Listen to server status
    WebSocketServerService.instance.serverStatus.listen((isRunning) {
      if (mounted) {
        setState(() {
          _isServerRunning = isRunning;
          if (isRunning) {
            _statusMessage = 'Server running on $_serverHost:$_serverPort';
            _clientUrl = 'http://$_serverHost:$_serverPort';
          } else {
            _statusMessage = 'Server stopped';
            _clientUrl = '';
          }
        });
      }
    });

    // Listen to client connections
    WebSocketServerService.instance.clientConnection.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isClientConnected = isConnected;
          _statusMessage = isConnected
              ? 'Client connected - Screen mirroring active'
              : 'Client disconnected';
        });
      }
    });

    // Listen to mirroring status
    ScreenMirroringService.instance.mirroringStatus.listen((isMirroring) {
      if (mounted) {
        setState(() {
          _isMirroring = isMirroring;
        });
      }
    });

    // Listen to errors
    WebSocketServerService.instance.errors.listen((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server Error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    ScreenMirroringService.instance.errors.listen((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mirroring Error: $error'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  Future<void> _toggleServer() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_isServerRunning) {
      await WebSocketServerService.instance.stopServer();
      await ScreenMirroringService.instance.stopMirroring();
    } else {
      final success = await WebSocketServerService.instance.startServer(
        host: _serverHost,
        port: _serverPort,
      );
      if (!success && mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to start server'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleMirroring() async {
    if (_isMirroring) {
      await ScreenMirroringService.instance.stopMirroring();
    } else {
      await ScreenMirroringService.instance.startMirroring(
        fps: _fps,
        quality: _quality,
      );
    }
  }

  void _showSettings() {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          'Settings',
          style: TextStyle(color: scheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _serverHost,
              style: TextStyle(color: scheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Server Host',
                hintText: '0.0.0.0',
                labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)),
                hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.45)),
              ),
              onChanged: (value) => _serverHost = value,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _serverPort.toString(),
              style: TextStyle(color: scheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Server Port',
                hintText: '8080',
                labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)),
                hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.45)),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _serverPort = int.tryParse(value) ?? 8080;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'FPS: $_fps',
              style: TextStyle(color: scheme.onSurface),
            ),
            Slider(
              value: _fps.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              label: '$_fps fps',
              onChanged: (value) {
                setState(() {
                  _fps = value.round();
                });
                if (_isMirroring) {
                  ScreenMirroringService.instance.updateSettings(fps: _fps);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Quality: ${(_quality * 100).round()}%',
              style: TextStyle(color: scheme.onSurface),
            ),
            Slider(
              value: _quality,
              min: 0.1,
              max: 1.0,
              divisions: 9,
              label: '${(_quality * 100).round()}%',
              onChanged: (value) {
                setState(() {
                  _quality = value;
                });
                if (_isMirroring) {
                  ScreenMirroringService.instance
                      .updateSettings(quality: _quality);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WebSocketServerService.instance.stopServer();
    ScreenMirroringService.instance.stopMirroring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Mirroring'),
        actions: [
          IconButton(
            onPressed: _showSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isServerRunning ? Icons.dns : Icons.dns,
                          color: _isServerRunning ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Server Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_statusMessage),
                    if (_clientUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SelectableText(
                        'Client URL: $_clientUrl',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Connection Status
            Row(
              children: [
                Expanded(
                  child: _buildStatusCard(
                    'Server',
                    _isServerRunning,
                    Icons.router,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusCard(
                    'Client',
                    _isClientConnected,
                    Icons.devices,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusCard(
                    'Mirroring',
                    _isMirroring,
                    Icons.screen_share,
                    Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Control Buttons
            ElevatedButton.icon(
              onPressed: _toggleServer,
              icon: Icon(_isServerRunning ? Icons.stop : Icons.play_arrow),
              label: Text(_isServerRunning ? 'Stop Server' : 'Start Server'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isServerRunning ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isServerRunning ? _toggleMirroring : null,
              icon: Icon(
                  _isMirroring ? Icons.stop_screen_share : Icons.screen_share),
              label: Text(_isMirroring ? 'Stop Mirroring' : 'Start Mirroring'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMirroring ? Colors.orange : Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to use:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Start the server'),
                    const Text('2. Open the client URL in your PC browser'),
                    const Text('3. Start mirroring to share your screen'),
                    const Text('4. Adjust settings for performance'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
      String title, bool isActive, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? color : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? color : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
