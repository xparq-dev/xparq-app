// lib/features/social/screens/camera_screen.dart

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final String initialMode;
  const CameraScreen({super.key, this.initialMode = 'photo'});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  List<CameraDescription> _allCameras = [];
  List<CameraDescription> _backCameras = [];
  CameraDescription? _mainBackCamera;
  CameraDescription? _ultraWideCamera;
  CameraDescription? _telephotoCamera;
  double? _stableSensorRatio;

  CameraController? _controller;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isSwitchingMode = false;

  // Modes: PHOTO, VIDEO, WARP GEAR, SUPERNOVA
  late String _currentMode;

  // Aspect Ratio: 3:4, 9:16, 1:1, Full
  late String _currentAspectRatio;
  final List<String> _aspectRatios = ['3:4', '9:16', '1:1', 'Full'];

  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _showGrid = false;

  // Zoom Refinement (4 levels: 0.5, 1, 2, 10)
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 10.0;
  double _baseZoom = 1.0;

  // Timer
  int _timerSeconds = 0;
  int _countdown = 0;
  Timer? _countdownTimer;

  // Filter
  String _activeFilter = 'None';
  final List<String> _filters = [
    'None',
    'Cosmic Glow',
    'Nebula Tint',
    'Stellar',
    'Void',
  ];

  bool _isHoldingShutter = false;

  // Focus state
  Offset? _focusPoint;
  bool _showFocusCircle = false;
  late AnimationController _focusPulseController;

  Timer? _recordTimer;
  int _recordSeconds = 0;
  static const int maxVideoDurationSeconds = 30;
  static const int warpGearDurationSeconds = 2;

  Timer? _shutterTimer;
  bool _wasLongPress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _currentMode = widget.initialMode.toUpperCase();
    _currentAspectRatio = _currentMode == 'SUPERNOVA' ? '9:16' : '3:4';

    // Lock UI to Portrait for camera stability
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _setupCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    _countdownTimer?.cancel();
    _shutterTimer?.cancel();
    _controller?.dispose();
    _focusPulseController.dispose();

    // Reset orientation preference
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _onNewCameraSelected(_controller!.description);
    }
  }

  Future<void> _setupCamera() async {
    _allCameras = await availableCameras();
    if (_allCameras.isNotEmpty) {
      _backCameras = _allCameras
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .toList();

      if (_backCameras.isNotEmpty) {
        // Identify Main Wide sensor
        try {
          _mainBackCamera = _backCameras.firstWhere(
            (c) => c.name == '0' || c.name.toLowerCase().contains('wide'),
            orElse: () => _backCameras[0],
          );
        } catch (_) {
          _mainBackCamera = _backCameras[0];
        }

        // Identify Ultra-wide sensor
        try {
          _ultraWideCamera = _backCameras.firstWhere(
            (c) =>
                c.name == '2' ||
                c.name.toLowerCase().contains('ultra') ||
                c.name.toLowerCase().contains('wide_angle'),
          );
        } catch (_) {}

        // Identify Telephoto sensor
        try {
          _telephotoCamera = _backCameras.firstWhere(
            (c) =>
                c.name == '1' ||
                c.name == '3' ||
                c.name.toLowerCase().contains('tele'),
          );
        } catch (_) {}

        // Fallback heuristics if naming failed
        if (_ultraWideCamera == null && _backCameras.length > 1) {
          _ultraWideCamera = _backCameras[1];
        }
        if (_telephotoCamera == null && _backCameras.length > 2) {
          _telephotoCamera = _backCameras[2];
        }
      }

      final initialCamera = _mainBackCamera ?? _allCameras[0];
      _cameraIndex = _allCameras.indexOf(initialCamera);
      _onNewCameraSelected(initialCamera);
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    if (_isSwitchingMode) return;
    setState(() => _isSwitchingMode = true);

    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    // ✅ Samsung fix: ไม่ใส่ imageFormatGroup สำหรับ video
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: true,
    );

    _controller!.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await _controller!.initialize();
      // ✅ Expert Step: Lock orientation immediately to prevent "sensor jump" during recording
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _stableSensorRatio = _controller!.value.aspectRatio;
      await _controller!.setFlashMode(_flashMode);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _isSwitchingMode = false;
      });
    }
  }

  Future<void> _handleZoom(ScaleUpdateDetails details) async {
    if (_controller == null || !_isInitialized || _isSwitchingMode) return;

    double targetEffectiveZoom = (_baseZoom * details.scale).clamp(0.5, 10.0);

    CameraDescription? targetSensor;
    double physicalZoom = 1.0;

    if (targetEffectiveZoom < 0.9 && _ultraWideCamera != null) {
      targetSensor = _ultraWideCamera;
      physicalZoom = (targetEffectiveZoom / 0.5).clamp(1.0, 2.0);
    } else if (targetEffectiveZoom > 2.1 && _telephotoCamera != null) {
      targetSensor = _telephotoCamera;
      physicalZoom = (targetEffectiveZoom / 2.0).clamp(1.0, 5.0);
    } else {
      targetSensor = _mainBackCamera;
      physicalZoom = targetEffectiveZoom.clamp(1.0, 10.0);
    }

    if (targetSensor != null && _controller?.description != targetSensor) {
      HapticFeedback.mediumImpact();
      await _onNewCameraSelected(targetSensor);
      _cameraIndex = _allCameras.indexOf(targetSensor);
    }

    if ((targetEffectiveZoom - _currentZoom).abs() > 0.01) {
      _currentZoom = targetEffectiveZoom;
      _controller!.setZoomLevel(physicalZoom.clamp(_minZoom, _maxZoom));
      setState(() {});
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_isInitialized) return;
    FlashMode next = _flashMode == FlashMode.off
        ? FlashMode.always
        : (_flashMode == FlashMode.always ? FlashMode.auto : FlashMode.off);
    try {
      await _controller!.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (_) {}
  }

  Future<void> _openGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      context.pushReplacementNamed('createPulse', extra: {'image': image});
    }
  }

  Future<void> _handleFocus(TapUpDetails details) async {
    if (_controller == null || !_isInitialized || _isRecording) return;
    final size = MediaQuery.of(context).size;
    final double x = details.localPosition.dx / size.width;
    final double y = details.localPosition.dy / size.height;

    setState(() {
      _focusPoint = details.localPosition;
      _showFocusCircle = true;
    });
    _focusPulseController.forward(from: 0);

    try {
      await _controller!.setFocusPoint(Offset(x, y));
      await _controller!.setExposurePoint(Offset(x, y));
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showFocusCircle = false);
      });
    } catch (_) {}
  }

  Future<void> _handleCaptureTap() async {
    if (_controller == null || !_isInitialized || _countdown > 0) return;

    if (_isRecording) {
      await _stopVideoRecording();
      return;
    }

    if (_timerSeconds > 0) {
      _startCountdown();
    } else {
      _performCapture();
    }
  }

  void _startCountdown() {
    setState(() => _countdown = _timerSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _countdown = 0;
          timer.cancel();
          _performCapture();
        }
      });
    });
  }

  Future<void> _performCapture() async {
    if (_currentMode == 'PHOTO') {
      try {
        final XFile file = await _controller!.takePicture();
        if (mounted) {
          context.pushNamed(
            'createPulse',
            extra: {'image': file, 'isSupernova': _currentMode == 'SUPERNOVA'},
          );
        }
      } catch (_) {}
    } else {
      // VIDEO or WARP GEAR
      if (!_isRecording) {
        _startVideoRecording();
      } else {
        _stopVideoRecording();
      }
    }
  }

  // ✅ ฟังก์ชันเดียว ไม่ซ้ำ + lock orientation ก่อน record ทุกครั้ง
  Future<void> _startVideoRecording() async {
    if (_controller == null || !_isInitialized || _isRecording) return;
    try {
      // ✅ Senior Step: Explicitly lock orientation to PORTRAIT before starting encoder
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      // ✅ Expert Step: Warm up the video encoder before starting (from nebula_picker_screen logic)
      await _controller!.prepareForVideoRecording();

      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      _startVideoRecordingTimer();
    } catch (e) {
      debugPrint('Recording error: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_isInitialized || !_isRecording) return;
    try {
      final XFile file = await _controller!.stopVideoRecording();
      _recordTimer?.cancel();
      setState(() => _isRecording = false);

      if (mounted) {
        final bool isSupernova = _currentMode == 'SUPERNOVA';

        XFile finalVideoFile;
        if (!kIsWeb) {
          // ✅ Samsung A54 fix: หมุน video กลับ 90 องศา หลังบันทึกเสร็จ
          final String inputPath = file.path;
          final String outputPath = inputPath.replaceAll('.mp4', '_fixed.mp4');

          await FFmpegKit.execute(
            '-i $inputPath -vf "transpose=1" -c:a copy $outputPath',
          );
          finalVideoFile = XFile(outputPath);
        } else {
          finalVideoFile = file;
        }

        if (mounted) {
          final Map<String, dynamic> extra = _currentMode == 'WARP GEAR'
              ? {
                  'video': finalVideoFile,
                  'isWarpGear': true,
                  'isSupernova': isSupernova,
                }
              : {'video': finalVideoFile, 'isSupernova': isSupernova};
          context.pushNamed('createPulse', extra: extra);
        }
      }
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }
  }

  void _startVideoRecordingTimer() {
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      int limit = _currentMode == 'WARP GEAR'
          ? warpGearDurationSeconds
          : maxVideoDurationSeconds;

      if (_recordSeconds >= limit) {
        timer.cancel();
        _stopVideoRecording();
      } else {
        setState(() => _recordSeconds++);
      }
    });
  }

  double _getAspectRatioValue() {
    switch (_currentAspectRatio) {
      case '3:4':
        return 3 / 4;
      case '9:16':
        return 9 / 16;
      case '1:1':
        return 1.0;
      case 'Full':
      default:
        final size = MediaQuery.of(context).size;
        return size.width / size.height;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final double activeAspectRatio = _getAspectRatioValue();

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final double screenHeight = constraints.maxHeight;
          final double screenAspectRatio = screenWidth / screenHeight;

          final double targetAspectRatio = (_currentAspectRatio == 'Full')
              ? screenAspectRatio
              : activeAspectRatio;

          final double finalAspectRatio =
              (targetAspectRatio <= 0 || targetAspectRatio.isNaN)
              ? screenAspectRatio
              : targetAspectRatio;

          return GestureDetector(
            onScaleStart: (_) => _baseZoom = _currentZoom,
            onScaleUpdate: _handleZoom,
            onTapUp: _handleFocus,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ✅ Preview แบบตรง ไม่มี RotatedBox / NativeDeviceOrientationReader
                // lockCaptureOrientation จัดการ orientation ให้ทั้ง preview และวิดีโอ
                Center(
                  child: AspectRatio(
                    aspectRatio: finalAspectRatio,
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height:
                              constraints.maxWidth *
                              (_stableSensorRatio ??
                                  _controller!.value.aspectRatio),
                          child: CameraPreview(_controller!),
                        ),
                      ),
                    ),
                  ),
                ),

                _buildFilterOverlay(),
                if (_showGrid) _buildGridOverlay(),
                _buildCosmicGradient(),

                if (_showFocusCircle && _focusPoint != null)
                  Positioned(
                    left: _focusPoint!.dx - 35,
                    top: _focusPoint!.dy - 35,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 1.6, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _focusPulseController,
                          curve: Curves.elasticOut,
                        ),
                      ),
                      child: _buildFocusCircle(),
                    ),
                  ),

                SafeArea(
                  child: Column(
                    children: [
                      _buildTopControls(),
                      const Spacer(),
                      _buildAspectRatioControls(),
                      const SizedBox(height: 16),
                      _buildZoomControls(),
                      const SizedBox(height: 16),
                      if (_countdown > 0) _buildCountdownUI(),
                      _buildBottomSection(),
                    ],
                  ),
                ),

                if (_isSwitchingMode)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterOverlay() {
    if (_activeFilter == 'None') return const SizedBox.shrink();
    Color c = Colors.transparent;
    double o = 0.2;
    switch (_activeFilter) {
      case 'Cosmic Glow':
        c = Colors.blue;
        break;
      case 'Nebula Tint':
        c = Colors.purple;
        break;
      case 'Stellar':
        c = Colors.orange;
        break;
      case 'Void':
        c = Colors.black;
        o = 0.4;
        break;
    }
    return Container(color: c.withValues(alpha: o));
  }

  Widget _buildGridOverlay() {
    return Stack(
      children: [
        Row(
          children: [
            const Spacer(),
            Container(width: 0.5, color: Colors.white24),
            const Spacer(),
            Container(width: 0.5, color: Colors.white24),
            const Spacer(),
          ],
        ),
        Column(
          children: [
            const Spacer(),
            Container(height: 0.5, color: Colors.white24),
            const Spacer(),
            Container(height: 0.5, color: Colors.white24),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  Widget _buildCosmicGradient() {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.4),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
              stops: const [0.0, 0.2, 0.8, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _iconBtn(icon: Icons.close, onTap: () => context.pop()),
          _iconBtn(icon: _getFlashIcon(), onTap: _toggleFlash),
          _iconBtn(icon: Icons.settings_outlined, onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildFocusCircle() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.0,
        ),
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_ultraWideCamera != null) ...[
            _zoomButton('.5', 0.5),
            const SizedBox(width: 8),
          ],
          _zoomButton('1x', 1.0),
          const SizedBox(width: 8),
          _zoomButton('2', 2.0),
          const SizedBox(width: 8),
          _zoomButton('10', 10.0),
        ],
      ),
    );
  }

  Widget _buildAspectRatioControls() {
    if (_isRecording) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: _aspectRatios.map((ratio) => _ratioButton(ratio)).toList(),
      ),
    );
  }

  Widget _ratioButton(String label) {
    final bool isSelected = _currentAspectRatio == label;
    return GestureDetector(
      onTap: () => setState(() => _currentAspectRatio = label),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.amber : Colors.white,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _zoomButton(String label, double value) {
    bool isSelected = (_currentZoom - value).abs() < 0.1;

    if (value == 0.5 && _ultraWideCamera != null) {
      isSelected = _controller?.description == _ultraWideCamera;
    } else if (value == 1.0 && _mainBackCamera != null) {
      isSelected =
          _controller?.description == _mainBackCamera &&
          (_currentZoom - 1.0).abs() < 0.1;
    } else if (value >= 2.0 && _telephotoCamera != null) {
      isSelected = _controller?.description == _telephotoCamera;
    }

    return GestureDetector(
      onTap: () async {
        if (_controller == null || !_isInitialized) return;

        if (value == 0.5 && _ultraWideCamera != null) {
          if (_controller?.description != _ultraWideCamera) {
            await _onNewCameraSelected(_ultraWideCamera!);
            _cameraIndex = _allCameras.indexOf(_ultraWideCamera!);
          }
          await _controller!.setZoomLevel(1.0);
          setState(() => _currentZoom = 0.5);
          return;
        }

        if (value == 1.0 && _mainBackCamera != null) {
          if (_controller?.description != _mainBackCamera) {
            await _onNewCameraSelected(_mainBackCamera!);
            _cameraIndex = _allCameras.indexOf(_mainBackCamera!);
          }
          await _controller!.setZoomLevel(1.0);
          setState(() => _currentZoom = 1.0);
          return;
        }

        if (value >= 2.0 && _telephotoCamera != null) {
          if (_controller?.description != _telephotoCamera) {
            await _onNewCameraSelected(_telephotoCamera!);
            _cameraIndex = _allCameras.indexOf(_telephotoCamera!);
          }
          await _controller!.setZoomLevel(1.0);
          setState(() => _currentZoom = value);
          return;
        }

        double target = value;
        if (value == 0.5) target = 1.0;

        final clampedTarget = target.clamp(_minZoom, _maxZoom);
        await _controller!.setZoomLevel(clampedTarget);
        setState(() => _currentZoom = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black38,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  void _showFilterPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (c) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 25),
          height: 200,
          child: Column(
            children: [
              const Text(
                'COSMIC FILTERS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  itemBuilder: (c, i) {
                    final f = _filters[i];
                    final isS = _activeFilter == f;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _activeFilter = f);
                        Navigator.pop(c);
                      },
                      child: Container(
                        margin: const EdgeInsetsDirectional.only(end: 20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isS
                              ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: isS
                                ? const Color(0xFF00E5FF)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            f,
                            style: TextStyle(
                              color: isS
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: isS
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
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
    );
  }

  Widget _buildCountdownUI() {
    return Center(
      child: Text(
        '$_countdown',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 100,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 15, color: Colors.black54)],
        ),
      ),
    );
  }

  void _handleShutterDown() {
    if (!_isInitialized || _controller == null || _countdown > 0) return;

    setState(() {
      _isHoldingShutter = true;
      _wasLongPress = false;
    });

    if (_currentMode == 'VIDEO' || _currentMode == 'WARP GEAR') {
      if (!_isRecording) {
        _startVideoRecording();
        _shutterTimer = Timer(const Duration(milliseconds: 300), () {
          _wasLongPress = true;
        });
      }
    } else {
      _shutterTimer = Timer(const Duration(milliseconds: 300), () {
        if (_isHoldingShutter) {
          _wasLongPress = true;
          _startVideoRecording();
        }
      });
    }
  }

  void _handleShutterUp() {
    if (!_isHoldingShutter) return;

    _shutterTimer?.cancel();
    final bool holdingWhenStopped = _wasLongPress;

    setState(() => _isHoldingShutter = false);

    if (_isRecording) {
      if (holdingWhenStopped) {
        _stopVideoRecording();
      }
    } else {
      if (!holdingWhenStopped) {
        _handleCaptureTap();
      }
    }
  }

  void _handleShutterCancel() {
    _shutterTimer?.cancel();
    if (_isRecording && _wasLongPress) {
      _stopVideoRecording();
    }
    setState(() => _isHoldingShutter = false);
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _optionButton(icon: _getFlashIcon(), onTap: _toggleFlash),
                const SizedBox(width: 40),
                _optionButton(
                  icon: Icons.grid_on,
                  onTap: () => setState(() => _showGrid = !_showGrid),
                  isActive: _showGrid,
                ),
                const SizedBox(width: 40),
                _optionButton(
                  icon: Icons.timer,
                  onTap: () => setState(
                    () => _timerSeconds = _timerSeconds == 0
                        ? 3
                        : (_timerSeconds == 3
                              ? 5
                              : (_timerSeconds == 5 ? 10 : 0)),
                  ),
                  badge: _timerSeconds > 0 ? '${_timerSeconds}s' : null,
                ),
                const SizedBox(width: 40),
                _optionButton(
                  icon: Icons.auto_awesome,
                  onTap: _showFilterPicker,
                  isActive: _activeFilter != 'None',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 45),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _gestureButton(
                      icon: Icons.photo_library,
                      onTap: _openGallery,
                    ),
                  ),
                ),
                GestureDetector(
                  onTapDown: (_) => _handleShutterDown(),
                  onTapUp: (_) => _handleShutterUp(),
                  onTapCancel: _handleShutterCancel,
                  child: _buildNovaShutter(),
                ),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _gestureButton(
                      icon: Icons.cached,
                      onTap: () {
                        if (_isRecording) return;
                        if (_allCameras.length < 2) return;
                        _cameraIndex = (_cameraIndex + 1) % _allCameras.length;
                        _onNewCameraSelected(_allCameras[_cameraIndex]);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isRecording) ...[
            const SizedBox(height: 15),
            Text(
              'RECORDING: ${_recordSeconds}s / ${(_currentMode == 'WARP GEAR' ? warpGearDurationSeconds : maxVideoDurationSeconds)}s',
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gestureButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildNovaShutter() {
    final bool isVideoMode =
        _currentMode == 'VIDEO' || _currentMode == 'WARP GEAR';
    final Color accentColor = isVideoMode ? Colors.redAccent : Colors.white;

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white10,
        border: Border.all(color: Colors.white30, width: 1),
      ),
      padding: const EdgeInsets.all(8),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: _isRecording || _isHoldingShutter ? 0.9 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white12,
            border: Border.all(color: Colors.white, width: 4),
          ),
          padding: const EdgeInsets.all(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_isRecording ? 8 : 40),
              color: accentColor,
              boxShadow: [
                if (!_isRecording)
                  const BoxShadow(
                    color: Colors.black38,
                    blurRadius: 15,
                    offset: Offset(0, 6),
                  ),
              ],
            ),
            child: _currentMode == 'WARP GEAR'
                ? Center(
                    child: Icon(
                      Icons.bolt_rounded,
                      color: _isRecording ? Colors.white : Colors.black87,
                      size: 38,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _optionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF00E5FF) : Colors.white70,
            size: 26,
          ),
          if (badge != null)
            Positioned(
              top: -10,
              right: -15,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Color(0xFF00E5FF),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.auto:
        return Icons.flash_auto;
      default:
        return Icons.flash_off;
    }
  }
}
