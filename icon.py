#!/usr/bin/env python3
"""Generate app icon for IKEA Desk Controller."""

from PIL import Image, ImageDraw
from pathlib import Path


def create_icon(size=256):
    """Create a minimalist desk icon."""
    # Create image with transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Colors
    bg_color = (45, 45, 48, 255)  # Dark background
    desk_color = (100, 149, 237, 255)  # Cornflower blue
    leg_color = (80, 80, 85, 255)  # Dark gray
    arrow_color = (76, 175, 80, 255)  # Green

    margin = size // 8
    center = size // 2

    # Background circle
    draw.ellipse(
        [margin // 2, margin // 2, size - margin // 2, size - margin // 2],
        fill=bg_color
    )

    # Desk top (thick rectangle)
    desk_top = size // 5
    desk_height = size // 12
    desk_y = center - size // 10
    draw.rounded_rectangle(
        [margin + desk_top, desk_y, size - margin - desk_top, desk_y + desk_height],
        radius=size // 40,
        fill=desk_color
    )

    # Desk legs
    leg_width = size // 16
    leg_top = desk_y + desk_height
    leg_bottom = size - margin - size // 6

    # Left leg
    left_leg_x = margin + desk_top + size // 10
    draw.rectangle(
        [left_leg_x, leg_top, left_leg_x + leg_width, leg_bottom],
        fill=leg_color
    )

    # Right leg
    right_leg_x = size - margin - desk_top - size // 10 - leg_width
    draw.rectangle(
        [right_leg_x, leg_top, right_leg_x + leg_width, leg_bottom],
        fill=leg_color
    )

    # Up arrow (above desk)
    arrow_size = size // 10
    arrow_y = desk_y - arrow_size - size // 20
    arrow_x = center

    # Up arrow triangle
    draw.polygon([
        (arrow_x, arrow_y),
        (arrow_x - arrow_size // 2, arrow_y + arrow_size),
        (arrow_x + arrow_size // 2, arrow_y + arrow_size)
    ], fill=arrow_color)

    # Down arrow (below desk)
    arrow_y_down = leg_bottom + size // 20

    draw.polygon([
        (arrow_x, arrow_y_down + arrow_size),
        (arrow_x - arrow_size // 2, arrow_y_down),
        (arrow_x + arrow_size // 2, arrow_y_down)
    ], fill=arrow_color)

    return img


def main():
    icon_dir = Path(__file__).parent

    # Create different sizes
    sizes = [256, 128, 64, 32]

    for size in sizes:
        icon = create_icon(size)
        icon.save(icon_dir / f"icon_{size}.png")
        print(f"Created icon_{size}.png")

    # Main icon
    icon = create_icon(256)
    icon.save(icon_dir / "icon.png")
    print("Created icon.png")


if __name__ == "__main__":
    main()
