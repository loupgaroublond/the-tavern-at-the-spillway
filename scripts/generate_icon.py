#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Generate Tavern app icon: orange squircle with JT text on black background."""

from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import math


def create_squircle_mask(size: int, radius_factor: float = 0.22) -> Image.Image:
    """Create a squircle (superellipse) mask."""
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)

    # Superellipse parameter (higher = more square-like)
    n = 4
    half = size // 2
    radius = int(size * radius_factor)

    # Draw filled squircle using polygon approximation
    points = []
    steps = 360
    for i in range(steps):
        theta = 2 * math.pi * i / steps
        # Superellipse formula
        cos_t = math.cos(theta)
        sin_t = math.sin(theta)
        x = half + half * 0.9 * (abs(cos_t) ** (2/n)) * (1 if cos_t >= 0 else -1)
        y = half + half * 0.9 * (abs(sin_t) ** (2/n)) * (1 if sin_t >= 0 else -1)
        points.append((x, y))

    draw.polygon(points, fill=255)
    return mask


def create_icon(size: int = 1024, dark_mode: bool = True) -> Image.Image:
    """Create the app icon.

    Args:
        size: Icon size in pixels
        dark_mode: If True, black background with orange text (for dark mode)
                   If False, orange background with black text (for light mode)
    """
    # Colors
    orange = (255, 149, 0)  # macOS system orange
    black = (0, 0, 0)

    bg_color = black if dark_mode else orange
    text_color = orange if dark_mode else black

    # Create base image with transparency
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Create squircle background
    squircle = create_squircle_mask(size)

    # Create the background with squircle shape
    background = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(background)

    # Fill with background color where squircle mask is
    for y in range(size):
        for x in range(size):
            if squircle.getpixel((x, y)) > 128:
                background.putpixel((x, y), (*bg_color, 255))

    img = background
    draw = ImageDraw.Draw(img)

    # Try to load Luminari font
    font_size = int(size * 0.45)
    font = None

    # Luminari is a decorative font with a medieval/fantasy feel
    font_paths = [
        "/Library/Fonts/Luminari.ttf",
        "/System/Library/Fonts/Supplemental/Luminari.ttf",
        "/System/Library/Fonts/Luminari.ttf",
    ]

    for font_path in font_paths:
        try:
            font = ImageFont.truetype(font_path, font_size)
            print(f"Using font: {font_path}")
            break
        except (OSError, IOError):
            continue

    if font is None:
        print("Warning: Luminari font not found, using default")
        font = ImageFont.load_default()

    # Draw "JT" text
    text = "JT"

    # Get text bounding box for centering
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    x = (size - text_width) // 2
    y = (size - text_height) // 2 - bbox[1]  # Adjust for baseline

    # Draw the text
    draw.text((x, y), text, fill=text_color, font=font)

    return img


def main():
    script_dir = Path(__file__).parent.parent / "Tavern" / "Sources" / "Tavern"
    assets_dir = script_dir / "Assets.xcassets"
    icon_dir = assets_dir / "AppIcon.appiconset"

    # Create directories
    icon_dir.mkdir(parents=True, exist_ok=True)

    # Generate dark mode icon (black bg, orange text) - this is the "any" appearance
    icon_dark = create_icon(1024, dark_mode=True)
    icon_dark_path = icon_dir / "AppIcon-Dark.png"
    icon_dark.save(icon_dark_path, "PNG")
    print(f"Created: {icon_dark_path}")

    # Generate light mode icon (orange bg, black text)
    icon_light = create_icon(1024, dark_mode=False)
    icon_light_path = icon_dir / "AppIcon-Light.png"
    icon_light.save(icon_light_path, "PNG")
    print(f"Created: {icon_light_path}")

    # Create Contents.json with light/dark variants
    # macOS uses "any" for the default and "dark" for dark mode
    # So light mode icon goes in "any", dark mode icon goes in "dark"
    sizes = ["16x16", "32x32", "128x128", "256x256", "512x512"]
    scales = ["1x", "2x"]

    images = []
    for size in sizes:
        for scale in scales:
            # Light mode (any appearance)
            images.append({
                "filename": "AppIcon-Light.png",
                "idiom": "mac",
                "scale": scale,
                "size": size
            })
            # Dark mode
            images.append({
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "filename": "AppIcon-Dark.png",
                "idiom": "mac",
                "scale": scale,
                "size": size
            })

    contents = {
        "images": images,
        "info": {"author": "xcode", "version": 1}
    }

    import json
    (icon_dir / "Contents.json").write_text(json.dumps(contents, indent=2))
    print(f"Created: {icon_dir / 'Contents.json'}")

    # Create root Contents.json for Assets.xcassets
    (assets_dir / "Contents.json").write_text('{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n')
    print(f"Created: {assets_dir / 'Contents.json'}")

    print("\nDone! Icons generated for light and dark mode.")


if __name__ == "__main__":
    main()
