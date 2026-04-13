// lib/features/social/screens/supernova_viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/features/social/models/pulse_model.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';

class SupernovaViewerScreen extends StatefulWidget {
  final List<PulseModel> pulses;
  final int initialIndex;

  const SupernovaViewerScreen({
    super.key,
    required this.pulses,
    this.initialIndex = 0,
  });

  @override
  State<SupernovaViewerScreen> createState() => _SupernovaViewerScreenState();
}

class _SupernovaViewerScreenState extends State<SupernovaViewerScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _startStory();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startStory() {
    _progressController.reset();
    _progressController.forward();
  }

  void _nextStory() {
    if (_currentIndex < widget.pulses.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStory();
    } else {
      context.pop();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStory();
    }
  }

  void _onTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    if (dx < screenWidth / 3) {
      _previousStory();
    } else if (dx > 2 * screenWidth / 3) {
      _nextStory();
    } else {
      // Pause/Resume on middle tap
      if (_progressController.isAnimating) {
        _progressController.stop();
      } else {
        _progressController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: (_) => _progressController.stop(),
        onLongPressEnd: (_) => _progressController.forward(),
        child: Stack(
          children: [
            // Story Content (Images/Videos)
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.pulses.length,
              itemBuilder: (context, index) {
                final pulse = widget.pulses[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (pulse.imageUrl != null && pulse.imageUrl!.isNotEmpty)
                      XparqImage(imageUrl: pulse.imageUrl!, fit: BoxFit.contain)
                    else
                      Container(
                        color: const Color(0xFF0D1218),
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            pulse.content,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // Gradient overlay for top/bottom text
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.6),
                            ],
                            stops: const [0.0, 0.2, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Content Overlay (if image has text)
                    if (pulse.imageUrl != null && pulse.imageUrl!.isNotEmpty)
                      Positioned(
                        bottom: 60,
                        left: 20,
                        right: 20,
                        child: Text(
                          pulse.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                );
              },
            ),

            // Progress Bars
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Row(
                  children: List.generate(widget.pulses.length, (index) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: index == _currentIndex
                                ? _progressController.value
                                : (index < _currentIndex ? 1.0 : 0.0),
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 2,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Top Bar (User Info & Close)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 30, left: 16, right: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          widget.pulses[_currentIndex].authorAvatar.isNotEmpty
                          ? XparqImage.getImageProvider(
                              widget.pulses[_currentIndex].authorAvatar,
                            )
                          : null,
                      child: widget.pulses[_currentIndex].authorAvatar.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.pulses[_currentIndex].authorName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _formatTime(widget.pulses[_currentIndex].createdAt),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => context.pop(),
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

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
