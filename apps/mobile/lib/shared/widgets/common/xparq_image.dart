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

  const XparqImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb &&
        (imageUrl.startsWith('file://') || io.File(imageUrl).existsSync())) {
      final path = imageUrl.replaceFirst('file://', '');
      return Image.file(
        io.File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ??
              Container(
                color: Colors.grey[900],
                child: const Icon(Icons.broken_image, color: Colors.white24),
              );
        },
      );
    }

    if (kIsWeb &&
        (imageUrl.startsWith('blob:') || imageUrl.startsWith('data:'))) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ?? const Icon(Icons.error_outline),
      );
    }

    if (imageUrl.isEmpty) {
      return placeholder ??
          Container(
            color: Colors.grey[900],
            child: const Icon(Icons.image, color: Colors.white24),
          );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorWidget: (context, url, error) =>
          errorWidget ?? const Icon(Icons.error_outline),
    );
  }

  /// Helper to get ImageProvider for properties that require it
  static ImageProvider getImageProvider(String imageUrl) {
    if (!kIsWeb &&
        (imageUrl.startsWith('file://') || io.File(imageUrl).existsSync())) {
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
