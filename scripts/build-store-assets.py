#!/usr/bin/env python3
"""Compose the App Store listing art from the raw simulator captures.

`scripts/capture-store-assets.sh` produces the screenshots; this lays each one
into a captioned frame at exactly the pixel size App Store Connect wants, and
also renders the wide header and the search-result mock.

Frames are built as HTML and shot with headless Chrome, so they use the same
typeface, palette and gradient as steadykeyboard.com — the listing and the site
stay one design rather than two.

    scripts/build-store-assets.py            # everything that has raw input
    scripts/build-store-assets.py --device iPhone-17-Pro-Max
"""

from __future__ import annotations

import argparse
import base64
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "store" / "raw"
OUT = ROOT / "store"
FONTS = ROOT / "docs" / "fonts"
ICON = ROOT / "App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


@dataclass(frozen=True)
class Shot:
    """One listing frame: a captured screen plus the line it has to carry."""

    slug: str
    title: str
    sub: str


SHOTS = [
    Shot("01-texting", "The keys you need next get bigger.",
         "Tap targets widen as the word narrows."),
    Shot("02-one-tap", "Finish the word in one tap.",
         "Three large suggestions sit right above the keys."),
    Shot("03-names", "Names it would never guess.",
         "Saved once, then inserted exactly, in one tap."),
    Shot("04-phrases", "A whole sentence from big targets.",
         "Fill the blanks, send the message."),
    Shot("05-conversation", "Nothing you type leaves your phone.",
         "Every prediction runs on-device. No “Allow Full Access”."),
    Shot("06-settings", "Three strengths. Your call.",
         "Off, Medium or Aggressive, changeable any time."),
]


@dataclass(frozen=True)
class Device:
    """A capture folder and the frame proportions that suit its canvas.

    The screenshot is not given a width: it takes whatever height the caption
    leaves and keeps its aspect ratio, so one template fits both canvases and
    nothing is ever cropped or stretched.
    """

    slug: str
    label: str
    width: int
    height: int
    title_px: int
    sub_px: int
    pad_top: int
    pad_bottom: int
    screen_radius: int
    gap: int


DEVICES = [
    Device("iPhone-17-Pro-Max", "iPhone 6.9″", 1320, 2868,
           title_px=92, sub_px=41, pad_top=118, pad_bottom=40,
           screen_radius=66, gap=84),
    Device("iPad-Pro-13-inch-M5", "iPad 13″", 2064, 2752,
           title_px=112, sub_px=50, pad_top=132, pad_bottom=48,
           screen_radius=46, gap=96),
]


def data_uri(path: Path, mime: str) -> str:
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode()


def font_face() -> str:
    regular = data_uri(FONTS / "atkinson-hyperlegible-400.woff2", "font/woff2")
    bold = data_uri(FONTS / "atkinson-hyperlegible-700.woff2", "font/woff2")
    return f"""
@font-face {{ font-family: "Atkinson Hyperlegible"; font-weight: 400;
  src: url("{regular}") format("woff2"); }}
@font-face {{ font-family: "Atkinson Hyperlegible"; font-weight: 700;
  src: url("{bold}") format("woff2"); }}
"""


# The site's hero: linear-gradient(158deg, #1C6E68, #124A46) under a soft
# highlight. Keeping it identical is the point.
BACKDROP = """
  background:
    radial-gradient(1500px 900px at 80% -10%, rgba(217, 238, 235, .20), transparent 62%),
    radial-gradient(1100px 800px at 6% 108%, rgba(9, 44, 41, .55), transparent 60%),
    linear-gradient(158deg, #1C6E68 0%, #124A46 100%);
"""


def shoot(html: str, width: int, height: int, destination: Path, scale: int = 1) -> None:
    """Render an HTML string to a PNG of exactly width x height.

    `scale` renders in a smaller window at a higher device scale factor, which
    is how the 5244px-wide creatives are made: a headless window that wide is
    unreliable, and a `vw` layout scales exactly.
    """
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / "frame.html"
        page.write_text(html, encoding="utf-8")
        result = subprocess.run(
            [
                CHROME,
                "--headless=new",
                "--disable-gpu",
                "--hide-scrollbars",
                f"--force-device-scale-factor={scale}",
                "--virtual-time-budget=4000",
                f"--window-size={width // scale},{height // scale}",
                f"--screenshot={destination}",
                page.as_uri(),
            ],
            capture_output=True,
            text=True,
        )
        if not destination.exists():
            sys.exit(f"Chrome did not produce {destination}:\n{result.stderr}")


def frame_html(device: Device, shot: Shot, screenshot: Path) -> str:
    return f"""<!doctype html>
<html><head><meta charset="utf-8"><style>
{font_face()}
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{ width: {device.width}px; height: {device.height}px; overflow: hidden; }}
body {{
  {BACKDROP}
  font-family: "Atkinson Hyperlegible", system-ui, sans-serif;
  display: flex; flex-direction: column; align-items: center;
  padding: {device.pad_top}px 70px {device.pad_bottom}px;
  text-align: center;
}}
h1 {{
  font-weight: 700;
  font-size: {device.title_px}px;
  line-height: 1.1;
  letter-spacing: -.012em;
  color: #fff;
  max-width: {int(device.width * 0.84)}px;
  text-wrap: balance;
}}
p {{
  margin-top: {int(device.sub_px * 0.72)}px;
  font-size: {device.sub_px}px;
  line-height: 1.4;
  color: rgba(255, 255, 255, .80);
  max-width: {int(device.width * 0.74)}px;
  text-wrap: balance;
}}
.screen {{
  margin-top: {device.gap}px;
  min-height: 0;
  flex: 1 1 auto;
  border-radius: {device.screen_radius}px;
  overflow: hidden;
  border: 2px solid rgba(255, 255, 255, .22);
  box-shadow: 0 60px 120px -30px rgba(5, 24, 22, .62);
}}
.screen img {{ display: block; height: 100%; width: auto; }}
</style></head><body>
<h1>{shot.title}</h1>
<p>{shot.sub}</p>
<div class="screen"><img src="{data_uri(screenshot, 'image/png')}"></div>
</body></html>"""



def flatten(path: Path) -> None:
    """Drop the alpha channel. App Store Connect rejects a PNG that has one."""
    Image.open(path).convert("RGB").save(path)


@dataclass(frozen=True)
class Creative:
    """A landscape creative asset: the product-page header, or the search one.

    Both are 5244x2950 — the single size App Store Connect accepts for either
    placement — and both are one layout at two scales: copy on the left, a
    device cluster on the right. The header runs three devices and deliberately
    leaves its lower-left empty, because the App Store overlays the app icon
    and name there. The search asset is read at thumbnail size, so it gets
    fewer words, much bigger type, and one device instead of three.
    """

    out: str
    kicker: str
    headline: str  # <br> is honoured — the line breaks are art-directed
    sub: str
    devices: tuple[str, ...]


CREATIVE_W, CREATIVE_H = 5244, 2950

# The warm kicker over teal, the weights and every measurement below come from
# Emberly's creatives, so the two listings read as one house style. What is
# Steady's and stays Steady's: the backdrop and the typeface, both shared with
# steadykeyboard.com.
KICKER = "#FFD9C2"

CREATIVES = {
    "header": Creative(
        "header-5244x2950",
        kicker="Phrases with blanks",
        headline="A whole text<br>in one tap",
        sub="Keep the sentences you send often. Fill each blank from big chips.",
        devices=("02-one-tap.png", "04-phrases.png", "03-names.png"),
    ),
    "search": Creative(
        "search-5244x2950",
        kicker="Steady",
        headline="The keys you<br>need next<br>get bigger",
        sub="Reshapes itself as you type.",
        devices=("01-texting.png",),
    ),
}


def creative_html(creative: Creative, source: Path) -> str:
    """The landscape creative, laid out in `vw` so one template fits any
    canvas of the same shape — 5244x2950 for Connect, 2560x1340 for the site.
    """
    single = len(creative.devices) == 1
    devices = "".join(
        f'<div class="device{" mid" if not single and i == 1 else ""}">'
        f'<img src="{data_uri(source / name, "image/png")}"></div>'
        for i, name in enumerate(creative.devices)
    )
    return f"""<!doctype html>
<html><head><meta charset="utf-8"><style>
{font_face()}
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{ width: 100vw; height: 100vh; overflow: hidden; }}
body {{
  {BACKDROP}
  font-family: "Atkinson Hyperlegible", system-ui, sans-serif;
  display: flex; align-items: center; gap: {"4vw" if single else "2vw"};
  padding: 0 {"7vw" if single else "5.5vw"};
  -webkit-font-smoothing: antialiased;
}}
.copy {{ flex: 1 1 0; min-width: 0; padding-bottom: {"0" if single else "3vw"}; }}
.kicker {{
  font-size: {"1.5vw" if single else "1.15vw"}; font-weight: 700;
  letter-spacing: {"0.34vw" if single else "0.26vw"};
  text-transform: uppercase; color: {KICKER};
}}
.headline {{
  margin-top: {"1.4vw" if single else "1.1vw"};
  /* A notch under Emberly's 7.6/5.3: Atkinson Hyperlegible sets wider than
     the SF Pro those were measured in, and the trio's copy column is narrow. */
  font-size: {"7.6vw" if single else "4.9vw"}; line-height: 1.04;
  font-weight: 700; letter-spacing: -0.14vw; color: #fff;
}}
.sub {{
  margin-top: {"1.8vw" if single else "1.5vw"};
  font-size: {"1.9vw" if single else "1.5vw"}; line-height: 1.4;
  color: rgba(255, 255, 255, .88); max-width: {"30vw" if single else "26vw"};
}}
/* A 5244x2950 canvas is 56.25vw tall and a phone capture is 2.17x its own
   width, so a single device wider than ~23vw clips off the top and bottom. */
.devices {{
  flex: none; display: flex; align-items: center;
  {"" if single else "gap: 1.6vw;"}
}}
.device {{
  width: {"22.4vw" if single else "15.4vw"};
  border-radius: {"3.1vw" if single else "1.85vw"};
  padding: {"0.3vw" if single else "0.18vw"};
  background: #0B1512;
  box-shadow: 0 1.6vw 4.4vw rgba(8, 20, 17, .45);
}}
.device img {{ display: block; width: 100%;
  border-radius: {"2.85vw" if single else "1.7vw"}; }}
/* Centre phone of the trio steps forward as the hero. */
.device.mid {{
  width: 17.6vw; border-radius: 2.1vw; padding: 0.2vw;
  box-shadow: 0 2.2vw 6vw rgba(8, 20, 17, .58);
  position: relative; z-index: 2;
}}
.device.mid img {{ border-radius: 1.95vw; }}
</style></head><body>
<div class="copy">
  <div class="kicker">{creative.kicker}</div>
  <div class="headline">{creative.headline}</div>
  <div class="sub">{creative.sub}</div>
</div>
<div class="devices">{devices}</div>
</body></html>"""


def search_result_html(shots: list[Path], width: int, height: int) -> str:
    """How the listing reads in App Store search — the first three frames at
    the size they are actually seen, next to the icon and subtitle."""
    thumbs = "".join(
        f'<div class="thumb"><img src="{data_uri(path, "image/png")}"></div>' for path in shots
    )
    return f"""<!doctype html>
<html><head><meta charset="utf-8"><style>
{font_face()}
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{ width: {width}px; height: {height}px; overflow: hidden; }}
body {{
  background: #F6F8F7;
  font-family: "Atkinson Hyperlegible", system-ui, sans-serif;
  padding: 56px 60px;
  color: #15201D;
}}
.caption {{ font-size: 22px; color: #7C8C87; margin-bottom: 30px; }}
.card {{
  background: #fff; border-radius: 26px; padding: 36px 38px 40px;
  border: 1px solid #E2EAE7;
  box-shadow: 0 2px 6px rgba(20, 32, 29, .06), 0 32px 64px -34px rgba(20, 32, 29, .28);
}}
.row {{ display: flex; align-items: center; gap: 24px; }}
.row img.icon {{ width: 116px; height: 116px; border-radius: 26px; }}
.name {{ font-size: 32px; font-weight: 700; letter-spacing: -.01em; }}
.sub {{ font-size: 22px; color: #4B5B57; margin-top: 7px; }}
.get {{
  margin-left: auto; background: #EEF4F2; color: #1C6E68;
  font-size: 21px; font-weight: 700; padding: 13px 38px; border-radius: 999px;
}}
.shots {{ display: flex; gap: 16px; margin-top: 32px; }}
.thumb {{
  width: 196px; border-radius: 16px; overflow: hidden; border: 1px solid #E2EAE7;
}}
.thumb img {{ display: block; width: 100%; }}
</style></head><body>
<p class="caption">What the first three frames look like in App Store search results</p>
<div class="card">
  <div class="row">
    <img class="icon" src="{data_uri(ICON, 'image/png')}" alt="">
    <div>
      <div class="name">Steady</div>
      <div class="sub">A keyboard that reshapes itself</div>
    </div>
    <div class="get">GET</div>
  </div>
  <div class="shots">{thumbs}</div>
</div>
</body></html>"""


def build_device(device: Device) -> list[Path]:
    source = RAW / device.slug
    if not source.is_dir():
        print(f"-- {device.slug}: no raw capture, skipping")
        return []

    # Only the frames this script owns are replaced — the app preview built by
    # scripts/build-app-preview.sh lives in the same folder and must survive.
    destination = OUT / device.slug
    destination.mkdir(parents=True, exist_ok=True)

    built = []
    for shot in SHOTS:
        screenshot = source / f"{shot.slug}.png"
        if not screenshot.exists():
            print(f"   !! missing {screenshot.relative_to(ROOT)}")
            continue
        target = destination / f"{shot.slug}.png"
        shoot(frame_html(device, shot, screenshot), device.width, device.height, target)
        print(f"   {target.relative_to(ROOT)}  {device.width}x{device.height}")
        built.append(target)
    return built


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--device", help="build only this capture folder")
    args = parser.parse_args()

    if not Path(CHROME).exists():
        sys.exit("Google Chrome is needed to render the frames")

    devices = [d for d in DEVICES if not args.device or d.slug == args.device]
    first_three: list[Path] = []
    for device in devices:
        print(f"-- {device.label}")
        built = build_device(device)
        if device.slug == DEVICES[0].slug:
            first_three = built[:3]

    source = RAW / DEVICES[0].slug
    if not args.device and source.is_dir():
        print("-- creatives")
        for creative in CREATIVES.values():
            missing = [n for n in creative.devices if not (source / n).exists()]
            if missing:
                print(f"   !! missing {', '.join(missing)} — skipping {creative.out}")
                continue
            target = OUT / "creative" / f"{creative.out}.png"
            shoot(creative_html(creative, source), CREATIVE_W, CREATIVE_H, target, scale=2)
            flatten(target)
            print(f"   {target.relative_to(ROOT)}  {CREATIVE_W}x{CREATIVE_H}")

        header_shots = CREATIVES["header"].devices
        if all((source / name).exists() for name in header_shots):
            print("-- marketing")
            # The same layout at the banner's shape: press kit, featuring
            # nomination, the top of a page. The creatives above are 16:9; this
            # is 1.91:1, which is what Open Graph scales from cleanly.
            header = OUT / "header-2560x1340.png"
            shoot(creative_html(CREATIVES["header"], source), 2560, 1340, header)
            flatten(header)
            print(f"   {header.relative_to(ROOT)}  2560x1340")
            social = OUT / "social-1200x630.png"
            Image.open(header).resize((1200, 630), Image.LANCZOS).save(social)
            print(f"   {social.relative_to(ROOT)}  1200x630")
            # The site serves the same banner as its og:image, so copy it into
            # docs/ rather than asking anyone to remember to.
            site_card = ROOT / "docs" / "social-card.png"
            shutil.copyfile(social, site_card)
            print(f"   {site_card.relative_to(ROOT)}  1200x630")

    if len(first_three) == 3:
        shoot(search_result_html(first_three, 800, 900), 800, 900,
              OUT / "search-result-preview.png")
        print(f"   {(OUT / 'search-result-preview.png').relative_to(ROOT)}  800x900")


if __name__ == "__main__":
    main()
