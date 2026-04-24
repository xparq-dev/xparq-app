import os

def replace_line(file, line_num, old, new):
    with open(file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    if old in lines[line_num - 1]:
        lines[line_num - 1] = lines[line_num - 1].replace(old, new)
        with open(file, 'w', encoding='utf-8') as out:
            out.writelines(lines)
            print(f"Fixed {file}:{line_num}")

replace_line('lib/features/radar/screens/radar_screen.dart', 586, 'Text(', 'Padding(')
replace_line('lib/features/social/screens/create_pulse_screen.dart', 92, 'Text(', 'SizedBox(')
replace_line('lib/features/social/widgets/echo_bottom_sheet.dart', 181, 'Text(', 'SizedBox(')

# fix const eval by removing const
def remove_const_above(file, line_num):
    with open(file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    for i in range(line_num - 1, max(-1, line_num - 5), -1):
        if 'const ' in lines[i]:
            lines[i] = lines[i].replace('const ', '')
            with open(file, 'w', encoding='utf-8') as out:
                out.writelines(lines)
            print(f"Removed const in {file}:{i+1}")
            break

remove_const_above('lib/features/radar/screens/radar_screen.dart', 635)
remove_const_above('lib/features/social/widgets/echo_bottom_sheet.dart', 120)

