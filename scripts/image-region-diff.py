import sys, json, hashlib
from PIL import Image, ImageChops

a_path, b_path = sys.argv[1], sys.argv[2]
x1, y1, x2, y2 = map(int, sys.argv[3:7])
a = Image.open(a_path).convert('RGB').crop((x1, y1, x2, y2))
b = Image.open(b_path).convert('RGB').crop((x1, y1, x2, y2))
diff = ImageChops.difference(a, b)
gray = diff.convert('L')
hist = gray.histogram()
strong = sum(hist[8:256])
pixels = a.size[0] * a.size[1]
fraction = strong / pixels if pixels else 0
mean = sum(value * count for value, count in enumerate(hist)) / pixels if pixels else 0
print(json.dumps({
  'changed': fraction > 0.0015,
  'strong_fraction': round(fraction, 6),
  'mean_delta': round(mean, 3),
  'region': [x1, y1, x2, y2],
  'sha_a': hashlib.sha256(a.tobytes()).hexdigest(),
  'sha_b': hashlib.sha256(b.tobytes()).hexdigest(),
}))