import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

class NebulaPickerScreen extends ConsumerStatefulWidget {
  const NebulaPickerScreen({super.key});

  @override
  ConsumerState<NebulaPickerScreen> createState() => _NebulaPickerScreenState();
}

class _NebulaPickerScreenState extends ConsumerState<NebulaPickerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Camera state
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;

  // UI state
  int _currentModeIndex = 1; // STORY
  final List<String> _modes = ['POST', 'STORY', 'REEL', 'LIVE'];
  bool _isRecording = false;
  bool _isStartingRecording = false; // Phase 3: Wait for start to finish
  bool _wantsToStopRecording = false; // Phase 3: Catch early release
  bool _isPressing = false; // Phase 3: Track touch state
  bool _isLocked = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  double _zoomLevel = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;

  // Filters state
  int _selectedFilterIndex = 2; // Normal/Center
  final List<String> _filters = [
    'Classic',
    'B&W',
    'Normal',
    'Vibrant',
    'Cosmic',
  ];

  // Animation & Scroll
  late PageController _modePageController;
  late PageController _filterPageController;

  @override
  void initState() {
    super.initState();
    // Phase 3: Force system portrait
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    WidgetsBinding.instance.addObserver(this);
    _modePageController = PageController(
      initialPage: _currentModeIndex,
      viewportFraction: 0.25,
    );
    _filterPageController = PageController(
      initialPage: _selectedFilterIndex,
      viewportFraction: 0.2,
    );
    _initCameras();
    _requestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Restore orientation if needed, or keep it locked
    _cameraController?.dispose();
    _modePageController.dispose();
    _filterPageController.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera(cameraController.description);
    }
  }

  Future<void> _requestPermissions() async {
    await PhotoManager.requestPermissionExtend();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      debugPrint('Senior Camera: Found ${_cameras.length} cameras');
      for (var i = 0; i < _cameras.length; i++) {
        debugPrint(
          'Camera[$i]: name=${_cameras[i].name}, dir=${_cameras[i].lensDirection}, sensor=${_cameras[i].sensorOrientation}',
        );
      }

      if (_cameras.isNotEmpty) {
        // Find main back camera (usually id "0")
        CameraDescription mainCamera = _cameras[0];
        try {
          mainCamera = _cameras.firstWhere(
            (c) =>
                c.lensDirection == CameraLensDirection.back &&
                (c.name == '0' || c.name.contains('back')),
            orElse: () => _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
            ),
          );
        } catch (_) {
          mainCamera = _cameras[0];
        }

        _selectedCameraIndex = _cameras.indexOf(mainCamera);
        debugPrint(
          'Senior Camera: Selected Main Camera Index $_selectedCameraIndex (Name: ${mainCamera.name})',
        );
        _setupCamera(mainCamera);
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _setupCamera(CameraDescription cameraDescription) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }
    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.max,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      // Expert Step: Absolute orientation lock to Portrait
      await _cameraController!.lockCaptureOrientation(
        DeviceOrientation.portraitUp,
      );

      _maxZoom = await _cameraController!.getMaxZoomLevel();
      _minZoom = await _cameraController!.getMinZoomLevel();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Error setup camera: $e');
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;

    // Switch camera
    await _setupCamera(_cameras[_selectedCameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    _flashMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _cameraController!.setFlashMode(_flashMode);
    setState(() {});
  }

  // --- Capture Logic ---

  Future<void> _takePhoto() async {
    if (_cameraController == null || !_isCameraInitialized || _isRecording) {
      return;
    }
    try {
      debugPrint('Senior Camera: Taking picture...');
      final XFile photo = await _cameraController!.takePicture();
      debugPrint('Senior Camera: Picture saved to ${photo.path}');

      if (mounted) {
        debugPrint('Senior Camera: Returning XFile ${photo.path} to caller');
        context.pop({'file': photo, 'mode': _modes[_currentModeIndex]});
      }
    } catch (e) {
      debugPrint('Error photo: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null ||
        !_isCameraInitialized ||
        _isRecording ||
        _isStartingRecording) {
      return;
    }
    if (!_isPressing) return;

    try {
      setState(() {
        _isStartingRecording = true;
        _wantsToStopRecording = false;
      });

      // Senior Step: Explicitly lock orientation to PORTRAIT before starting encoder
      await _cameraController!.lockCaptureOrientation(
        DeviceOrientation.portraitUp,
      );

      // Senior Step: Warm up the encoder
      await _cameraController!.prepareForVideoRecording();

      // Senior Step: Final check before hitting native start
      if (!_isPressing && _isStartingRecording) {
        _resetRecordingState();
        return;
      }

      await _cameraController!.startVideoRecording();

      if (mounted) {
        setState(() {
          _isRecording = true;
          _isStartingRecording = false;
          _recordSeconds = 0;
          _isLocked = false;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) setState(() => _recordSeconds++);
        });

        if (_wantsToStopRecording) {
          _stopRecording();
        }
      }
    } catch (e) {
      debugPrint('Senior Camera Error (Start): $e');
      _resetRecordingState();
    }
  }

  Future<void> _stopRecording() async {
    if (_isStartingRecording) {
      _wantsToStopRecording = true;
      return;
    }
    if (!_isRecording) return;

    try {
      // Direct controller check to avoid "stop called on idle" crashes
      if (_cameraController!.value.isRecordingVideo) {
        final XFile file = await _cameraController!.stopVideoRecording();
        _recordTimer?.cancel();

        // Unlock orientation after capture is finished
        await _cameraController!.unlockCaptureOrientation();

        if (mounted) {
          setState(() {
            _isRecording = false;
            _isLocked = false;
            _wantsToStopRecording = false;
          });
          context.pop({'file': file, 'mode': _modes[_currentModeIndex]});
        }
      } else {
        _resetRecordingState();
      }
    } catch (e) {
      debugPrint('Senior Camera Error (Stop): $e');
      _resetRecordingState();
    }
  }

  void _resetRecordingState() {
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isStartingRecording = false;
      _wantsToStopRecording = false;
      _isLocked = false;
    });
    _recordTimer?.cancel();
  }

  void _handleZoom(double verticalDrag) {
    if (_cameraController == null) return;
    double sensitivity = 0.005;
    double newZoom = (_zoomLevel - (verticalDrag * sensitivity)).clamp(
      _minZoom,
      _maxZoom,
    );
    if (newZoom != _zoomLevel) {
      _zoomLevel = newZoom;
      _cameraController!.setZoomLevel(_zoomLevel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview with Verified Full-screen Wrap
          _buildCameraPreview(),

          // 2. Interaction Layer for Swipe-up Gallery
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (details) {
                if (_isRecording || _isStartingRecording) return;
                if (details.localPosition.dy >
                    MediaQuery.sizeOf(context).height * 0.7) {
                  return;
                }

                if (details.primaryDelta! < -15) {
                  HapticFeedback.mediumImpact();
                  // Album logic...
                }
              },
            ),
          ),

          // 3. UI Content Layers
          _buildTopBar(),
          _buildSideActions(),
          _buildBottomControls(),

          if (_isRecording || _isStartingRecording) _buildRecordingIndicator(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
      );
    }

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: constraints.maxWidth,
              height:
                  constraints.maxWidth * _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 5,
      left: 10,
      right: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () => context.pop(),
          ),
          IconButton(
            icon: Icon(
              _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
              color: Colors.white,
              size: 26,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _toggleFlash();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 26),
            onPressed: () => HapticFeedback.lightImpact(),
          ),
        ],
      ),
    );
  }

  Widget _buildSideActions() {
    return Positioned(
      right: 10,
      top: MediaQuery.sizeOf(context).height * 0.2,
      child: Column(
        children: [
          _sideIconButton(Icons.text_fields, 'Aa'),
          _sideIconButton(Icons.all_inclusive, 'Boomerang'),
          _sideIconButton(Icons.grid_view, 'Layout'),
          _sideIconButton(Icons.keyboard_arrow_down, 'More'),
        ],
      ),
    );
  }

  Widget _sideIconButton(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: () => HapticFeedback.lightImpact(),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black26,
          padding: const EdgeInsets.all(10),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.5), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Filter Selector (Row above Shutter)
            SizedBox(
              height: 70,
              child: PageView.builder(
                controller: _filterPageController,
                itemCount: _filters.length,
                onPageChanged: (index) {
                  setState(() => _selectedFilterIndex = index);
                  HapticFeedback.selectionClick();
                },
                itemBuilder: (context, index) {
                  bool isSelected = _selectedFilterIndex == index;
                  return Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 56 : 42,
                      height: isSelected ? 56 : 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: isSelected ? 3 : 1,
                        ),
                        color: Colors.white12,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.auto_awesome,
                              color: Colors.white54,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 15),

            // Capture Row (Album - Shutter - Flip)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _albumThumbnail(),
                  _buildAdvancedShutter(),
                  IconButton(
                    icon: const Icon(
                      Icons.cached,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _toggleCamera();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Mode Selector
            SizedBox(
              height: 30,
              child: PageView.builder(
                controller: _modePageController,
                itemCount: _modes.length,
                onPageChanged: (index) {
                  setState(() => _currentModeIndex = index);
                  HapticFeedback.selectionClick();
                },
                itemBuilder: (context, index) {
                  bool isSelected = _currentModeIndex == index;
                  return Center(
                    child: Text(
                      _modes[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                        letterSpacing: 1.2,
                        shadows: const [
                          Shadow(blurRadius: 10, color: Colors.black),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _albumThumbnail() {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Colors.white24,
            child: const Icon(Icons.photo, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedShutter() {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        setState(() => _isPressing = true);
        // Start long press timer for video
        Timer(const Duration(milliseconds: 300), () {
          if (_isPressing &&
              !_isRecording &&
              !_isLocked &&
              !_isStartingRecording) {
            HapticFeedback.heavyImpact();
            _startRecording();
          }
        });
      },
      onPointerUp: (_) {
        setState(() => _isPressing = false);
        if (_isRecording || _isStartingRecording) {
          if (!_isLocked) {
            HapticFeedback.mediumImpact();
            _stopRecording();
          }
        } else {
          // It was a tap
          HapticFeedback.mediumImpact();
          _takePhoto();
        }
      },
      onPointerMove: (event) {
        if (_isRecording) {
          _handleZoom(event.localDelta.dy);
          if (event.localDelta.dx > 50 && !_isLocked) {
            setState(() => _isLocked = true);
            HapticFeedback.heavyImpact();
          }
        }
      },
      child: Hero(
        tag: 'shutter',
        child: Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: (_isRecording || _isStartingRecording)
                  ? Colors.red
                  : Colors.white,
              width: 5,
            ),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: (_isRecording || _isStartingRecording) ? 32 : 72,
              height: (_isRecording || _isStartingRecording) ? 32 : 72,
              decoration: BoxDecoration(
                color: (_isRecording || _isStartingRecording)
                    ? Colors.red
                    : Colors.white,
                borderRadius: BorderRadius.circular(
                  (_isRecording || _isStartingRecording) ? 8 : 36,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fiber_manual_record,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(_recordSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
