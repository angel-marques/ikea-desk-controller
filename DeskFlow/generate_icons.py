#!/usr/bin/env python3
"""
Generate app icons for DeskFlow macOS app
Creates icons in all required sizes for macOS app bundle
"""

from PIL import Image, ImageDraw
import os

# Icon sizes needed for macOS
SIZES = [16, 32, 64, 128, 256, 512, 1024]

# Colors from the design
BACKGROUND_COLOR = "#111111"
ACCENT_COLOR = "#FF8400"
DESK_COLOR = "#666666"


def create_icon(size: int) -> Image.Image:
    """Create a DeskFlow app icon at the specified size."""
    # Create base image with rounded corners effect
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Draw rounded rectangle background
    padding = int(size * 0.05)
    corner_radius = int(size * 0.2)
    draw.rounded_rectangle(
        [padding, padding, size - padding, size - padding],
        radius=corner_radius,
        fill=BACKGROUND_COLOR
    )

    # Scale factors
    center_x = size // 2
    center_y = size // 2

    # Draw desk illustration
    desk_width = int(size * 0.6)
    desk_height = int(size * 0.05)
    desk_y = int(center_y + size * 0.05)

    # Desk surface
    draw.rounded_rectangle(
        [center_x - desk_width // 2, desk_y,
         center_x + desk_width // 2, desk_y + desk_height],
        radius=int(size * 0.01),
        fill=DESK_COLOR
    )

    # Desk legs
    leg_width = int(size * 0.04)
    leg_height = int(size * 0.2)
    leg_y = desk_y + desk_height

    # Left leg
    draw.rounded_rectangle(
        [center_x - desk_width // 2 + leg_width, leg_y,
         center_x - desk_width // 2 + leg_width * 2, leg_y + leg_height],
        radius=int(size * 0.01),
        fill=ACCENT_COLOR
    )

    # Right leg
    draw.rounded_rectangle(
        [center_x + desk_width // 2 - leg_width * 2, leg_y,
         center_x + desk_width // 2 - leg_width, leg_y + leg_height],
        radius=int(size * 0.01),
        fill=ACCENT_COLOR
    )

    # Draw up arrow (main visual element)
    arrow_size = int(size * 0.25)
    arrow_y = int(center_y - size * 0.15)

    # Arrow body
    arrow_body_width = int(size * 0.08)
    arrow_body_height = int(size * 0.15)
    draw.rounded_rectangle(
        [center_x - arrow_body_width // 2, arrow_y,
         center_x + arrow_body_width // 2, arrow_y + arrow_body_height],
        radius=int(size * 0.02),
        fill=ACCENT_COLOR
    )

    # Arrow head (triangle)
    arrow_head_size = int(size * 0.15)
    arrow_head_y = arrow_y - int(size * 0.02)
    draw.polygon(
        [
            (center_x, arrow_head_y - arrow_head_size // 2),  # Top
            (center_x - arrow_head_size // 2, arrow_head_y + arrow_head_size // 2),  # Bottom left
            (center_x + arrow_head_size // 2, arrow_head_y + arrow_head_size // 2),  # Bottom right
        ],
        fill=ACCENT_COLOR
    )

    return img


def main():
    output_dir = "DeskFlow/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(output_dir, exist_ok=True)

    for size in SIZES:
        icon = create_icon(size)
        filename = f"icon_{size}.png"
        filepath = os.path.join(output_dir, filename)
        icon.save(filepath, "PNG")
        print(f"Created {filepath}")

    print("\nAll icons generated successfully!")


if __name__ == "__main__":
    main()
