import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:gal/gal.dart';
import 'package:xparq_app/core/widgets/xparq_image.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/profile/providers/image_upload_provider.dart';
import 'package:xparq_app/features/social/providers/pulse_providers.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class CreatePulseScreen extends ConsumerStatefulWidget {
  final XFile? initialImage;
  final XFile? initialVideo;
  final bool isWarpGear;
  final bool isSupernova;

  const CreatePulseScreen({
    super.key,
    this.initialImage,
    this.initialVideo,
    this.isWarpGear = false,
    this.isSupernova = false,
  });

  @override
  ConsumerState<CreatePulseScreen> createState() => _CreatePulseScreenState();
}

class _CreatePulseScreenState extends ConsumerState<CreatePulseScreen> {
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isNsfw = false;
  XFile? _imageFile;
  XFile? _videoFile;
  VideoPlayerController? _videoController;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _imageFile = widget.initialImage;
    _videoFile = widget.initialVideo;

    if (_videoFile != null) {
      _initVideo();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pulseNotifierProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    if (_videoFile == null) return;
    _videoController?.dispose();
    if (kIsWeb) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(_videoFile!.path),
      );
    } else {
      _videoController = VideoPlayerController.file(io.File(_videoFile!.path));
    }
    await _videoController!.initialize();
    _videoController!.setLooping(true);
    if (widget.isWarpGear) {
      _videoController!.setPlaybackSpeed(1.8);
    }
    _videoController!.play();
    setState(() {});
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.of(context)!.pulseDiscardTitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          AppLocalizations.of(context)!.pulseDiscardDesc,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.of(context)!.pulseKeep,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.54),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)!.pulseDiscard,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleExit() async {
    if (await _onWillPop()) {
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pulseNotifierProvider);
    final profileAsync = ref.watch(planetProfileProvider);

    ref.listen(pulseNotifierProvider, (prev, next) {
      if (next.isSuccess) {
        context.pop();
      } else if (next.errorMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.isSupernova
                ? AppLocalizations.of(context)!.orbitSupernovaMenuTitle
                : widget.isWarpGear
                ? AppLocalizations.of(context)!.orbitWarpGearTitle
                : AppLocalizations.of(context)!.orbitNewPulseTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            if (_imageFile != null)
              Positioned.fill(
                child: XparqImage(
                  imageUrl: _imageFile!.path,
                  fit: BoxFit.cover,
                ),
              ),
            if (_videoFile != null &&
                _videoController != null &&
                _videoController!.value.isInitialized)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
            _buildOverlayGradient(),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  if (widget.isWarpGear)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.pulseWarpGearActive,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildTextInput(),
                        const SizedBox(height: 30),
                        _buildActionButtons(state, profileAsync),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isUploading) _buildUploadOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _circleIconButton(icon: Icons.close, onTap: _handleExit),
            ),
          ),
          Text(
            AppLocalizations.of(context)!.pulsePreview,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _circleIconButton(icon: Icons.shortcut, onTap: _shareMedia),
                  const SizedBox(width: 12),
                  _circleIconButton(
                    icon: Icons.file_download,
                    onTap: _saveToDevice,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return Form(
      key: _formKey,
      child: TextFormField(
        controller: _contentController,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 18,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        decoration: InputDecoration(
          hintText: widget.isSupernova
              ? AppLocalizations.of(context)!.pulseSupernovaHint
              : AppLocalizations.of(context)!.pulseOrbitQuestion,
          hintStyle: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.5),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildActionButtons(dynamic state, dynamic profileAsync) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _minorActionButton(
          icon: Icons.auto_awesome_motion,
          label: AppLocalizations.of(context)!.pulseNebula,
          onTap: () async {
            final file = await context.pushNamed('nebulaPicker') as XFile?;
            if (file != null) {
              setState(() {
                // Determine if it's a video or image based on extension
                final path = file.path.toLowerCase();
                if (path.endsWith('.mp4') ||
                    path.endsWith('.mov') ||
                    path.endsWith('.m4v')) {
                  _imageFile = null;
                  _videoFile = file;
                  _initVideo();
                } else {
                  _videoFile = null;
                  _imageFile = file;
                  _videoController?.dispose();
                  _videoController = null;
                }
              });
            }
          },
        ),
        GestureDetector(
          onTap: state.isLoading
              ? null
              : () {
                  final profile = profileAsync.valueOrNull;
                  if (profile != null) _launchSupernova(profile);
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isSupernova
                    ? [const Color(0xFF00E5FF), const Color(0xFFFF4081)]
                    : [const Color(0xFF00E5FF), const Color(0xFF00B8D4)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: state.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    widget.isSupernova
                        ? AppLocalizations.of(context)!.pulseLaunchSupernova
                        : AppLocalizations.of(context)!.pulsePostToOrbit,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        _minorActionButton(
          icon: _isNsfw ? Icons.visibility_off : Icons.visibility,
          label: 'NSFW',
          onTap: () => setState(() => _isNsfw = !_isNsfw),
          isActive: _isNsfw,
        ),
      ],
    );
  }

  Widget _minorActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circleIconButton(
          icon: icon,
          onTap: onTap,
          size: 50,
          bgColor: isActive
              ? Theme.of(context).colorScheme.error.withOpacity(0.2)
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          innerIconColor: isActive
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurface,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildOverlayGradient() {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.isSupernova
                  ? [
                      const Color(0xFF00E5FF).withOpacity(0.3),
                      const Color(0xFFFF4081).withOpacity(0.2),
                      const Color(0xFFFF4081).withOpacity(0.4),
                      const Color(0xFF00E5FF).withOpacity(0.6),
                    ]
                  : [
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
              stops: widget.isSupernova
                  ? const [0.0, 0.3, 0.7, 1.0]
                  : const [0.0, 0.2, 0.7, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
      ),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 42,
    Color bgColor = Colors.transparent,
    Color? innerIconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor == Colors.transparent ? Colors.black38 : bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(
          icon,
          color: innerIconColor ?? Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }

  Future<void> _shareMedia() async {
    if (_imageFile != null) {
      // ignore: deprecated_member_use
      await share_plus.Share.shareXFiles([
        share_plus.XFile(_imageFile!.path),
      ], text: _contentController.text);
    } else if (_videoFile != null) {
      // ignore: deprecated_member_use
      await share_plus.Share.shareXFiles([
        share_plus.XFile(_videoFile!.path),
      ], text: _contentController.text);
    }
  }

  Future<void> _saveToDevice() async {
    try {
      if (_imageFile != null) {
        await Gal.putImage(_imageFile!.path);
      } else if (_videoFile != null) {
        await Gal.putVideo(_videoFile!.path);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.pulseSavedGallery),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.pulseSaveFailed(e.toString()),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _launchSupernova(dynamic profile) async {
    setState(() => _isUploading = true);
    String? imageUrl;
    String? videoUrl;
    try {
      if (_imageFile != null) {
        imageUrl = await ref
            .read(imageUploadServiceProvider)
            .uploadPulseImage(file: _imageFile!, uid: profile.id);
      }
      if (_videoFile != null) {
        videoUrl = await ref
            .read(imageUploadServiceProvider)
            .uploadPulseVideo(file: _videoFile!, uid: profile.id);
      }
      await ref
          .read(pulseNotifierProvider.notifier)
          .createPulse(
            _contentController.text.trim(),
            author: profile,
            isNsfw: _isNsfw,
            imageUrl: imageUrl,
            videoUrl: videoUrl,
            pulseType: widget.isSupernova ? 'story' : 'post',
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.pulseUploadFailed(e.toString()),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
