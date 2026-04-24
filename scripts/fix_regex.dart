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
    if (!content.contains(r'$1(')) continue;

    bool changed = false;
    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      while (lines[i].contains(r'$1(')) {
        String line = lines[i];
        String replacement = '';

        if (line.contains(r"$1('") ||
            line.contains(r'$1("') ||
            line.contains(r"$1('''")) {
          replacement = 'Text(';
        } else if (line.contains(r'$1(Icons.')) {
          replacement = 'Icon(';
        } else if (line.contains(r'style: $1(')) {
          replacement = 'TextStyle(';
        } else if (line.contains(r'borderSide: $1(') ||
            line.contains(r'top: $1(') ||
            line.contains(r'bottom: $1(') ||
            line.contains(r'left: $1(') ||
            line.contains(r'right: $1(') ||
            line.contains(r'border: $1(')) {
          replacement = 'BorderSide(';
        } else if (line.contains(r'$1(width:') ||
            line.contains(r'$1(height:')) {
          if (line.contains('color:')) {
            replacement = 'Divider(';
          } else {
            replacement = 'SizedBox(';
          }
        } else if (line.contains(r'$1(padding:')) {
          replacement = 'Padding(';
        } else if (line.contains(r'$1(color:') ||
            line.contains(r'$1(fontSize:') ||
            line.contains(r'$1(fontWeight:')) {
          replacement = 'TextStyle(';
        } else if (line.contains(r'title: $1(') ||
            line.contains(r'subtitle: $1(') ||
            line.contains(r'content: $1(') ||
            line.contains(r'label: $1(')) {
          replacement = 'Text(';
        } else if (line.contains(r'icon: $1(') ||
            line.contains(r'leading: $1(') ||
            line.contains(r'trailing: $1(')) {
          replacement = 'Icon(';
        } else if (line.contains(r'$1(children:')) {
          replacement = 'Column(';
          print(
            'WARNING: Guessed Column for children in \${file.path}:\${i+1}',
          );
        } else {
          replacement = 'Text(';
          print(
            'WARNING: Guessed Text for unknown in \${file.path}:\${i+1}: $line',
          );
        }

        lines[i] = lines[i].replaceFirst(r'$1(', replacement);
        changed = true;
      }
    }

    if (changed) {
      await file.writeAsString(lines.join('\n'));
      print('Fixed \${file.path}');
    }
  }
}
