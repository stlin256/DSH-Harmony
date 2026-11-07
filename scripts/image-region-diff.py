import sys, json, hashlib
from PIL import Image, ImageChops

a_path, b_path = sys.argv[1], sys.argv[2]
x1, y1, x2, y2 = map(int, sys.argv[3:7])
region = (x1, y1, x2, y2)
if x2 <= x1 or y2 <= y1:
    print(json.dumps({'changed': False, 'error': 'empty region', 'region': list(region)}))
    sys.exit(2)

# PIL pads out-of-bounds crops with black, which would silently report "no
# change" for regions that miss the image entirely. Intersect the region with
# both images and fail when it does not overlap either one.
def intersect(image, box):
    return (max(box[0], 0), max(box[1], 0),
            min(box[2], image.size[0]), min(box[3], image.size[1]))

a_full = Image.open(a_path).convert('RGB')
b_full = Image.open(b_path).convert('RGB')
a_box = intersect(a_full, region)
b_box = intersect(b_full, region)
if a_box[2] <= a_box[0] or a_box[3] <= a_box[1] or b_box[2] <= b_box[0] or b_box[3] <= b_box[1]:
    print(json.dumps({'changed': False, 'error': 'region outside image bounds', 'region': list(region)}))
    sys.exit(2)

a = a_full.crop(a_box)
b = b_full.crop(b_box)
if a.size != b.size:
    print(json.dumps({'changed': False, 'error': 'images differ in size', 'region': list(region),
                      'sizes': [list(a.size), list(b.size)]}))
    sys.exit(2)
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
  'region': list(region),
  'compared_region': list(a_box),
  'sha_a': hashlib.sha256(a.tobytes()).hexdigest(),
  'sha_b': hashlib.sha256(b.tobytes()).hexdigest(),
}))
