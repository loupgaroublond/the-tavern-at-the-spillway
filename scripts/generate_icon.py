#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Generate Tavern app icon: orange squircle with JT text.

Supports both legacy .appiconset format and new .icon bundle format with light/dark mode.
"""

from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import math
import json


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

    # Try to load Bradley Hand font
    font_size = int(size * 0.45)
    font = None

    # Bradley Hand is a casual handwritten font
    font_paths = [
        "/Library/Fonts/Bradley Hand Bold.ttf",
        "/System/Library/Fonts/Supplemental/Bradley Hand Bold.ttf",
        "/System/Library/Fonts/Bradley Hand Bold.ttf",
    ]

    for font_path in font_paths:
        try:
            font = ImageFont.truetype(font_path, font_size)
            print(f"Using font: {font_path}")
            break
        except (OSError, IOError):
            continue

    if font is None:
        print("Warning: Bradley Hand font not found, using default")
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


# macOS icon size definitions: (catalog_size, scale, actual_pixels)
ICON_SIZES = [
    ("16x16", "1x", 16),
    ("16x16", "2x", 32),
    ("32x32", "1x", 32),
    ("32x32", "2x", 64),
    ("128x128", "1x", 128),
    ("128x128", "2x", 256),
    ("256x256", "1x", 256),
    ("256x256", "2x", 512),
    ("512x512", "1x", 512),
    ("512x512", "2x", 1024),
]


def create_icon_bundle(output_path: Path) -> None:
    """Create a .icon bundle with light/dark mode support.

    This creates the new macOS 26+ .icon format that supports automatic
    light/dark mode switching via Icon Composer's format.
    """
    icon_dir = output_path
    assets_dir = icon_dir / "Assets"

    # Create bundle structure
    icon_dir.mkdir(parents=True, exist_ok=True)
    assets_dir.mkdir(exist_ok=True)

    # Generate 1024x1024 icons for light and dark modes
    light_icon = create_icon(1024, dark_mode=False)  # Orange bg, black text
    dark_icon = create_icon(1024, dark_mode=True)    # Black bg, orange text

    light_icon.save(assets_dir / "icon-light.png", "PNG")
    dark_icon.save(assets_dir / "icon-dark.png", "PNG")
    print(f"Created: Assets/icon-light.png, Assets/icon-dark.png")

    # Create icon.json with light/dark opacity specializations
    icon_json = {
        "groups": [
            {
                "layers": [
                    {
                        "image-name": "icon-dark.png",
                        "name": "icon-dark",
                        "opacity-specializations": [
                            {"value": 0},  # Hidden in light mode (default)
                            {"appearance": "dark", "value": 1}  # Visible in dark mode
                        ]
                    },
                    {
                        "image-name": "icon-light.png",
                        "name": "icon-light",
                        "opacity-specializations": [
                            {"appearance": "dark", "value": 0}  # Hidden in dark mode
                            # Default (light mode) is implicitly opacity 1
                        ]
                    }
                ],
                "shadow": {"kind": "neutral", "opacity": 0.5},
                "translucency": {"enabled": True, "value": 0.5}
            }
        ],
        "supported-platforms": {
            "circles": ["watchOS"],
            "squares": "shared"
        }
    }

    (icon_dir / "icon.json").write_text(json.dumps(icon_json, indent=2))
    print(f"Created: icon.json")


def generate_legacy_appiconset(icon_dir: Path) -> None:
    """Generate legacy .appiconset format for older macOS versions."""
    icon_dir.mkdir(parents=True, exist_ok=True)

    # Remove old icon files
    for old_file in icon_dir.glob("AppIcon-*.png"):
        old_file.unlink()
        print(f"Removed old: {old_file.name}")

    # Generate icons at each required size (single variant for legacy format)
    images = []

    for size_str, scale, pixels in ICON_SIZES:
        filename = f"AppIcon-{size_str}@{scale}.png"
        icon = create_icon(pixels, dark_mode=True)  # Black bg, orange text
        icon.save(icon_dir / filename, "PNG")
        print(f"Created: {filename} ({pixels}x{pixels}px)")

        images.append({
            "filename": filename,
            "idiom": "mac",
            "scale": scale,
            "size": size_str,
        })

    # Write Contents.json
    contents = {
        "images": images,
        "info": {"author": "xcode", "version": 1}
    }
    (icon_dir / "Contents.json").write_text(json.dumps(contents, indent=2))
    print(f"Created: Contents.json")


def main():
    script_dir = Path(__file__).parent.parent / "Tavern" / "Sources" / "Tavern"
    assets_dir = script_dir / "Assets.xcassets"

    # Generate legacy .appiconset (for macOS 13-25 compatibility)
    legacy_dir = assets_dir / "AppIcon.appiconset"
    print("=== Generating legacy .appiconset ===")
    generate_legacy_appiconset(legacy_dir)
    print(f"Generated {len(ICON_SIZES)} legacy icons.\n")

    # Generate new .icon bundle (for macOS 26+ with light/dark support)
    icon_bundle_dir = script_dir / "AppIcon.icon"
    print("=== Generating .icon bundle (macOS 26+) ===")
    create_icon_bundle(icon_bundle_dir)
    print(f"Generated AppIcon.icon bundle with light/dark support.\n")

    # Create root Contents.json for Assets.xcassets
    (assets_dir / "Contents.json").write_text('{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n')

    print("Done! Both legacy and modern icon formats generated.")


if __name__ == "__main__":
    main()
