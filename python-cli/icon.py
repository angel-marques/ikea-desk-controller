#!/usr/bin/env python3
"""Generate app icon for IKEA Desk Controller - macOS style."""

from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import math


def create_rounded_rectangle_mask(size, radius):
    """Create a mask for rounded rectangle (squircle-like)."""
    mask = Image.new('L', size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size[0]-1, size[1]-1], radius=radius, fill=255)
    return mask


def create_gradient(size, color1, color2, vertical=True):
    """Create a gradient image."""
    img = Image.new('RGBA', size)
    for i in range(size[1] if vertical else size[0]):
        ratio = i / (size[1] if vertical else size[0])
        r = int(color1[0] + (color2[0] - color1[0]) * ratio)
        g = int(color1[1] + (color2[1] - color1[1]) * ratio)
        b = int(color1[2] + (color2[2] - color1[2]) * ratio)
        a = int(color1[3] + (color2[3] - color1[3]) * ratio) if len(color1) > 3 else 255

        if vertical:
            for j in range(size[0]):
                img.putpixel((j, i), (r, g, b, a))
        else:
            for j in range(size[1]):
                img.putpixel((i, j), (r, g, b, a))
    return img


def create_icon(size=512):
    """Create a macOS-style desk icon."""
    # Create base image
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))

    # Background gradient (dark blue-gray)
    bg_top = (55, 65, 81, 255)      # Slate gray
    bg_bottom = (31, 41, 55, 255)   # Darker slate
    bg = create_gradient((size, size), bg_top, bg_bottom)

    # Apply squircle mask (macOS style rounded corners)
    radius = size // 4
    mask = create_rounded_rectangle_mask((size, size), radius)
    bg.putalpha(mask)
    img.paste(bg, (0, 0), bg)

    draw = ImageDraw.Draw(img)

    # Calculate dimensions
    padding = size // 6
    center_x = size // 2
    center_y = size // 2

    # Desk surface (elegant rounded rectangle)
    desk_width = size - padding * 2
    desk_height = size // 14
    desk_y = center_y - size // 20
    desk_radius = desk_height // 2

    # Desk surface gradient (light blue/teal)
    desk_color_light = (96, 165, 250)   # Light blue
    desk_color_dark = (59, 130, 246)    # Blue

    # Draw desk surface with subtle highlight
    desk_rect = [padding, desk_y, size - padding, desk_y + desk_height]
    draw.rounded_rectangle(desk_rect, radius=desk_radius, fill=desk_color_dark)

    # Highlight on top of desk
    highlight_rect = [padding + 2, desk_y + 2, size - padding - 2, desk_y + desk_height // 2]
    draw.rounded_rectangle(highlight_rect, radius=desk_radius // 2, fill=desk_color_light)

    # Desk legs (sleek)
    leg_width = size // 20
    leg_inset = size // 5
    leg_top = desk_y + desk_height
    leg_bottom = size - padding - size // 10
    leg_color = (107, 114, 128)  # Gray
    leg_highlight = (156, 163, 175)  # Light gray

    # Left leg
    left_leg_x = padding + leg_inset
    draw.rounded_rectangle(
        [left_leg_x, leg_top, left_leg_x + leg_width, leg_bottom],
        radius=leg_width // 3,
        fill=leg_color
    )
    # Leg highlight
    draw.line(
        [(left_leg_x + 2, leg_top + 5), (left_leg_x + 2, leg_bottom - 5)],
        fill=leg_highlight, width=2
    )

    # Right leg
    right_leg_x = size - padding - leg_inset - leg_width
    draw.rounded_rectangle(
        [right_leg_x, leg_top, right_leg_x + leg_width, leg_bottom],
        radius=leg_width // 3,
        fill=leg_color
    )
    # Leg highlight
    draw.line(
        [(right_leg_x + 2, leg_top + 5), (right_leg_x + 2, leg_bottom - 5)],
        fill=leg_highlight, width=2
    )

    # Foot bar
    foot_y = leg_bottom - size // 25
    draw.rounded_rectangle(
        [left_leg_x, foot_y, right_leg_x + leg_width, foot_y + size // 30],
        radius=size // 60,
        fill=leg_color
    )

    # Up arrow (elegant chevron style)
    arrow_color = (52, 211, 153)  # Emerald/teal
    arrow_size = size // 8
    arrow_thickness = size // 25
    arrow_y = desk_y - size // 8

    # Up chevron
    points_up = [
        (center_x - arrow_size // 2, arrow_y + arrow_size // 3),
        (center_x, arrow_y - arrow_size // 6),
        (center_x + arrow_size // 2, arrow_y + arrow_size // 3),
    ]
    draw.line(points_up, fill=arrow_color, width=arrow_thickness, joint="curve")

    # Second up chevron (smaller, above)
    arrow_y2 = arrow_y - arrow_size // 2
    points_up2 = [
        (center_x - arrow_size // 3, arrow_y2 + arrow_size // 4),
        (center_x, arrow_y2 - arrow_size // 8),
        (center_x + arrow_size // 3, arrow_y2 + arrow_size // 4),
    ]
    draw.line(points_up2, fill=(*arrow_color[:3], 180), width=arrow_thickness - 2, joint="curve")

    # Down arrow
    arrow_y_down = leg_bottom + size // 12

    # Down chevron
    points_down = [
        (center_x - arrow_size // 2, arrow_y_down - arrow_size // 3),
        (center_x, arrow_y_down + arrow_size // 6),
        (center_x + arrow_size // 2, arrow_y_down - arrow_size // 3),
    ]
    draw.line(points_down, fill=arrow_color, width=arrow_thickness, joint="curve")

    # Second down chevron
    arrow_y_down2 = arrow_y_down + arrow_size // 2
    points_down2 = [
        (center_x - arrow_size // 3, arrow_y_down2 - arrow_size // 4),
        (center_x, arrow_y_down2 + arrow_size // 8),
        (center_x + arrow_size // 3, arrow_y_down2 - arrow_size // 4),
    ]
    draw.line(points_down2, fill=(*arrow_color[:3], 180), width=arrow_thickness - 2, joint="curve")

    return img


def main():
    icon_dir = Path(__file__).parent

    # Create high-res icon first
    icon_hires = create_icon(512)

    # Save different sizes with proper downscaling
    sizes = [512, 256, 128, 64, 32]

    for size in sizes:
        if size == 512:
            icon = icon_hires
        else:
            icon = icon_hires.resize((size, size), Image.Resampling.LANCZOS)

        icon.save(icon_dir / f"icon_{size}.png")
        print(f"Created icon_{size}.png")

    # Main icon (256 is good default)
    icon_256 = icon_hires.resize((256, 256), Image.Resampling.LANCZOS)
    icon_256.save(icon_dir / "icon.png")
    print("Created icon.png")


if __name__ == "__main__":
    main()
