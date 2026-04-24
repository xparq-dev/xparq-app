import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  bool _isScanned = false;
  bool _hasPermission = false;
  bool _isLoading = true;
  final MobileScannerController _controller = MobileScannerController(autoStart: false);
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      if (status.isGranted) {
        try {
          await _controller.start();
        } catch (e) {
          debugPrint('Mobile scanner start error: $e');
        }
      }
      setState(() {
        _hasPermission = status.isGranted;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final BarcodeCapture? capture = await _controller.analyzeImage(
        image.path,
      );
      if (capture != null && capture.barcodes.isNotEmpty) {
        _handleScan(capture);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.scannerNoQRFound),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.scannerErrorAnalyzing(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_isScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null) {
        setState(() => _isScanned = true);

        // Handle Custom Scheme: iXPARQ://signal/invite?uid=...
        if (code.startsWith('iXPARQ://signal/invite')) {
          final uri = Uri.tryParse(code);
          final otherUid = uri?.queryParameters['uid'];
          if (otherUid != null) {
            await _handleSignalInvite(otherUid);
            return;
          }
        }

        // Try to launch URL if it's a link
        final Uri? uri = Uri.tryParse(code);
        if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.scannerLaunchError(code),
                  ),
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.pulseScannedCode(code),
                ),
              ),
            );
          }
        }

        // Return after handling
        if (mounted) Navigator.pop(context);
        break;
      }
    }
  }

  Future<void> _handleSignalInvite(String otherUid) async {
    final myUid = ref.read(authRepositoryProvider).currentUser?.id ?? '';
    if (myUid.isEmpty) return;

    // 1. Check if already friends
    final orbitStatus = ref.read(myOrbitingStatusProvider).valueOrNull ?? {};
    final isFriend = orbitStatus[otherUid] == 'accepted';

    if (!isFriend) {
      // Show confirmation prompt
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B2A),
          title: Text(
            AppLocalizations.of(context)!.scannerInviteTitle,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            AppLocalizations.of(
              context,
            )!.scannerInviteDesc(otherUid.substring(0, 8)),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                AppLocalizations.of(context)!.authConfirm,
                style: const TextStyle(color: Color(0xFF4FC3F7)),
              ),
            ),
          ],
        ),
      );

      if (proceed != true) {
        setState(() => _isScanned = false); // Allow re-scanning
        return;
      }
    }

    // 2. Open Chat
    if (mounted) {
      final repo = ref.read(chatRepositoryProvider);
      final chat = await repo.getOrCreateChat(myUid: myUid, otherUid: otherUid);

      if (mounted) {
        Navigator.pop(context); // Close scanner
        context.push('${AppRoutes.chat}/${chat.chatId}/$otherUid');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.scannerTitle),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.image_outlined),
            tooltip: AppLocalizations.of(context)!.scannerGalleryTooltip,
            onPressed: _pickImage,
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : !_hasPermission
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.scannerPermissionRequired,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _checkPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.scannerGrantAccess,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleScan,
                  errorBuilder: (context, error, child) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.scannerCameraError(error.errorCode.name),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.scannerRealDeviceRequired,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Scanner Overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.scannerAlignFrame,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

