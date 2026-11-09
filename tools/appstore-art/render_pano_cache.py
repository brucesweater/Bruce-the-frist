"""Renders the wide painted sky once and caches it in .cache/ (compose.py reuses it).

python3 render_pano_cache.py <number of screenshots> full|quick
"""
import os, sys, time
import cv2
from panorama import render_panorama
n = int(sys.argv[1]); quick = sys.argv[2] == "quick"
W, H = 1320, 2868
t = time.time()
pano = render_panorama(shots=n, scale_down=2 if quick else 1)
pano = cv2.resize(pano, (W * n, H))
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".cache", "pano-%d-%s.png" % (n, "quick" if quick else "full"))
os.makedirs(os.path.dirname(out), exist_ok=True)
cv2.imwrite(out, pano)
print("wrote", out, pano.shape, "in %.0fs" % (time.time() - t))
