// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final dir = Directory('lib');
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = await file.readAsString();
    bool changed = false;

    // Remove scaffold hardcoded colors
    if (content.contains('backgroundColor: const Color(0xFF050A1A),')) {
      content = content.replaceAll(
        RegExp(r'\s*backgroundColor:\s*const Color\(0xFF050A1A\),'),
        '',
      );
      changed = true;
    }
    if (content.contains('backgroundColor: Color(0xFF050A1A),')) {
      content = content.replaceAll(
        RegExp(r'\s*backgroundColor:\s*Color\(0xFF050A1A\),'),
        '',
      );
      changed = true;
    }

    // Convert hardcoded Colors.white to Theme text color for major files
    // But text usually needs const. Let's do a fast regex:
    // `style: const TextStyle(color: Colors.white` -> `style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color`
    // Actually, text color defaults to Theme.of(context).textTheme.bodyMedium.color so we can just remove color: Colors.white, where possible.

    if (changed) {
      await file.writeAsString(content);
      print('Updated \${file.path}');
    }
  }
}
