import pathlib
import sys

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
BACKGROUND = (27, 30, 36)
ACCENT = (95, 212, 200)
NODE = (38, 42, 49)
BRANCH = (64, 70, 80)
SIZE = 512
SCALE = 4


def _curve(start, end, pull, steps=96):
    (x0, y0), (x3, y3) = start, end
    x1, y1, x2, y2 = x0 + pull, y0, x3 - pull, y3
    points = []
    for i in range(steps + 1):
        t = i / steps
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t**3
        points.append((a * x0 + b * x1 + c * x2 + d * x3, a * y0 + b * y1 + c * y2 + d * y3))
    return points


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
    root = tuple(v * unit for v in (84, 216, 220, 296))
    children = [
        (tuple(v * unit for v in (300, 120, 432, 200)), ACCENT),
        (tuple(v * unit for v in (300, 312, 432, 392)), BRANCH),
    ]
    start = (220 * unit, 256 * unit)
    for box, _ in children:
        end = (box[0], (box[1] + box[3]) / 2)
        radius = 7 * unit
        for x, y in _curve(start, end, 52 * unit, steps=1200):
            draw.ellipse(
                (x - radius, y - radius, x + radius, y + radius),
                fill=BRANCH + (255,),
            )
    draw.rounded_rectangle(root, radius=int(24 * unit), fill=ACCENT + (255,))
    for box, outline in children:
        draw.rounded_rectangle(
            box,
            radius=int(24 * unit),
            fill=NODE + (255,),
            outline=outline + (255,),
            width=int(12 * unit),
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
