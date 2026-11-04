import sys, json
root = json.load(open(sys.argv[1], encoding='utf-8-sig'))
out = []
def walk(node):
    if isinstance(node, dict):
        attributes = node.get('attributes') or {}
        text = attributes.get('text')
        if isinstance(text, str) and text.strip():
            out.append(text.strip())
        for child in node.get('children') or []:
            walk(child)
    elif isinstance(node, list):
        for item in node:
            walk(item)
walk(root)
print('\n'.join(out))