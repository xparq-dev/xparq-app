// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final dir = Directory('lib');
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    if (file.path.contains('app_colors.dart')) continue;

    String content = await file.readAsString();
    bool changed = false;

    // We will do a simple text replacement for the most common patterns:
    // Colors.white -> Theme.of(context).colorScheme.onSurface
    // Colors.white70 -> Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
    // Colors.white54 -> Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
    // Colors.white38 -> Theme.of(context).colorScheme.onSurface.withOpacity(0.38)
    // Colors.white24 -> Theme.of(context).colorScheme.onSurface.withOpacity(0.24)
    // Colors.white12 -> Theme.of(context).colorScheme.onSurface.withOpacity(0.12)
    // Colors.white10 -> Theme.of(context).colorScheme.onSurface.withOpacity(0.10)

    final replacements = {
      'Colors.white70':
          'Theme.of(context).colorScheme.onSurface.withOpacity(0.7)',
      'Colors.white54':
          'Theme.of(context).colorScheme.onSurface.withOpacity(0.54)',
      'Colors.white38':
          'Theme.of(context).colorScheme.onSurface.withOpacity(0.38)',
      'Colors.white24':
          'Theme.of(context).colorScheme.onSurface.withOpacity(0.24)',
      'Colors.white12':
          'Theme.of(context).colorScheme.onSurface.withOpacity(0.12)',
      'Colors.white10':
          'Theme.of(context).colorScheme.onSurface.withOpacity(0.10)',
      'Colors.white': 'Theme.of(context).colorScheme.onSurface',
      'const TextStyle(color: Theme.of(context)':
          'TextStyle(color: Theme.of(context)',
      'const Icon(Icons': 'Icon(Icons',
    };

    String newContent = content;

    // Replace Colors.white...
    replacements.forEach((key, value) {
      if (newContent.contains(key)) {
        newContent = newContent.replaceAll(key, value);
        changed = true;
      }
    });

    // Need to also remove `const` keyword before widgets that now use Theme.of(context)
    // We can do a basic regex to remove const from Text, Icon, TextStyle, etc. if they contain Theme.of
    if (newContent.contains('Theme.of(context)')) {
      newContent = newContent.replaceAll(
        RegExp(
          r'const\s+(Text|TextStyle|Icon|Divider|BorderSide|Padding|SizedBox|Row|Column)\(',
        ),
        r'$1(',
      );
      // Sometimes it's nested like `const [ Text(...) ]` -> we might get errors, but let's see.
    }

    if (changed && content != newContent) {
      await file.writeAsString(newContent);
      print('Refactored \${file.path}');
    }
  }
}
