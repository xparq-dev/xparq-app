import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/profile/providers/image_upload_provider.dart';
import 'package:xparq_app/features/social/providers/pulse_providers.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';

const int _kPulseMaxChars = 280;
const List<_VisibilityOption> _visibilityOptions = [
  _VisibilityOption('Public', 'Anyone in your orbit'),
  _VisibilityOption('Friends', 'People you are connected with'),
  _VisibilityOption('Only me', 'Private note just for you'),
];
const List<_MoodOption> _moodOptions = [
  _MoodOption('Happy', '😊', Color(0xFFFFC857)),
  _MoodOption('Sad', '😔', Color(0xFF7E88FF)),
  _MoodOption('Chill', '😎', Color(0xFF4FC3F7)),
  _MoodOption('Excited', '🤩', Color(0xFFFF7AA2)),
  _MoodOption('Focused', '🧠', Color(0xFF9C6BFF)),
  _MoodOption('Loved', '🥰', Color(0xFFFF7AA2)),
  _MoodOption('Tired', '😴', Color(0xFFA5A5A5)),
  _MoodOption('Angry', '😡', Color(0xFFE24B6B)),
  _MoodOption('Thinking', '🤔', Color(0xFF8E72FF)),
  _MoodOption('Sick', '🤒', Color(0xFF4CAF50)),
  _MoodOption('Party', '🥳', Color(0xFFFFB020)),
];

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

class _CreatePulseScreenState extends ConsumerState<CreatePulseScreen>
    with SingleTickerProviderStateMixin {
  final _contentController = TextEditingController();
  final _focusNode = FocusNode();

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isNsfw = false;
  bool _isUploading = false;
  XFile? _imageFile;
  XFile? _videoFile;
  VideoPlayerController? _videoController;
  String _selectedVisibility = _visibilityOptions.first.value;
  _MoodOption? _selectedMood;
  String? _selectedLocation;

  bool get _isEmpty => _contentController.text.trim().isEmpty;
  bool get _isOverLimit => _contentController.text.length > _kPulseMaxChars;
  bool get _hasValidContent => !_isEmpty && !_isOverLimit;
  bool get _hasAttachment => _imageFile != null || _videoFile != null;
  bool get _showAiPrompt => _contentController.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _imageFile = widget.initialImage;
    _videoFile = widget.initialVideo;

    _contentController.addListener(_handleComposerStateChange);
    _focusNode.addListener(_handleComposerStateChange);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    if (_videoFile != null) {
      _initVideo();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pulseNotifierProvider.notifier).reset();
      _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _contentController
      ..removeListener(_handleComposerStateChange)
      ..dispose();
    _focusNode
      ..removeListener(_handleComposerStateChange)
      ..dispose();
    _videoController?.dispose();
    _entranceController.dispose();
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
    _videoController!
      ..setLooping(true)
      ..play();

    if (mounted) {
      setState(() {});
    }
  }

  Future<bool> _onWillPop() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151224) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          AppLocalizations.of(context)!.pulseDiscardTitle,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1B1634),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          AppLocalizations.of(context)!.pulseDiscardDesc,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF6F6B85),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep editing',
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF6F6B85),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Discard',
              style: TextStyle(
                color: Color(0xFFE24B6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleExit() async {
    FocusScope.of(context).unfocus();
    if (await _onWillPop() && mounted) {
      context.pop();
    }
  }

  void _handleComposerStateChange() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openMediaPicker() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MediaSourceSheet(isDark: isDark),
    );

    if (source == null || !mounted) return;

    XFile? file;

    if (source == 'camera') {
      final result =
          await context.pushNamed('nebulaPicker') as Map<String, dynamic>?;
      if (result != null) {
        file = result['file'] as XFile?;
      }
    } else {
      final picker = ImagePicker();
      // Use media picker to support both images and videos
      if (source == 'video') {
        file = await picker.pickVideo(source: ImageSource.gallery);
      } else {
        file = await picker.pickImage(source: ImageSource.gallery);
      }
    }

    if (file == null || !mounted) return;

    final path = file.path.toLowerCase();
    if (path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.m4v')) {
      setState(() {
        _imageFile = null;
        _videoFile = file;
      });
      await _initVideo();
      return;
    }

    _videoController?.dispose();
    setState(() {
      _videoController = null;
      _videoFile = null;
      _imageFile = file;
    });
  }

  Future<void> _pickMood() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mood = await showGeneralDialog<_MoodOption?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Mood popup',
      barrierColor: Colors.black.withValues(alpha: 0.10),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: const Alignment(0, 0.26),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _MoodRail(
                isDark: isDark,
                moods: _moodOptions,
                selectedMood: _selectedMood,
                onSelected: (mood) => Navigator.pop(context, mood),
                onClear: _selectedMood == null
                    ? null
                    : () => Navigator.pop(context, null),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );

    if (mounted) {
      setState(() => _selectedMood = mood);
    }
  }

  void _toggleLocation(PlanetModel? profile) {
    final locationName = profile?.locationName?.trim();
    setState(() {
      _selectedLocation = _selectedLocation == null
          ? ((locationName != null && locationName.isNotEmpty)
              ? locationName
              : 'On campus')
          : null;
    });
  }

  void _toggleSensitive(PlanetModel? profile) {
    final canToggle = profile?.isExplorer ?? false;
    if (!canToggle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF2A1F52),
          content:
              Text('Sensitive content is available for Explorer accounts.'),
        ),
      );
      return;
    }
    setState(() => _isNsfw = !_isNsfw);
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A1F52),
        content: Text('$feature is coming soon for Pulse.'),
      ),
    );
  }

  Future<void> _submitPulse(PlanetModel profile) async {
    if (!_hasValidContent) return;

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

      await ref.read(pulseNotifierProvider.notifier).createPulse(
            _contentController.text.trim(),
            author: profile,
            isNsfw: _isNsfw,
            imageUrl: imageUrl,
            videoUrl: videoUrl,
            moodEmoji: _selectedMood?.emoji,
            moodLabel: _selectedMood?.label,
            locationName: _selectedLocation,
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
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(pulseNotifierProvider);
    final profileAsync = ref.watch(planetProfileProvider);
    final profile = profileAsync.valueOrNull;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = bottomInset > 0;

    ref.listen(pulseNotifierProvider, (prev, next) {
      if (next.isSuccess) {
        context.pop();
      } else if (next.errorMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFE24B6B),
            content: Text(next.errorMessage!),
          ),
        );
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _handleExit,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF080611).withValues(alpha: 0.62),
                                const Color(0xFF140F29).withValues(alpha: 0.54),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.28),
                                const Color(0xFFF1EAFF).withValues(alpha: 0.24),
                              ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final minHeight = keyboardOpen
                      ? 0.0
                      : math.max(0.0, constraints.maxHeight - 32);

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      22,
                      keyboardOpen ? 10 : 24,
                      22,
                      bottomInset + 20,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minHeight),
                      child: Align(
                        alignment: keyboardOpen
                            ? Alignment.topCenter
                            : Alignment.center,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: Material(
                                color: isDark
                                    ? const Color(0xFF161222)
                                        .withValues(alpha: 0.92)
                                    : Colors.white.withValues(alpha: 0.94),
                                elevation: 0,
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : const Color(0xFFE7E0F5),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black
                                                .withValues(alpha: 0.32)
                                            : const Color(0xFF5E35B1)
                                                .withValues(alpha: 0.10),
                                        blurRadius: 32,
                                        offset: const Offset(0, 20),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      11,
                                      16,
                                      16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildHandle(isDark),
                                        const SizedBox(height: 7),
                                        _buildHeader(isDark),
                                        const SizedBox(height: 12),
                                        _buildIdentityRow(profile, isDark),
                                        const SizedBox(height: 10),
                                        _buildComposerCard(profile, isDark),
                                        if (_hasAttachment) ...[
                                          const SizedBox(height: 8),
                                          _buildAttachmentPreview(isDark),
                                        ],
                                        const SizedBox(height: 14),
                                        _buildPostButton(
                                            state, profile, isDark),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isUploading) _buildUploadOverlay(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: isDark ? Colors.white24 : const Color(0xFFD9D3EA),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Center(
      child: Text(
        widget.isSupernova
            ? 'New Supernova'
            : widget.isWarpGear
                ? 'Warp Pulse'
                : 'New Pulse',
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1B1634),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String? _resolvedHandle(PlanetModel? profile) {
    final rawHandle = profile?.handle?.trim();
    if (rawHandle != null && rawHandle.isNotEmpty) {
      return rawHandle.replaceFirst(RegExp(r'^@+'), '');
    }

    final fallback = profile?.xparqName.trim();
    if (fallback == null || fallback.isEmpty) {
      return null;
    }

    return fallback.replaceAll(RegExp(r'\s+'), '').replaceFirst(
          RegExp(r'^@+'),
          '',
        );
  }

  Widget _buildIdentityRow(PlanetModel? profile, bool isDark) {
    final chipColor =
        isDark ? const Color(0xFF241D39) : const Color(0xFFF5F2FF);
    final handle = _resolvedHandle(profile);
    final hasHandle = handle != null && handle.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: profile != null && profile.photoUrl.isNotEmpty
                    ? XparqImage(imageUrl: profile.photoUrl)
                    : Container(
                        color: isDark
                            ? const Color(0xFF2A2340)
                            : const Color(0xFFEAE2FF),
                        alignment: Alignment.center,
                        child: Text(
                          (profile?.xparqName.isNotEmpty ?? false)
                              ? profile!.xparqName.characters.first
                                  .toUpperCase()
                              : 'Y',
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFF4E3B8F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            _buildAudienceChip(isDark, chipColor),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.xparqName ?? 'Your profile',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1B1634),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasHandle || (profile?.isExplorer ?? false)) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (hasHandle)
                        Text(
                          '@$handle',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF7A7592),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (profile?.isExplorer ?? false)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF7C4DFF).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF7C4DFF)
                                  .withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            'Explorer',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFE2D8FF)
                                  : const Color(0xFF6847D6),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudienceChip(bool isDark, Color backgroundColor) {
    return PopupMenuButton<String>(
      tooltip: 'Who can see this?',
      color: isDark ? const Color(0xFF1A152A) : Colors.white,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) => setState(() => _selectedVisibility = value),
      itemBuilder: (context) => _visibilityOptions
          .map(
            (option) => PopupMenuItem<String>(
              value: option.value,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.value,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1B1634),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    option.subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF8A84A3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE4DCF7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _selectedVisibility == 'Only me'
                  ? Icons.lock_outline_rounded
                  : _selectedVisibility == 'Friends'
                      ? Icons.people_outline_rounded
                      : Icons.public_rounded,
              size: 13,
              color: isDark ? Colors.white70 : const Color(0xFF5F5681),
            ),
            const SizedBox(width: 5),
            Text(
              _selectedVisibility,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF4F4671),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 1),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: isDark ? Colors.white54 : const Color(0xFF7A7592),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerCard(PlanetModel? profile, bool isDark) {
    final isFocused = _focusNode.hasFocus;
    final counterColor = _isOverLimit
        ? const Color(0xFFE24B6B)
        : _hasValidContent
            ? const Color(0xFF8E72FF)
            : (isDark ? Colors.white54 : const Color(0xFF9E9AB0));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark
            ? const Color(0xFF0F0C18).withValues(alpha: 0.82)
            : const Color(0xFFF9F6FF),
        border: Border.all(
          color: isFocused
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.75)
              : (isDark ? Colors.white10 : const Color(0xFFE3DCF6)),
          width: isFocused ? 1.4 : 1,
        ),
      ),
      child: Stack(
        children: [
          AnimatedPadding(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(top: _showAiPrompt ? 32 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _contentController,
                  focusNode: _focusNode,
                  minLines: 4,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1B1634),
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: "What's on your mind?",
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFFAAA4BE),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
                const SizedBox(height: 12),
                _buildComposerTools(profile, isDark),
                if (_selectedMood != null || _selectedLocation != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (_selectedMood != null)
                        _buildPillChip(
                          label:
                              '${_selectedMood!.emoji} ${_selectedMood!.label}',
                          backgroundColor:
                              _selectedMood!.color.withValues(alpha: 0.16),
                          foregroundColor:
                              isDark ? Colors.white : const Color(0xFF1B1634),
                        ),
                      if (_selectedLocation != null)
                        _buildPillChip(
                          label: 'Location: $_selectedLocation',
                          backgroundColor:
                              const Color(0xFF42A5F5).withValues(alpha: 0.14),
                          foregroundColor:
                              isDark ? Colors.white : const Color(0xFF255E92),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  height: 1,
                  color: isDark ? Colors.white10 : const Color(0xFFE8E1F7),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _isOverLimit ? 1 : 0,
                        child: const Text(
                          'Keep it a little shorter so it feels quick to read.',
                          style: TextStyle(
                            color: Color(0xFFE24B6B),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        color: counterColor,
                        fontSize: 11,
                        fontWeight:
                            _isOverLimit ? FontWeight.w700 : FontWeight.w500,
                      ),
                      child: Text(
                          '${_contentController.text.length}/$_kPulseMaxChars'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInBack,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0.18, -0.18),
                  end: Offset.zero,
                ).animate(animation);
                final scale =
                    Tween<double>(begin: 0.75, end: 1).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: slide,
                    child: ScaleTransition(scale: scale, child: child),
                  ),
                );
              },
              child: _showAiPrompt
                  ? _buildAiPromptButton(isDark)
                  : const SizedBox.shrink(key: ValueKey('ai-hidden')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiPromptButton(bool isDark) {
    return _ToolIconButton(
      key: const ValueKey('ai-visible'),
      icon: Icons.auto_awesome_rounded,
      color: isDark ? const Color(0xFFD8C8FF) : const Color(0xFF6B4DFF),
      tooltip: 'AI prompt',
      onTap: () => _showComingSoon('AI prompts'),
      backgroundColor:
          isDark ? const Color(0xFF241D39) : const Color(0xFFF1EBFF),
      borderColor: isDark ? Colors.white10 : const Color(0xFFE4DCF7),
    );
  }

  Widget _buildComposerTools(PlanetModel? profile, bool isDark) {
    final idleBackground =
        isDark ? const Color(0xFF181426) : const Color(0xFFF7F4FF);
    final idleBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8E0F8);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        _ToolIconButton(
          icon: _isNsfw
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: _isNsfw ? const Color(0xFFE24B6B) : const Color(0xFF6B628B),
          isActive: _isNsfw,
          tooltip: 'Sensitive content',
          onTap: () => _toggleSensitive(profile),
          backgroundColor: idleBackground,
          borderColor: idleBorder,
        ),
        _ToolIconButton(
          icon: Icons.add_photo_alternate_outlined,
          color: const Color(0xFF7C4DFF),
          isActive: _hasAttachment,
          tooltip: 'Add image or video',
          onTap: _openMediaPicker,
          backgroundColor: idleBackground,
          borderColor: idleBorder,
        ),
        _ToolIconButton(
          icon: Icons.gif_box_rounded,
          color: const Color(0xFFFF7AA2),
          tooltip: 'Add GIF',
          onTap: () => _showComingSoon('GIF picker'),
          backgroundColor: idleBackground,
          borderColor: idleBorder,
        ),
        _ToolIconButton(
          icon: Icons.poll_outlined,
          color: const Color(0xFF4FC3F7),
          tooltip: 'Create poll',
          onTap: () => _showComingSoon('Polls'),
          backgroundColor: idleBackground,
          borderColor: idleBorder,
        ),
        _ToolIconButton(
          icon: Icons.location_on_outlined,
          color: _selectedLocation != null
              ? const Color(0xFF2E9D69)
              : const Color(0xFF2AB673),
          isActive: _selectedLocation != null,
          tooltip: 'Add location',
          onTap: () => _toggleLocation(profile),
          backgroundColor: idleBackground,
          borderColor: idleBorder,
        ),
        _ToolIconButton(
          icon: Icons.sentiment_satisfied_alt_rounded,
          color: const Color(0xFFFFB020),
          isActive: _selectedMood != null,
          tooltip: 'Pick mood',
          onTap: _pickMood,
          backgroundColor: idleBackground,
          borderColor: idleBorder,
        ),
      ],
    );
  }

  Widget _buildPillChip({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F0C18).withValues(alpha: 0.82)
            : const Color(0xFFF7F3FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE3DCF6),
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Attachment preview',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF4F4671),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  _videoController?.dispose();
                  setState(() {
                    _videoController = null;
                    _videoFile = null;
                    _imageFile = null;
                  });
                },
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark ? Colors.white54 : const Color(0xFF7A7592),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _videoFile != null
                ? _buildVideoPreview()
                : AspectRatio(
                    aspectRatio: 4 / 3,
                    child: XparqImage(
                      imageUrl: _imageFile!.path,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          color: const Color(0xFFECE7FF),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Color(0xFF7C4DFF)),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildPostButton(PulseState state, PlanetModel? profile, bool isDark) {
    final isEnabled = _hasValidContent && profile != null && !state.isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: isEnabled
            ? const LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFF3D8BFF)],
              )
            : LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2A233D), const Color(0xFF2A233D)]
                    : [const Color(0xFFD9D3EA), const Color(0xFFD9D3EA)],
              ),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFF6B4DFF).withValues(alpha: 0.26),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : const [],
      ),
      child: ElevatedButton(
        onPressed: isEnabled ? () => _submitPulse(profile) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor:
              isDark ? Colors.white54 : const Color(0xFF8E87A8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: state.isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Post Pulse',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
      ),
    );
  }

  Widget _buildUploadOverlay(bool isDark) {
    return Container(
      color: Colors.black.withValues(alpha: 0.24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151224) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2C1F52).withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF7C4DFF)),
              const SizedBox(height: 10),
              Text(
                'Posting your pulse...',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1B1634),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isActive;
  final String tooltip;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;

  const _ToolIconButton({
    super.key,
    required this.icon,
    required this.color,
    this.isActive = false,
    required this.tooltip,
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? color : color.withValues(alpha: 0.72);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Ink(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.14)
                : backgroundColor.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.26)
                  : borderColor.withValues(alpha: 0.84),
            ),
          ),
          child: Icon(icon, color: iconColor, size: 15),
        ),
      ),
    );
  }
}

class _MoodRail extends StatelessWidget {
  final bool isDark;
  final List<_MoodOption> moods;
  final _MoodOption? selectedMood;
  final ValueChanged<_MoodOption> onSelected;
  final VoidCallback? onClear;

  const _MoodRail({
    required this.isDark,
    required this.moods,
    required this.selectedMood,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 56,
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF151224).withValues(alpha: 0.98)
              : Colors.white.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFDED5F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.15),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.10, 0.90, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              if (onClear != null)
                _MoodRailItem.clear(
                  isDark: isDark,
                  onTap: onClear!,
                ),
              ...moods.map(
                (mood) => _MoodRailItem(
                  mood: mood,
                  isDark: isDark,
                  isSelected: selectedMood == mood,
                  onTap: () => onSelected(mood),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodRailItem extends StatelessWidget {
  final _MoodOption? mood;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isClear;

  const _MoodRailItem({
    required _MoodOption this.mood,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
  }) : isClear = false;

  const _MoodRailItem.clear({
    required this.isDark,
    required this.onTap,
  })  : mood = null,
        isSelected = false,
        isClear = true;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isClear
        ? (isDark ? Colors.white10 : const Color(0xFFF3EEFF))
        : isSelected
            ? mood!.color.withValues(alpha: 0.20)
            : Colors.transparent;

    final borderColor = isClear
        ? (isDark ? Colors.white12 : const Color(0xFFE4DCF7))
        : isSelected
            ? mood!.color.withValues(alpha: 0.34)
            : Colors.transparent;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: isClear
              ? Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? Colors.white70 : const Color(0xFF7A7592),
                )
              : Text(
                  mood!.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
        ),
      ),
    );
  }
}

class _VisibilityOption {
  final String value;
  final String subtitle;

  const _VisibilityOption(this.value, this.subtitle);
}

class _MoodOption {
  final String label;
  final String emoji;
  final Color color;

  const _MoodOption(this.label, this.emoji, this.color);
}

class _MediaSourceSheet extends StatelessWidget {
  final bool isDark;

  const _MediaSourceSheet({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161222) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFFE0DAF1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MediaOption(
                icon: Icons.photo_library_outlined,
                label: 'Photos',
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
                onTap: () => Navigator.pop(context, 'photo'),
              ),
              _MediaOption(
                icon: Icons.videocam_outlined,
                label: 'Videos',
                color: const Color(0xFF3D8BFF),
                isDark: isDark,
                onTap: () => Navigator.pop(context, 'video'),
              ),
              _MediaOption(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                color: const Color(0xFFE24B6B),
                isDark: isDark,
                onTap: () => Navigator.pop(context, 'camera'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _MediaOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1B1634),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
