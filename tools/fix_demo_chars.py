import re

file_path = "E:/MuMain/MuGodot/src/scenes/MuCharacterSelect.gd"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if "func _setup_network_or_demo_data" in line:
        new_lines.append("## Thiết lập danh sách 5 slot nhân vật (Tài khoản mới bắt đầu với 0 nhân vật)\n")
        new_lines.append("func _setup_network_or_demo_data() -> void:\n")
        new_lines.append("\tif MuAccountSession.character_list.is_empty():\n")
        new_lines.append("\t\tfor i in range(5):\n")
        new_lines.append("\t\t\tMuAccountSession.character_list.append({})\n")
        skip = True
    elif skip:
        if line.startswith("func _setup_click_areas") or "## Thiết lập 5 vùng chạm" in line:
            skip = False
            new_lines.append("\n")
            new_lines.append(line)
    else:
        new_lines.append(line)

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("Updated MuCharacterSelect.gd successfully!")
