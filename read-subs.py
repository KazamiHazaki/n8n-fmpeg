# read-subs.py
import sys
import json

filename = sys.argv[1]  # Take filename as argument

captions = []

try:
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()

    blocks = content.strip().split('\n\n')[1:]  # Skip WEBVTT header

    for block in blocks:
        lines = block.strip().split('\n')
        if len(lines) >= 2:
            time_line = lines[0]
            text = ' '.join(lines[1:])
            if ' --> ' in time_line:
                start, end = time_line.split(' --> ')
                captions.append({
                    "start": start.strip(),
                    "end": end.strip(),
                    "text": text.strip()
                })

except Exception as e:
    captions.append({"error": str(e)})

# Output JSON to stdout so n8n can read it
print(json.dumps({"captions": captions}))
