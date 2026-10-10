"""Builds the app icon's source images from the owner's logo.

The logo, `assets/cards/Madhu Games Crowned Logo.png`, is the owner's and is
only read here, never changed (AGENTS.md §13). It is a wide badge on a
transparent background, so the icons put it on a navy background that fades
to near black at the edges, like the card backs:

- `app_icon.png`: the whole badge on that background, square and opaque:
  iOS and older Android.
- `app_icon_foreground.png`: the badge alone, small enough that the round
  and squircle masks of Android's adaptive icons never cut it.
- `app_icon_background.png`: the background alone, for adaptive icons.

Then `dart run flutter_launcher_icons` in `apps/mobile` makes every icon size
from them (pubspec.yaml, `flutter_launcher_icons`). Run this with Python 3 and
Pillow from `apps/mobile`: `python branding/make_icon_sources.py`.
"""

from pathlib import Path

from PIL import Image

SIZE = 1024
CENTRE = (11, 58, 140)  # the logo's blue
EDGE = (2, 10, 31)  # near black, with a little navy
HERE = Path(__file__).resolve().parent
LOGO = HERE.parent / 'assets' / 'cards' / 'Madhu Games Crowned Logo.png'


def background() -> Image.Image:
    """A radial gradient from CENTRE to EDGE."""
    image = Image.new('RGB', (SIZE, SIZE))
    pixels = image.load()
    half = SIZE / 2
    for y in range(SIZE):
        for x in range(SIZE):
            d = min(1.0, (((x - half) ** 2 + (y - half) ** 2) ** 0.5) / (half * 1.25))
            t = d * d
            pixels[x, y] = tuple(round(c + (e - c) * t) for c, e in zip(CENTRE, EDGE))
    return image


def badge(width: int) -> Image.Image:
    """The logo cut to its visible badge and scaled to [width] pixels wide."""
    logo = Image.open(LOGO).convert('RGBA')
    logo = logo.crop(logo.getchannel('A').getbbox())
    height = round(logo.height * width / logo.width)
    return logo.resize((width, height), Image.LANCZOS)


def centred(canvas: Image.Image, mark: Image.Image) -> Image.Image:
    canvas = canvas.copy()
    canvas.alpha_composite(
        mark,
        ((SIZE - mark.width) // 2, (SIZE - mark.height) // 2),
    )
    return canvas


def main() -> None:
    back = background()
    back.save(HERE / 'app_icon_background.png')
    full = centred(back.convert('RGBA'), badge(round(SIZE * 0.9)))
    full.convert('RGB').save(HERE / 'app_icon.png')
    clear = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    centred(clear, badge(round(SIZE * 0.8))).save(HERE / 'app_icon_foreground.png')


if __name__ == '__main__':
    main()
