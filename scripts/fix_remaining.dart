// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final file = File('analyze_output.txt');
  if (!await file.exists()) return;
  final lines = await file.readAsLines();

  final regex = RegExp(r' (error|warning) - (.*) - (.*):(\d+):(\d+) - (.*)$');

  for (final line in lines) {
    var match = regex.firstMatch(line);
    if (match != null) {
      String msg = match.group(2)!;
      String filePath = match.group(3)!;
      int lineNum = int.parse(match.group(4)!);

      final dartFile = File(filePath);
      if (await dartFile.exists()) {
        final codeLines = await dartFile.readAsLines();
        if (lineNum > 0 && lineNum <= codeLines.length) {
          String codeLine = codeLines[lineNum - 1];
          bool changed = false;

          // 1. method $1 not defined -> text has `$1(` or something. Actually, my previous script left `$1(`? Wait, `fix_regex.dart` only replaced `replaceFirst`. Maybe there were MULTIPLE `$1(` on the same line!
          if (msg.contains("The method '\$1' isn't defined") ||
              codeLine.contains(r'$1(')) {
            codeLine = codeLine.replaceAll(r'$1(', 'Text(');
            // Let's assume Text as it's the safest fallback if there are multiple.
            // Or let's just use Text( if no color. If it has color, TextStyle(.
            if (codeLine.contains('color:')) {
              // Heuristic: usually multiple `$1(` means `Row(children: [ $1(child: $1(...) ])`
              if (codeLine.contains('style: \$1(')) {
                codeLine = codeLine.replaceAll(
                  'style: \$1(',
                  'style: TextStyle(',
                );
              } else {
                codeLine = codeLine.replaceAll(r'$1(', 'Icon('); // second guess
              }
            }
            changed = true;
          }

          // 2. The element type 'TextStyle' can't be assigned to the list type 'Widget'
          // This means I replaced `Divider(...)` with `TextStyle(...)` inside a `children: [...]` list!
          if (msg.contains(
            "The element type 'TextStyle' can't be assigned to the list type 'Widget'",
          )) {
            codeLine = codeLine.replaceAll('TextStyle(', 'Divider(');
            changed = true;
          }

          if (msg.contains(
            "The element type 'BorderSide' can't be assigned to the list type 'Widget'",
          )) {
            codeLine = codeLine.replaceAll('BorderSide(', 'Divider(');
            changed = true;
          }

          if (msg.contains(
            "Methods can't be invoked in constant expressions",
          )) {
            // In main.dart, I probably removed const from a TextStyle, but its parent is still const!
            // Wait, the error is `Methods can't be invoked in constant expressions`. Oh! `Theme.of(context)` is NOT CONST!
            // If a widget has `Theme.of(context)` inside it, its parent CANNOT be const!
            // So I must remove the `const` on the parent.
            // But my script operates per line! So finding the parent's `const` is hard.
          }

          if (changed) {
            codeLines[lineNum - 1] = codeLine;
            await dartFile.writeAsString(codeLines.join('\n'));
            print('Fixed line \$lineNum in \$filePath');
          }
        }
      }
    }
  }
}
