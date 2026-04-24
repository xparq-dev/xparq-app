import os

def replace_line(file, line_num, old, new):
    if not os.path.exists(file): return
    with open(file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    if old in lines[line_num - 1]:
        lines[line_num - 1] = lines[line_num - 1].replace(old, new)
        with open(file, 'w', encoding='utf-8') as out:
            out.writelines(lines)

replace_line('lib/features/chat/screens/chat_list_screen.dart', 90, 'Text(', 'Padding(')
replace_line('lib/features/chat/screens/signal_chat_screen.dart', 392, 'Text(', 'Padding(')
replace_line('lib/features/radar/screens/radar_screen.dart', 150, 'Text(', 'Icon(')
replace_line('lib/features/radar/screens/radar_screen.dart', 543, 'Text(', 'Icon(')

def remove_const_above(file, line_num):
    if not os.path.exists(file): return
    with open(file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    for i in range(line_num - 1, max(-1, line_num - 5), -1):
        if 'const ' in lines[i]:
            lines[i] = lines[i].replace('const ', '')
            with open(file, 'w', encoding='utf-8') as out:
                out.writelines(lines)
            break

remove_const_above('lib/features/chat/screens/signal_chat_screen.dart', 150)
remove_const_above('lib/features/radar/screens/radar_screen.dart', 670)
remove_const_above('lib/features/social/widgets/echo_bottom_sheet.dart', 153)

# For edit_profile 92: error - The named parameter 'padding' is required. it was changed to `Padding()` earlier. It should be `const SizedBox.shrink()`
replace_line('lib/features/profile/screens/edit_profile_screen.dart', 92, 'Padding()', 'const SizedBox.shrink()')
# radarNotifierProvider -> radarRepositoryProvider
replace_line('lib/features/control_deck/screens/control_deck_screen.dart', 25, 'radarNotifierProvider', 'radarRepositoryProvider')
