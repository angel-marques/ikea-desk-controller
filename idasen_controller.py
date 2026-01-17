#!/usr/bin/env python3
"""
IKEA IDÅSEN Desk Controller for macOS
Control your standing desk via Bluetooth Low Energy
"""

import asyncio
import argparse
import json
import struct
import sys
from pathlib import Path
from typing import Optional

try:
    import tomllib
except ImportError:
    import tomli as tomllib

try:
    from bleak import BleakClient, BleakScanner
    from bleak.backends.device import BLEDevice
except ImportError:
    print("Error: bleak library not found.")
    print("Install it with: pip install bleak")
    sys.exit(1)


# BLE UUIDs for LINAK desk controller
UUID_HEIGHT = "99fa0021-338a-1024-8a49-009c0215f78a"
UUID_COMMAND = "99fa0002-338a-1024-8a49-009c0215f78a"
UUID_REFERENCE_INPUT = "99fa0031-338a-1024-8a49-009c0215f78a"
UUID_DPG = "99fa0011-338a-1024-8a49-009c0215f78a"

# Commands
CMD_UP = bytearray([0x47, 0x00])
CMD_DOWN = bytearray([0x46, 0x00])
CMD_STOP = bytearray([0xFF, 0x00])
CMD_WAKEUP = bytearray([0xFE, 0x00])

# Height limits (in meters)
MIN_HEIGHT = 0.62
MAX_HEIGHT = 1.27

# Default positions (adjust to your preference)
POSITION_SIT = 0.72
POSITION_STAND = 1.10
POSITION_WALK = 1.18  # For walking pad/treadmill

# Config directory (~/.config/desk/)
CONFIG_DIR = Path.home() / ".config" / "desk"
CONFIG_PATH = CONFIG_DIR / "config.toml"
PRESETS_PATH = CONFIG_DIR / "presets.json"


def load_config() -> dict:
    """Load configuration from config.toml."""
    if not CONFIG_PATH.exists():
        return {}
    try:
        with open(CONFIG_PATH, "rb") as f:
            return tomllib.load(f)
    except Exception:
        return {}


def save_config(config: dict):
    """Save configuration to config.toml."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    lines = ["# IKEA IDÅSEN Desk Controller Configuration\n"]
    if "addr" in config:
        lines.append(f'addr = "{config["addr"]}"\n')
    if "sit_height" in config:
        lines.append(f"sit_height = {config['sit_height']}\n")
    if "stand_height" in config:
        lines.append(f"stand_height = {config['stand_height']}\n")
    if "walk_height" in config:
        lines.append(f"walk_height = {config['walk_height']}\n")
    with open(CONFIG_PATH, "w") as f:
        f.writelines(lines)


def load_presets() -> dict:
    """Load presets from presets.json."""
    if not PRESETS_PATH.exists():
        return {}
    try:
        with open(PRESETS_PATH, "r") as f:
            return json.load(f)
    except Exception:
        return {}


def save_presets(presets: dict):
    """Save presets to presets.json."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    with open(PRESETS_PATH, "w") as f:
        json.dump(presets, f, indent=2)


def raw_to_meters(raw: int) -> float:
    """Convert raw height value to meters."""
    return (raw / 10000.0) + MIN_HEIGHT


def meters_to_raw(meters: float) -> int:
    """Convert meters to raw height value."""
    return int((meters - MIN_HEIGHT) * 10000)


class IdasenDesk:
    def __init__(self, address: str):
        self.address = address
        self.client: Optional[BleakClient] = None
        self._height = 0.0
        self._speed = 0

    async def connect(self) -> bool:
        """Connect to the desk."""
        self.client = BleakClient(self.address)
        try:
            await self.client.connect()
            # Subscribe to height notifications
            await self.client.start_notify(UUID_HEIGHT, self._height_callback)
            # Wake up the desk
            await self.client.write_gatt_char(UUID_COMMAND, CMD_WAKEUP)
            await asyncio.sleep(0.5)
            return True
        except Exception as e:
            print(f"Connection failed: {e}")
            return False

    async def disconnect(self):
        """Disconnect from the desk."""
        if self.client and self.client.is_connected:
            await self.client.stop_notify(UUID_HEIGHT)
            await self.client.disconnect()

    def _height_callback(self, sender, data: bytearray):
        """Handle height notification."""
        raw_height, raw_speed = struct.unpack("<Hh", data)
        self._height = raw_to_meters(raw_height)
        self._speed = raw_speed

    async def get_height(self) -> float:
        """Get current desk height in meters."""
        data = await self.client.read_gatt_char(UUID_HEIGHT)
        raw_height, _ = struct.unpack("<Hh", data)
        self._height = raw_to_meters(raw_height)
        return self._height

    async def move_up(self):
        """Move desk up for ~1 second."""
        await self.client.write_gatt_char(UUID_COMMAND, CMD_WAKEUP)
        await self.client.write_gatt_char(UUID_COMMAND, CMD_UP)

    async def move_down(self):
        """Move desk down for ~1 second."""
        await self.client.write_gatt_char(UUID_COMMAND, CMD_WAKEUP)
        await self.client.write_gatt_char(UUID_COMMAND, CMD_DOWN)

    async def stop(self):
        """Stop desk movement."""
        await self.client.write_gatt_char(UUID_COMMAND, CMD_STOP)

    async def move_to(self, target_height: float):
        """Move desk to target height in meters."""
        target_height = max(MIN_HEIGHT, min(MAX_HEIGHT, target_height))

        # Stop notifications during movement to avoid conflicts
        await self.client.stop_notify(UUID_HEIGHT)

        try:
            # Get initial height with direct read
            current = await self.get_height()
            print(f"Current: {current:.2f}m -> Target: {target_height:.2f}m")

            if abs(current - target_height) < 0.005:
                print("Already at target height")
                return

            # Prepare: wakeup and stop to initialize reference input
            await self.client.write_gatt_char(UUID_COMMAND, CMD_WAKEUP)
            await asyncio.sleep(0.1)
            await self.client.write_gatt_char(UUID_COMMAND, CMD_STOP)
            await asyncio.sleep(0.1)

            # Convert target to raw bytes
            raw_target = meters_to_raw(target_height)
            target_bytes = struct.pack("<H", raw_target)

            previous_height = current
            stall_count = 0

            while True:
                # Send target position - this makes the desk move automatically
                await self.client.write_gatt_char(UUID_REFERENCE_INPUT, target_bytes)
                await asyncio.sleep(0.2)

                # Read height directly
                current = await self.get_height()
                print(f"  Height: {current:.3f}m ({current*100:.1f}cm)    ", end="\r")

                # Check if we reached target or stopped moving
                if abs(current - target_height) < 0.005:
                    print(f"\nReached target: {current:.2f}m ({current*100:.1f}cm)")
                    break

                # Detect if desk stopped moving (stalled)
                if abs(current - previous_height) < 0.001:
                    stall_count += 1
                    if stall_count > 10:
                        print(f"\nDesk stopped at: {current:.2f}m ({current*100:.1f}cm)")
                        break
                else:
                    stall_count = 0

                previous_height = current

        except asyncio.CancelledError:
            await self.stop()
            raise
        finally:
            await self.stop()
            # Re-enable notifications
            await self.client.start_notify(UUID_HEIGHT, self._height_callback)

    async def monitor(self):
        """Monitor desk height continuously."""
        print("Monitoring height (Ctrl+C to stop)...")
        await asyncio.sleep(0.3)  # Wait for first notification
        try:
            while True:
                height = self._height
                cm = height * 100
                print(f"Height: {height:.3f}m ({cm:.1f}cm) | Speed: {self._speed}    ", end="\r")
                await asyncio.sleep(0.2)
        except asyncio.CancelledError:
            pass


async def scan_for_desks(timeout: float = 10.0) -> list:
    """Scan for IKEA IDÅSEN desks."""
    print(f"Scanning for desks ({timeout}s)...")

    desks = []
    devices = await BleakScanner.discover(timeout=timeout)

    for device in devices:
        name = device.name or ""
        if "desk" in name.lower() or "idasen" in name.lower() or "linak" in name.lower():
            desks.append(device)
            print(f"  Found: {device.name} [{device.address}]")

    if not desks:
        print("\nNo desks found. Showing all BLE devices:")
        for device in devices:
            if device.name:
                print(f"  {device.name} [{device.address}]")

    return desks


async def async_main():
    # Load config first
    config = load_config()

    parser = argparse.ArgumentParser(
        description="Control your IKEA IDÅSEN desk from macOS",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s scan                    # Find your desk
  %(prog)s height                  # Show current height
  %(prog)s sit                     # Move to sitting position
  %(prog)s stand                   # Move to standing position
  %(prog)s walk                    # Move to walking pad position
  %(prog)s move 1.05               # Move to 1.05 meters
  %(prog)s save mypreset           # Save current height as 'mypreset'
  %(prog)s go mypreset             # Move to 'mypreset'
  %(prog)s presets                 # List all presets
  %(prog)s delete mypreset         # Delete 'mypreset'
        """
    )

    parser.add_argument("--addr", "-a", help="Desk Bluetooth UUID (use 'scan' to find it)")
    parser.add_argument("--sit-height", type=float,
                        default=config.get("sit_height", POSITION_SIT),
                        help=f"Sitting position height in meters (default: {config.get('sit_height', POSITION_SIT)})")
    parser.add_argument("--stand-height", type=float,
                        default=config.get("stand_height", POSITION_STAND),
                        help=f"Standing position height in meters (default: {config.get('stand_height', POSITION_STAND)})")
    parser.add_argument("--walk-height", type=float,
                        default=config.get("walk_height", POSITION_WALK),
                        help=f"Walking pad position height in meters (default: {config.get('walk_height', POSITION_WALK)})")

    subparsers = parser.add_subparsers(dest="command", help="Commands")

    subparsers.add_parser("scan", help="Scan for desks")
    subparsers.add_parser("height", help="Show current height")
    subparsers.add_parser("up", help="Move desk up")
    subparsers.add_parser("down", help="Move desk down")
    subparsers.add_parser("stop", help="Stop desk movement")
    subparsers.add_parser("sit", help="Move to sitting position")
    subparsers.add_parser("stand", help="Move to standing position")
    subparsers.add_parser("walk", help="Move to walking pad position")
    subparsers.add_parser("monitor", help="Monitor height continuously")
    subparsers.add_parser("config", help="Save current settings to config file")
    subparsers.add_parser("presets", help="List all saved presets")

    move_parser = subparsers.add_parser("move", help="Move to specific height")
    move_parser.add_argument("target", type=float, help="Target height in meters (0.62-1.27)")

    save_parser = subparsers.add_parser("save", help="Save current height as a preset")
    save_parser.add_argument("name", help="Name for the preset")

    delete_parser = subparsers.add_parser("delete", help="Delete a preset")
    delete_parser.add_argument("name", help="Name of the preset to delete")

    go_parser = subparsers.add_parser("go", help="Move to a saved preset")
    go_parser.add_argument("name", help="Name of the preset")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    if args.command == "scan":
        await scan_for_desks()
        return

    if args.command == "presets":
        presets = load_presets()
        if not presets:
            print("No presets saved yet.")
            print("Use 'preset-save <name>' to save the current height as a preset.")
        else:
            print("Saved presets:")
            for name, height in sorted(presets.items()):
                print(f"  {name}: {height:.3f}m ({height*100:.1f}cm)")
        return

    if args.command == "delete":
        presets = load_presets()
        if args.name not in presets:
            print(f"Preset '{args.name}' not found.")
            sys.exit(1)
        del presets[args.name]
        save_presets(presets)
        print(f"Preset '{args.name}' deleted.")
        return

    # Use addr from args, or fall back to config
    addr = args.addr or config.get("addr")

    if args.command == "config":
        if not addr:
            print("Error: --addr is required to save config.")
            sys.exit(1)
        new_config = {
            "addr": addr,
            "sit_height": args.sit_height,
            "stand_height": args.stand_height,
            "walk_height": args.walk_height,
        }
        save_config(new_config)
        print(f"Config saved to {CONFIG_PATH}")
        print(f"  addr = {addr}")
        print(f"  sit_height = {args.sit_height}")
        print(f"  stand_height = {args.stand_height}")
        print(f"  walk_height = {args.walk_height}")
        return

    if not addr:
        print("Error: --addr is required. Use 'scan' command to find your desk UUID.")
        print("       Or run 'config --addr UUID' to save it.")
        sys.exit(1)

    desk = IdasenDesk(addr)

    print(f"Connecting to {addr}...")
    if not await desk.connect():
        sys.exit(1)

    print("Connected!")

    try:
        if args.command == "height":
            height = await desk.get_height()
            print(f"Height: {height:.3f}m ({height * 100:.1f}cm)")

        elif args.command == "up":
            await desk.move_up()
            print("Moving up...")

        elif args.command == "down":
            await desk.move_down()
            print("Moving down...")

        elif args.command == "stop":
            await desk.stop()
            print("Stopped")

        elif args.command == "sit":
            print(f"Moving to sitting position ({args.sit_height}m)...")
            await desk.move_to(args.sit_height)

        elif args.command == "stand":
            print(f"Moving to standing position ({args.stand_height}m)...")
            await desk.move_to(args.stand_height)

        elif args.command == "walk":
            print(f"Moving to walking pad position ({args.walk_height}m)...")
            await desk.move_to(args.walk_height)

        elif args.command == "move":
            if args.target < MIN_HEIGHT or args.target > MAX_HEIGHT:
                print(f"Warning: Height should be between {MIN_HEIGHT}m and {MAX_HEIGHT}m")
            await desk.move_to(args.target)

        elif args.command == "monitor":
            await desk.monitor()

        elif args.command == "save":
            height = await desk.get_height()
            presets = load_presets()
            presets[args.name] = round(height, 3)
            save_presets(presets)
            print(f"Preset '{args.name}' saved at {height:.3f}m ({height*100:.1f}cm)")

        elif args.command == "go":
            presets = load_presets()
            if args.name not in presets:
                print(f"Preset '{args.name}' not found.")
                print("Available presets:", ", ".join(presets.keys()) if presets else "(none)")
                sys.exit(1)
            target = presets[args.name]
            print(f"Moving to preset '{args.name}' ({target}m)...")
            await desk.move_to(target)

    except KeyboardInterrupt:
        print("\nInterrupted")
        await desk.stop()

    finally:
        await desk.disconnect()
        print("Disconnected")


def main():
    """Entry point for the CLI."""
    asyncio.run(async_main())


if __name__ == "__main__":
    main()
