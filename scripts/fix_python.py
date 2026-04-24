import re
import os

with open('analyze_output.txt', 'r', encoding='utf-8', errors='ignore') as f:
    lines = f.readlines()

for line in lines:
    match = re.search(r' (error|warning|info) - (.*?) - (.*):(\d+):(\d+) - (.*)', line)
    if not match:
        continue
    
    msg = match.group(2)
    file_path = match.group(3)
    line_num = int(match.group(4))
    
    if not os.path.exists(file_path):
        continue
        
    with open(file_path, 'r', encoding='utf-8') as src:
        code_lines = src.readlines()
        
    if line_num <= 0 or line_num > len(code_lines):
        continue
        
    target = code_lines[line_num - 1]
    changed = False
    
    if "The method '$1' isn't defined" in msg or "$1(" in target:
        if "color:" in target and ("style:" not in target and "child:" not in target):
            target = target.replace("$1(", "Icon('") # fallback
            if "Icons." in target:
                 target = target.replace("$1(", "Icon(")
            elif "Theme.of" in target:
                 target = target.replace("$1(", "Divider(")
        elif "width:" in target or "height:" in target:
            if "color:" in target:
                 target = target.replace("$1(", "Divider(")
            else:
                 target = target.replace("$1(", "SizedBox(")
        else:
            target = target.replace("$1(", "Text(")
        # Make sure no const Text if it has Theme
        if "Theme.of" in target and "const " in target:
            target = target.replace("const ", "")
        changed = True
        
    if "The element type 'TextStyle' can't be assigned to the list type 'Widget'" in msg:
        target = target.replace("TextStyle(", "Divider(")
        changed = True
        
    if "The element type 'BorderSide' can't be assigned to the list type 'Widget'" in msg:
        target = target.replace("BorderSide(", "Divider(")
        changed = True

    if "Methods can't be invoked in constant expressions" in msg or "Invalid constant value" in msg:
        # We need to drop 'const' from the line
        target = target.replace("const ", "")
        changed = True
        
    if "Creation of a widget in a constant expression must have a constant constructor" in msg:
        target = target.replace("const ", "")
        changed = True
        
    if changed and target != code_lines[line_num - 1]:
        code_lines[line_num - 1] = target
        with open(file_path, 'w', encoding='utf-8') as out:
            out.writelines(code_lines)
        print(f"Fixed {file_path}:{line_num}")
