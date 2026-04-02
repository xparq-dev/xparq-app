import 'dart:io' as io;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class XparqImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const XparqImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = _buildImage(context);

    // ✅ เพิ่ม borderRadius (สำคัญมาก)
    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildImage(BuildContext context) {
    // 🔹 local file (ไม่ใช้ existsSync แล้ว)
    if (_isLocalFile(imageUrl)) {
      final path = imageUrl.replaceFirst('file://', '');
      return Image.file(
        io.File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _error(),
      );
    }

    // 🔹 web blob / data
    if (_isWebMemoryImage(imageUrl)) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _error(),
      );
    }

    // 🔹 empty
    if (imageUrl.isEmpty) {
      return _placeholder();
    }

    // 🔹 network (cached)
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _error(),
    );
  }

  // ======================
  // Helpers
  // ======================

  bool _isLocalFile(String url) {
    return !kIsWeb && url.startsWith('file://');
  }

  bool _isWebMemoryImage(String url) {
    return kIsWeb &&
        (url.startsWith('blob:') || url.startsWith('data:'));
  }

  Widget _placeholder() {
    return placeholder ??
        Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(Icons.image, color: Colors.white24),
          ),
        );
  }

  Widget _error() {
    return errorWidget ??
        Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white24),
          ),
        );
  }

  /// 🔥 ใช้กับ DecorationImage / Avatar
  static ImageProvider getImageProvider(String imageUrl) {
    if (!kIsWeb && imageUrl.startsWith('file://')) {
      final path = imageUrl.replaceFirst('file://', '');
      return FileImage(io.File(path));
    }

    if (kIsWeb &&
        (imageUrl.startsWith('blob:') || imageUrl.startsWith('data:'))) {
      return NetworkImage(imageUrl);
    }

    return CachedNetworkImageProvider(imageUrl);
  }
}