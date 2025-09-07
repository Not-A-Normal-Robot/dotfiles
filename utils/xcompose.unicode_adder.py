import unicodedata
import re
from pathlib import Path

# Path to your .XCompose file
script_dir = Path(__file__).parent
xcompose_path = (script_dir / "../dotfiles/.XCompose").resolve()

# Regex to match lines with a single quoted character after colon
line_pattern = re.compile(r'^(.*:\s*)"(.)"(.*)$')

new_lines = []
with xcompose_path.open("r", encoding="utf-8") as f:
    for line in f:
        match = line_pattern.match(line)
        if not match:
            new_lines.append(line)
            continue

        before, char, after = match.groups()

        # Ensure it's a single character
        if len(char) != 1:
            new_lines.append(line)
            continue

        codepoint = f"U{ord(char):04X}"
        name = unicodedata.name(char, "UNKNOWN")

        # If annotation already exists, skip
        if codepoint in after and name in after:
            new_lines.append(line)
            continue

        new_line = f"{before}\"{char}\"   {codepoint} # {name}{after if after.strip() else ''}\n"
        new_lines.append(new_line)

# Write modified version
with xcompose_path.open("w", encoding="utf-8") as f:
    f.writelines(new_lines)

print(f"Updated {xcompose_path}")
