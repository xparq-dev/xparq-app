import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/profile/services/image_upload_service.dart';

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService();
});
