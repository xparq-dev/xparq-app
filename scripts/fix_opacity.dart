// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final dir = Directory('lib');
  final regex = RegExp(r'\.withOpacity\(([^)]+)\)');
  int count = 0;

  for (var e in dir.listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) {
      String c = e.readAsStringSync();
      if (regex.hasMatch(c)) {
        c = c.replaceAllMapped(regex, (m) => '.withValues(alpha: ${m.group(1)})');
        e.writeAsStringSync(c);
        count++;
        print('Fixed ${e.path}');
      }
    }
  }
  print('Total files fixed: $count');
}
