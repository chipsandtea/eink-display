#!/usr/bin/env python3

import argparse
from pathlib import Path
from PIL import Image, ImageOps, ImageEnhance, ImageFilter, ImageDraw


PAPER_BG = (240, 233, 220)
INK = (30, 30, 30)
SOFT_SHADOW = (220, 213, 198)


def generate_sample_photo(path: Path, label: str, hue: tuple[int, int, int]) -> None:
    width, height = 640, 480
    img = Image.new("RGB", (width, height), (244, 238, 229))

    draw = ImageDraw.Draw(img)
    for y in range(height):
        t = y / height
        r = int(220 + 25 * (1 - t))
        g = int(230 + 10 * (1 - t))
        b = int(230 + 15 * (1 - t))
        draw.line((0, y, width, y), fill=(r, g, b))

    draw.rectangle((0, int(height * 0.62), width, height), fill=(157, 178, 145))
    draw.polygon([(0, int(height * 0.68)), (140, int(height * 0.44)), (260, int(height * 0.68))], fill=(96, 116, 82))
    draw.polygon([(120, int(height * 0.68)), (300, int(height * 0.36)), (500, int(height * 0.68))], fill=(88, 106, 77))
    draw.polygon([(360, int(height * 0.68)), (520, int(height * 0.42)), (640, int(height * 0.68))], fill=(100, 118, 88))

    draw.rectangle((120, int(height * 0.52), 190, height), fill=(150, 119, 78))
    draw.rectangle((150, int(height * 0.44), 190, height), fill=(121, 99, 62))
    draw.rectangle((210, int(height * 0.58), 300, height), fill=(149, 118, 80))
    draw.rectangle((240, int(height * 0.50), 280, height), fill=(117, 97, 61))

    draw.ellipse((440, 180, 560, 300), fill=(245, 230, 188))
    draw.ellipse((470, 210, 530, 270), fill=(250, 247, 226))

    draw.rounded_rectangle((40, 40, width - 40, height - 40), radius=12, outline=(70, 70, 70), width=2)
    draw.text((60, 60), label, fill=(35, 35, 35), anchor="la")

    img = ImageEnhance.Contrast(img).enhance(1.15)
    img = ImageOps.grayscale(img)
    img = ImageOps.autocontrast(img)
    img = img.filter(ImageFilter.GaussianBlur(radius=0.2))
    img.save(path)


def build_album_page(photo_paths: list[Path], title: str, output_path: Path) -> None:
    page_w, page_h = 1200, 1800
    canvas = Image.new("RGB", (page_w, page_h), PAPER_BG)
    draw = ImageDraw.Draw(canvas)

    draw.rectangle((60, 60, page_w - 60, page_h - 60), outline=(110, 100, 86), width=4)
    draw.text((100, 110), title.upper(), fill=(30, 30, 30), anchor="la")
    draw.line((100, 180, page_w - 100, 180), fill=(90, 90, 90), width=2)

    grid = [
        (100, 240, 520, 760),
        (620, 240, 1040, 760),
        (100, 820, 520, 1340),
        (620, 820, 1040, 1340),
    ]

    for idx, photo_path in enumerate(photo_paths[:4]):
        photo = Image.open(photo_path).convert("RGB")
        photo = ImageOps.fit(photo, (grid[idx][2] - grid[idx][0], grid[idx][3] - grid[idx][1]), method=Image.Resampling.LANCZOS)
        photo = ImageOps.grayscale(photo)
        photo = ImageEnhance.Contrast(photo).enhance(1.5)
        photo = ImageOps.autocontrast(photo)

        card = Image.new("RGB", (grid[idx][2] - grid[idx][0], grid[idx][3] - grid[idx][1]), (250, 245, 234))
        card.paste(photo, (0, 0))
        card = card.filter(ImageFilter.GaussianBlur(radius=0.15))

        canvas.paste(card, box=(grid[idx][0], grid[idx][1]))
        draw.rounded_rectangle((grid[idx][0], grid[idx][1], grid[idx][2], grid[idx][3]), outline=(80, 80, 80), width=3, radius=18)

    draw.text((100, 1440), "family • travel • home • moments", fill=(52, 52, 52), anchor="la")
    draw.text((100, 1500), "slow memories, light power, paper calm.", fill=(65, 65, 65), anchor="la")

    for _ in range(450):
        x = __import__("random").randint(80, page_w - 80)
        y = __import__("random").randint(100, page_h - 100)
        r = __import__("random").randint(1, 3)
        draw.ellipse((x, y, x + r, y + r), fill=(120, 120, 120))

    canvas = ImageOps.autocontrast(canvas)
    canvas = canvas.filter(ImageFilter.SMOOTH_MORE)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output_path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a paper-like e-ink photo album page.")
    parser.add_argument("--out", type=Path, default=Path("output/album_preview.png"), help="Path for the generated page.")
    parser.add_argument("--title", type=str, default="Home Memories", help="Album title shown on the page.")
    parser.add_argument("--count", type=int, default=4, help="Number of sample photos to generate.")
    args = parser.parse_args()

    photo_dir = args.out.parent / "samples"
    photo_dir.mkdir(parents=True, exist_ok=True)

    sample_paths = []
    labels = ["Spring", "Coast", "Garden", "Evening"]
    for idx in range(min(args.count, 4)):
        sample_path = photo_dir / f"sample_{idx}.png"
        generate_sample_photo(sample_path, labels[idx], (0, 0, 0))
        sample_paths.append(sample_path)

    if not sample_paths:
        raise ValueError("At least one sample photo is required.")

    build_album_page(sample_paths, args.title, args.out)
    print(f"Album page saved to: {args.out}")


if __name__ == "__main__":
    main()
