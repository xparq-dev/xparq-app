// lib/features/profile/widgets/profile_photo_gallery.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:xparq_app/core/widgets/xparq_image.dart';

class ProfilePhotoGallery extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const ProfilePhotoGallery({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  @override
  State<ProfilePhotoGallery> createState() => _ProfilePhotoGalleryState();
}

class _ProfilePhotoGalleryState extends State<ProfilePhotoGallery> {
  late PageController _pageController;
  late int _currentIndex;

  // We use a large number to simulate infinite looping
  static const int _loopFactor = 10000;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(
      initialPage: (widget.photos.length * _loopFactor ~/ 2) + widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 0. Cinematic Backdrop Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                color: Colors.black.withOpacity(0.75),
              ),
            ),
          ),
          // Main Gallery
          GestureDetector(
            onVerticalDragUpdate: (details) {
              // Swipe up to close
              if (details.primaryDelta! < -20) {
                Navigator.pop(context);
              }
            },
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index % widget.photos.length;
                });
              },
              itemBuilder: (context, index) {
                final photoIndex = index % widget.photos.length;
                // Only the actual initial page should have the shared hero tag
                // to avoid "multiple heroes" error in a looping PageView.
                final bool isInitialPage = index == (widget.photos.length * _loopFactor ~/ 2) + widget.initialIndex;
                final String heroTag = isInitialPage ? 'profile_photo_hero' : 'photo_gallery_$index';

                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Hero(
                      tag: heroTag,
                      child: XparqImage(
                        imageUrl: widget.photos[photoIndex],
                        fit: BoxFit.contain,
                        width: MediaQuery.of(context).size.width,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Top Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Page Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.photos.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Close Button
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Hint
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0,
            right: 0,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard_arrow_up, color: Colors.white70),
                  Text(
                    'Swipe up to close',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
