"""Generate square icon sources for flutter_launcher_icons from
`assets/app_icon.png`. Produces:

  - assets/icon/icon.png            1024x1024, dark background, logo inset
  - assets/icon/foreground.png      1024x1024, transparent, logo within
                                    the Android adaptive safe zone (~66%)
  - assets/icon/web_icon.png        1024x1024, transparent, tight logo for web
"""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "app_icon.png"
OUT_DIR = ROOT / "assets" / "icon"
OUT_DIR.mkdir(parents=True, exist_ok=True)

CANVAS = 1024
BG_COLOR = (19, 19, 19, 255)  # #131313 — matches existing adaptive background


def fit_logo(logo: Image.Image, target_ratio: float) -> Image.Image:
    """Scale the logo so that max(width,height) == CANVAS * target_ratio
    and return it centered on a transparent CANVAS×CANVAS canvas."""
    max_side = CANVAS * target_ratio
    w, h = logo.size
    scale = max_side / max(w, h)
    new_w, new_h = int(round(w * scale)), int(round(h * scale))
    resized = logo.resize((new_w, new_h), Image.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(resized, ((CANVAS - new_w) // 2, (CANVAS - new_h) // 2), resized)
    return canvas


def main() -> None:
    logo = Image.open(SRC).convert("RGBA")

    # iOS / fallback: dark square background, logo inset at 82% of the canvas
    ios_logo = fit_logo(logo, 0.82)
    ios = Image.new("RGBA", (CANVAS, CANVAS), BG_COLOR)
    ios.alpha_composite(ios_logo)
    ios.convert("RGB").save(OUT_DIR / "icon.png", format="PNG", optimize=True)

    # Android adaptive foreground: transparent, logo at 62% (inside safe zone)
    fg = fit_logo(logo, 0.62)
    fg.save(OUT_DIR / "foreground.png", format="PNG", optimize=True)

    # Web icon: transparent, logo at 92%
    web = fit_logo(logo, 0.92)
    web.save(OUT_DIR / "web_icon.png", format="PNG", optimize=True)

    print("wrote:")
    for p in (OUT_DIR / "icon.png", OUT_DIR / "foreground.png", OUT_DIR / "web_icon.png"):
        print(f"  {p.relative_to(ROOT)}  {Image.open(p).size}")


if __name__ == "__main__":
    main()
