import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:xparq_app/features/offline/providers/offline_friends_provider.dart';
import 'package:xparq_app/features/offline/services/offline_mesh_encryption_service.dart';
import 'package:xparq_app/features/offline/services/nearby_service.dart';
import 'package:xparq_app/features/offline/services/offline_chat_database.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class OfflineOtherProfileScreen extends ConsumerStatefulWidget {
  final String peerId;
  final String displayName;
  final String endpointId;

  const OfflineOtherProfileScreen({
    super.key,
    required this.peerId,
    required this.displayName,
    required this.endpointId, // Required for GNC
  });

  @override
  ConsumerState<OfflineOtherProfileScreen> createState() =>
      _OfflineOtherProfileScreenState();
}

class _OfflineOtherProfileScreenState
    extends ConsumerState<OfflineOtherProfileScreen> {
  bool _isFriend = false;
  bool _isRequesting = false;
  late StreamSubscription _acceptSubscription;

  @override
  void initState() {
    super.initState();
    _checkFriendStatus();

    // Listen to handshake acceptance
    _acceptSubscription = NearbyService.instance.onHandshakeAccept.listen((
      acceptedEndpointId,
    ) async {
      final currentEndpointId = NearbyService.instance.peers
          .where((p) => p.userId == widget.peerId)
          .firstOrNull
          ?.endpointId;

      if (acceptedEndpointId == widget.endpointId ||
          acceptedEndpointId == currentEndpointId) {
        // Handshake succeeded! Add via provider so friends list updates in UI
        await ref.read(offlineFriendsProvider.notifier).addFriend(
          widget.peerId,
          widget.displayName,
          publicKey: NearbyService.instance.peers
              .where((p) => p.userId == widget.peerId)
              .firstOrNull
              ?.publicKey,
        );
        if (mounted) {
          setState(() {
            _isFriend = true;
            _isRequesting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.displayName} accepted your request!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _acceptSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkFriendStatus() async {
    final status = await OfflineChatDatabase.instance.isFriend(widget.peerId);
    if (mounted) {
      setState(() {
        _isFriend = status;
      });
    }
  }

  Future<void> _sendFriendRequest(String targetEndpointId) async {
    setState(() {
      _isRequesting = true;
    });

    // Fire off the connection request
    await NearbyService.instance.requestConnection(targetEndpointId);

    if (mounted) {
      setState(() {
        _isRequesting =
            false; // Note: Waiting for response happens in background
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request sent! Waiting for response...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mutedText = scheme.onSurface.withValues(alpha: 0.64);
    final faintText = scheme.onSurface.withValues(alpha: 0.46);

    return StreamBuilder<List<NearbyPeer>>(
      stream: NearbyService.instance.incomingPeersStream,
      initialData: const [],
      builder: (context, snapshot) {
        final peers = snapshot.data ?? [];
        final activePeer =
            peers.where((p) => p.userId == widget.peerId).firstOrNull;
        final isOnline = activePeer != null;

        // Use updated endpointId if they re-discovered, else fallback to initial
        final currentEndpointId = activePeer?.endpointId ?? widget.endpointId;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Offline Planet'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Planet visual
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _isFriend
                                  ? Colors.greenAccent.withValues(alpha: 0.3)
                                  : Colors.blueAccent.withValues(alpha: 0.3),
                              blurRadius: 100,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors:
                                Theme.of(context).brightness == Brightness.dark
                                    ? (_isFriend
                                        ? [
                                            const Color(0xFF1B3B26),
                                            const Color(0xFF41775A),
                                          ]
                                        : [
                                            const Color(0xFF1B263B),
                                            const Color(0xFF415A77),
                                          ])
                                    : (_isFriend
                                        ? [
                                            const Color(0xFFE8F5E9),
                                            const Color(0xFFA5D6A7),
                                          ]
                                        : [
                                            const Color(0xFFE3F2FD),
                                            const Color(0xFF90CAF9),
                                          ]),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(
                          _isFriend ? Icons.handshake : Icons.public,
                          size: _isFriend ? 80 : 100,
                          color: scheme.onSurface.withValues(alpha: 0.18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  widget.displayName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOnline ? 'Online via Mesh' : 'Offline / Out of Range',
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                if (_isFriend)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _SecurityCard(
                      peerId: widget.peerId,
                      livePublicKey: activePeer?.publicKey,
                    ),
                  ),
                if (_isFriend) const SizedBox(height: 24),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      if (_isFriend) ...[
                        // CHAT button - Shown only if friends
                        Builder(
                          builder: (context) {
                            final isConnected = NearbyService
                                .instance.connectedEndpoints
                                .contains(currentEndpointId);

                            return ElevatedButton.icon(
                              onPressed: isOnline && !_isRequesting
                                  ? () async {
                                      if (isConnected) {
                                        context.push(
                                          '/offline/chat',
                                          extra: {
                                            'peerId': widget.peerId,
                                            'peerName': widget.displayName,
                                            'endpointId': currentEndpointId,
                                          },
                                        );
                                      } else {
                                        setState(() => _isRequesting = true);
                                        await NearbyService.instance
                                            .requestConnection(
                                          currentEndpointId,
                                        );
                                        // The listener in initState will handle the transition once accepted
                                      }
                                    }
                                  : null,
                              icon: _isRequesting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      isConnected
                                          ? Icons.chat_bubble_outline
                                          : Icons.link,
                                    ),
                              label: Text(
                                _isRequesting
                                    ? 'Connecting...'
                                    : (isConnected
                                        ? 'Send Signal (Chat)'
                                        : 'Connect to Peer'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isConnected
                                    ? Colors.blueAccent
                                    : Colors.orangeAccent,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.withValues(
                                  alpha: 0.3,
                                ),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                        ),
                        if (!isOnline) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Peer must be online to connect.',
                            style: TextStyle(
                              color: faintText,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ] else ...[
                        // REQUEST FRIEND button - Shown if not friends
                        ElevatedButton.icon(
                          onPressed: isOnline && !_isRequesting
                              ? () => _sendFriendRequest(currentEndpointId)
                              : null,
                          icon: _isRequesting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.person_add),
                          label: Text(
                            _isRequesting
                                ? 'Sending Request...'
                                : 'Add Peer (Handshake)',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.green.withValues(
                              alpha: 0.3,
                            ),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        if (!isOnline) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Peer must be online to add as friend.',
                            style: TextStyle(
                              color: faintText,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text(
                    _isFriend
                        ? 'You are now connected with this peer. You can send explicit signals and chat while in proximity offline.'
                        : 'This planet is discovered through the offline mesh. You must add them as a peer to initiate contact.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SecurityCard extends ConsumerWidget {
  final String peerId;
  final String? livePublicKey;

  const _SecurityCard({
    required this.peerId,
    required this.livePublicKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>([
        OfflineChatDatabase.instance.getFriendPublicKey(peerId),
        OfflineChatDatabase.instance.isFriendVerified(peerId),
      ]),
      builder: (context, snapshot) {
        final storedPublicKey =
            snapshot.data != null ? snapshot.data![0] as String? : null;
        final isVerified =
            snapshot.data != null ? snapshot.data![1] as bool : false;
        final fingerprintSource = livePublicKey ?? storedPublicKey ?? '';
        final fingerprint = OfflineMeshEncryptionService.instance
            .fingerprintFromPublicKey(fingerprintSource);
        final keyChanged = livePublicKey != null &&
            storedPublicKey != null &&
            livePublicKey!.isNotEmpty &&
            storedPublicKey.isNotEmpty &&
            livePublicKey != storedPublicKey;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: keyChanged
                  ? scheme.error.withValues(alpha: 0.45)
                  : scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    keyChanged
                        ? Icons.warning_amber_rounded
                        : (isVerified
                            ? Icons.verified_user_outlined
                            : Icons.shield_outlined),
                    color: keyChanged
                        ? scheme.error
                        : (isVerified ? Colors.green : scheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    keyChanged
                        ? 'Security key changed'
                        : (isVerified
                            ? 'Security key verified'
                            : 'Security key not verified'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Fingerprint',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                fingerprint,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                keyChanged
                    ? 'This peer is presenting a different key than the one you saved before.'
                    : 'Compare this fingerprint with your peer on a trusted channel before verifying.',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: fingerprintSource.isEmpty
                    ? null
                    : () async {
                        final nextValue = keyChanged ? false : !isVerified;
                        await ref
                            .read(offlineFriendsProvider.notifier)
                            .setFriendVerification(peerId, nextValue);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                nextValue
                                    ? 'Peer key marked as verified.'
                                    : (keyChanged
                                        ? 'Verification cleared because the key changed.'
                                        : 'Peer key marked as unverified.'),
                              ),
                            ),
                          );
                        }
                      },
                child: Text(
                  keyChanged
                      ? 'Clear trust'
                      : (isVerified ? 'Mark as unverified' : 'Verify key'),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: fingerprintSource.isEmpty
                    ? null
                    : () async {
                        final verified = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _VerifyPeerQrSheet(
                            expectedPublicKey: fingerprintSource,
                          ),
                        );
                        if (verified == true) {
                          await ref
                              .read(offlineFriendsProvider.notifier)
                              .setFriendVerification(peerId, true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Peer key verified via QR.'),
                              ),
                            );
                          }
                        }
                      },
                child: const Text('Scan verification QR'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VerifyPeerQrSheet extends StatefulWidget {
  final String expectedPublicKey;

  const _VerifyPeerQrSheet({
    required this.expectedPublicKey,
  });

  @override
  State<_VerifyPeerQrSheet> createState() => _VerifyPeerQrSheetState();
}

class _VerifyPeerQrSheetState extends State<_VerifyPeerQrSheet> {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
  );
  bool _handled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    // Request camera permission explicitly before starting scanner
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() {
        _errorMessage = status.isPermanentlyDenied
            ? 'Camera permission denied.\nPlease enable it in App Settings.'
            : 'Camera permission is required to scan QR codes.';
      });
      return;
    }

    try {
      await _controller.start();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera unavailable: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) return;
    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null) return;

    try {
      final data = jsonDecode(rawValue);
      if (data is! Map || data['type'] != 'offline_mesh_key') {
        throw const FormatException('Unexpected QR payload');
      }

      final publicKey = data['publicKey'] as String? ?? '';
      if (publicKey == widget.expectedPublicKey) {
        _handled = true;
        Navigator.pop(context, true);
        return;
      }

      _handled = true;
      Navigator.pop(context, false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR does not match this peer security key.'),
        ),
      );
    } catch (_) {
      _handled = true;
      Navigator.pop(context, false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read a valid verification QR.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Material(
          color: scheme.surface,
          elevation: 12,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Scan peer verification QR',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 360,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _errorMessage != null
                        ? Container(
                            color: Colors.black,
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.no_photography_outlined,
                                    color: Colors.white54,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : MobileScanner(
                            controller: _controller,
                            onDetect: _handleCapture,
                            errorBuilder: (context, error, child) {
                              return Container(
                                color: Colors.black,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.no_photography_outlined,
                                      color: Colors.white54,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Camera error: ${error.errorCode.name}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Align your peer verification QR in the frame.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(AppLocalizations.of(context)!.offlineCancel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
