import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'media_encryption_service.dart';

class EncryptedImageWidget extends StatefulWidget {
  final String url;
  final String storagePath;
  final String mediaKeyBase64;

  const EncryptedImageWidget({
    super.key,
    required this.url,
    required this.storagePath,
    required this.mediaKeyBase64,
  });

  @override
  EncryptedImageWidgetState createState() => EncryptedImageWidgetState();
}

class EncryptedImageWidgetState extends State<EncryptedImageWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Uint8List? _decryptedImageBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAndDecryptImage();
  }

  Future<void> _loadAndDecryptImage() async {
    try {
      final keyBytes = base64Decode(widget.mediaKeyBase64);

      // 1. Download encrypted file to temp
      final tempDir = await getTemporaryDirectory();
      final encryptedFilePath = p.join(
        tempDir.path,
        'download_${DateTime.now().millisecondsSinceEpoch}.enc',
      );

      final res = await Supabase.instance.client.storage
          .from('encrypted_chat_media')
          .download(widget.storagePath);

      final encryptedFile = File(encryptedFilePath);
      await encryptedFile.writeAsBytes(res);

      if (!mounted) return;

      // 2. Decrypt file
      final decryptedFile = await MediaEncryptionService.instance.decryptFile(
        encryptedFile,
        keyBytes,
        '.jpg', // assume jpg/png for now, decoding handles both
      );

      final decryptedBytes = await decryptedFile.readAsBytes();

      if (!mounted) return;

      setState(() {
        _decryptedImageBytes = decryptedBytes;
        _isLoading = false;
      });

      // Cleanup temp files security
      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
      }
      if (await decryptedFile.exists()) {
        await decryptedFile.delete();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return Container(
        height: 200,
        width: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const CircularProgressIndicator(),
      );
    }

    if (_error != null || _decryptedImageBytes == null) {
      return Container(
        height: 150,
        width: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load media',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(_decryptedImageBytes!, fit: BoxFit.cover, width: 200),
    );
  }
}
