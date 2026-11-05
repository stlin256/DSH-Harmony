import sys, json
root = json.load(open(sys.argv[1], encoding='utf-8-sig'))
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
if isinstance(root, list):
    for item in root: walk(item)
else:
    walk(root)
if found is None:
    print(json.dumps({'found': False}))
    sys.exit(0)
bounds = found.get('bounds', '')
import re
match = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', bounds)
x1, y1, x2, y2 = map(int, match.groups()) if match else (0, 0, 0, 0)
print(json.dumps({
  'found': True,
  'checked': found.get('checked'),
  'checkable': found.get('checkable'),
  'bounds': bounds,
  'x1': x1,
  'y1': y1,
  'x2': x2,
  'y2': y2,
  'height': y2 - y1,
  'x': (x1 + x2) // 2,
  'y': (y1 + y2) // 2,
}))