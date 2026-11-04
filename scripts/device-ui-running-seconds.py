import sys, json, re
root = json.load(open(sys.argv[1], encoding='utf-8-sig'))
texts = []
def walk(node):
    if isinstance(node, dict):
        text = (node.get('attributes') or {}).get('text')
        if isinstance(text, str) and text.strip():
            texts.append(text.strip())
        for child in node.get('children') or []:
            walk(child)
    elif isinstance(node, list):
        for item in node:
            walk(item)
walk(root)
joined = '\n'.join(texts)
match = re.search(r'用时\s*(\d+)\s*秒', joined)
if match:
    print(int(match.group(1)))
else:
    minutes = re.search(r'用时\s*(\d+)\s*分', joined)
    print(int(minutes.group(1)) * 60 if minutes else 0)