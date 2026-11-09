# App Store art

Scripts that make Unhook's App Store screenshots, the press-kit header and a search-result preview, in the style
of Bruce Run's set: one wide painted night sky that turns to sunrise across the screenshots, bold two-tone
headlines, gold orbits behind tilted iPhones, and Bruce holding his phone on the first screenshot.

Everything is drawn in code (Python, Pillow, OpenCV, NumPy), so the art is original and can be remade whenever the
app's screens change.

## What you need

- Python 3 with `pip install pillow opencv-python-headless numpy`
- Full-size app screenshots from CI. Push a commit whose message contains `[screenshots full]`. The Screenshots
  workflow runs the UI tests on the iPhone 17 Pro Max simulator and commits JPEGs to
  `AppStore/screenshots/raw/full/` (1320 × 2868).

## Make the screenshots

```sh
cd tools/appstore-art
python3 render_pano_cache.py 8 full      # paints the sky once (a few minutes), cached in .cache/
python3 compose.py ../../AppStore/screenshots/raw/full out
```

`compose.py` writes `out/01.png` … `out/08.png` at 1320 × 2868. Add `--quick` to paint the sky at half size
while you try out layouts. The set (screens, headlines, phone positions) is the `SHOTS` list at the bottom of
`compose.py`. Copy the finished images to `AppStore/screenshots/final/en-US/APP_IPHONE_67/`, where
`[asc screenshots]` uploads them.

Other scripts:

- `header.py <raw dir> <out.jpg>`: the 3840 × 1646 header for the press kit and website.
- `search_preview.py <screenshots dir> <app icon> <out.png>`: how the listing looks in App Store search (icon,
  name, subtitle and the first three screenshots). For checking only, not for upload.

## Files

| File | What it does |
|---|---|
| `sky.py`, `scene.py` | Noise, flow fields, brush strokes, swirling stars, hills and the glowing 30-step path. The in-app event art in `AppStore/event/` was made with `scene.render_scene`. |
| `panorama.py` | The wide sky behind the whole set: deep night on the left, sunrise on the right. |
| `typo.py` | Heavy rounded headlines (white line, then dawn-gold line) with a short extrusion and soft shadow. |
| `phone.py` | A clean iPhone frame around a screenshot, with a glow and drop shadow. |
| `ornaments.py` | Gold orbit ribbons, the laurel badge and small line icons. |
| `compose.py` | Puts it together. Also cuts Bruce out of his photo and puts Unhook's Today screen on his phone. |

## Assets

- `assets/bruce-photo.jpg`: Bruce's photo from the Bruce Run press kit, used with his permission.
- `assets/bruce-mask-*.png`: cut-out masks for that photo, made with rembg (BiRefNet for the hair, a
  human-segmentation model for the body).
- `fonts/`: Fredoka and Nunito, both under the SIL Open Font License (licenses included).
