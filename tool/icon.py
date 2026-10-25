import pathlib
import sys

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
BACKGROUND = (27, 30, 36)
ACCENT = (95, 212, 200)
CORE = (237, 239, 242)
SIZE = 512
SCALE = 4


def render() -> Image.Image:
    side = SIZE * SCALE
    unit = side / 512

    glow = Image.radial_gradient('L').resize((side * 2, side * 2), Image.BILINEAR)
    glow = glow.point(lambda v: int(255 * max(0.0, 1 - v / 255) ** 1.6 * 0.22))
    cx, cy = int(side * 0.78), int(side * 0.22)
    glow = glow.crop((side - cx, side - cy, 2 * side - cx, 2 * side - cy))
    icon = Image.composite(
        Image.new('RGB', (side, side), ACCENT),
        Image.new('RGB', (side, side), BACKGROUND),
        glow,
    ).convert('RGBA')

    card = Image.new('L', (side, side), 0)
    ImageDraw.Draw(card).rounded_rectangle(
        (0, 0, side - 1, side - 1), radius=int(side * 0.225), fill=255
    )
    icon.putalpha(card)

    draw = ImageDraw.Draw(icon)
    draw.rounded_rectangle(
        tuple(v * unit for v in (100, 100, 412, 412)),
        radius=int(56 * unit),
        outline=ACCENT + (255,),
        width=int(18 * unit),
    )
    draw.rounded_rectangle(
        tuple(v * unit for v in (162, 162, 350, 350)),
        radius=int(38 * unit),
        outline=ACCENT + (150,),
        width=int(14 * unit),
    )
    draw.rounded_rectangle(
        tuple(v * unit for v in (216, 216, 296, 296)),
        radius=int(20 * unit),
        fill=CORE + (255,),
    )
    return icon.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> int:
    original = ROOT / 'assets' / 'icon.png'
    render().save(original, optimize=True)
    data = original.read_bytes()
    copies = 0
    for package in sorted((ROOT / 'packages').iterdir()):
        if not (package / 'pubspec.yaml').exists():
            continue
        folder = package / 'screenshots'
        folder.mkdir(exist_ok=True)
        (folder / 'icon.png').write_bytes(data)
        copies += 1
    print(f'assets/icon.png ({len(data) // 1024} KB) and {copies} copies written')
    return 0


if __name__ == '__main__':
    sys.exit(main())
