import json, re, sys
layout = json.load(open(sys.argv[1], encoding='utf-8-sig'))
target = sys.argv[2]
found = None
def walk(node):
    global found
    if found is not None or not isinstance(node, dict):
        return
    attributes = node.get('attributes') or {}
    if attributes.get('id') == target:
        found = attributes
        return
    for child in node.get('children') or []:
        walk(child)
if isinstance(layout, list):
    for item in layout: walk(item)
else:
    walk(layout)
if not found:
    print(json.dumps([0,0,0,0]))
    sys.exit(0)
match = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', found.get('bounds',''))
x1, y1, x2, y2 = map(int, match.groups())
print(json.dumps([x1 + 18, y1 + 10, x1 + 140, y1 + 92]))