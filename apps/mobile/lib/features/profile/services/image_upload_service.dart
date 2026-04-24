import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ImageUploadService {
  final SupabaseClient _client;
  final ImagePicker _picker;

  ImageUploadService({SupabaseClient? client, ImagePicker? picker})
    : _client = client ?? Supabase.instance.client,
      _picker = picker ?? ImagePicker();

  /// Pick an image from gallery or camera.
  Future<XFile?> pickImage({required ImageSource source}) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
    );
    return picked;
  }

  /// Pick a video from gallery or camera.
  Future<XFile?> pickVideo({required ImageSource source}) async {
    final XFile? picked = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 30),
    );
    return picked;
  }

  /// Upload an image to Supabase Storage and return the public URL.
  Future<String> uploadImage({
    required XFile file,
    required String bucket,
    required String path,
  }) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.jpg';
    final fullPath = '$path/$fileName';

    final Uint8List bytes = await file.readAsBytes();

    await _client.storage
        .from(bucket)
        .uploadBinary(
          fullPath,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    return _client.storage.from(bucket).getPublicUrl(fullPath);
  }

  /// Upload a profile avatar.
  Future<String> uploadProfileImage({
    required XFile file,
    required String uid,
  }) async {
    return uploadImage(file: file, bucket: 'avatars', path: uid);
  }

  /// Upload a profile cover image.
  Future<String> uploadCoverImage({
    required XFile file,
    required String uid,
  }) async {
    return uploadImage(file: file, bucket: 'covers', path: uid);
  }

  /// Upload a pulse image.
  Future<String> uploadPulseImage({
    required XFile file,
    required String uid,
  }) async {
    return uploadImage(file: file, bucket: 'pulses', path: '$uid/images');
  }

  /// Upload a pulse video.
  Future<String> uploadPulseVideo({
    required XFile file,
    required String uid,
  }) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.mp4';
    final fullPath = '$uid/videos/$fileName';

    final Uint8List bytes = await file.readAsBytes();

    await _client.storage
        .from('pulses')
        .uploadBinary(
          fullPath,
          bytes,
          fileOptions: const FileOptions(contentType: 'video/mp4'),
        );

    return _client.storage.from('pulses').getPublicUrl(fullPath);
  }
}
