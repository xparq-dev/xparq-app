import re
import os

with open('analyze_output.txt', 'r', encoding='utf-16', errors='ignore') as f:
    lines = f.readlines()

for line in lines:
    match = re.search(r' (error|warning|info) - (.*?) - (.*):(\d+):(\d+) - (.*)', line)
    if not match:
        continue
    
    msg = match.group(2)
    file_path = match.group(3)
    line_num = int(match.group(4))
    
    if "error" not in line.lower():
         continue
    
    if not os.path.exists(file_path):
        continue
        
    with open(file_path, 'r', encoding='utf-8') as src:
        code_lines = src.readlines()
        
    if line_num <= 0 or line_num > len(code_lines):
        continue
        
    target = code_lines[line_num - 1]
    original = target
    
    if "1 positional argument expected by 'Text.new', but 0 found" in msg or "The named parameter 'child' isn't defined" in msg or "The named parameter 'mainAxisSize' isn't defined" in msg or "The named parameter 'children' isn't defined" in msg:
        if "Text(" in target:
            if "Icons." in target or "icon:" in target:
                 target = target.replace("Text(", "Icon(")
            elif "children:" in target:
                 target = target.replace("Text(", "Row(")
                 if "visibility_off" in code_lines[line_num]:
                      target = target.replace("Row(", "Column(")
            else:
                 target = target.replace("Text(", "Padding(")

    if "The named parameter 'padding' isn't defined" in msg or "The named parameter 'child' isn't defined" in msg:
        if "Text(" in target:
            target = target.replace("Text(", "Padding(")
            
    if "The named parameter 'width' isn't defined" in msg or "The named parameter 'height' isn't defined" in msg:
        if "Text(" in target:
            target = target.replace("Text(", "SizedBox(")
            
    if "The argument type 'TextStyle' can't be assigned to the parameter type 'BorderSide" in msg:
        target = target.replace("TextStyle(", "BorderSide(")

    if "The element type 'TextStyle' can't be assigned to the list type 'Widget'" in msg:
        target = target.replace("TextStyle(", "Divider(")

    if "The argument type 'IconData' can't be assigned to the parameter type 'String'" in msg or "The named parameter 'color' isn't defined" in msg or "The named parameter 'size' isn't defined" in msg:
        target = target.replace("Text(", "Icon(")

    if "Methods can't be invoked in constant expressions" in msg or "Creation of a widget in a constant expression must have a constant constructor" in msg:
        if "const " in target:
            target = target.replace("const ", "")
        else:
            # Look up to 10 lines up for const
            for j in range(line_num - 1, max(-1, line_num - 11), -1):
                if "const " in code_lines[j]:
                    code_lines[j] = code_lines[j].replace("const ", "")
                    break
                    
    if "Undefined name 'radarNotifierProvider'" in msg:
         target = target.replace("radarNotifierProvider", "radarRepositoryProvider")
         
    if "The getter 'onSurface60' isn't defined" in msg:
         target = target.replace("onSurface60", "onSurface.withOpacity(0.6)")

    if target != original:
        code_lines[line_num - 1] = target
        with open(file_path, 'w', encoding='utf-8') as out:
            out.writelines(code_lines)
        print(f"Fixed {file_path}:{line_num} -> {target.strip()}")
