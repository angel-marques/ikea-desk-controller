# IKEA IDÅSEN Desk Controller

Control your IKEA IDÅSEN standing desk from macOS via Bluetooth Low Energy.

## Requirements

- macOS with Bluetooth
- IKEA IDÅSEN desk with LINAK Bluetooth controller
- Python 3.11+
- [uv](https://github.com/astral-sh/uv) package manager

## Installation

```bash
# Clone or download this project
cd ikea-table

# Install dependencies
uv sync
```

## Initial Setup

### 1. Grant Bluetooth Permissions

The first time you run the app, macOS will ask for Bluetooth permissions. Grant access to your terminal app (Terminal, iTerm, Warp, etc.) in:

**System Settings > Privacy & Security > Bluetooth**

### 2. Find Your Desk

Put your desk in pairing mode (the Bluetooth button should be blinking) and scan:

```bash
uv run python idasen_controller.py scan
```

Output:
```
Scanning for desks (10.0s)...
  Found: Desk Table [YOUR-DESK-UUID-HERE]
```

### 3. Save Your Desk UUID

```bash
uv run python idasen_controller.py -a YOUR_UUID config
```

This saves the UUID to `config.toml` so you don't need to specify it every time.

## Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `height` | Show current desk height |
| `up` | Move desk up (~1 second) |
| `down` | Move desk down (~1 second) |
| `stop` | Stop desk movement |
| `monitor` | Watch height in real-time |

```bash
# Show current height
uv run python idasen_controller.py height

# Monitor height while moving with physical buttons
uv run python idasen_controller.py monitor
# Press Ctrl+C to stop
```

### Preset Positions

Three built-in positions are available:

| Command | Default Height | Description |
|---------|---------------|-------------|
| `sit` | 72cm | Sitting position |
| `stand` | 110cm | Standing position |
| `walk` | 118cm | Walking pad/treadmill position |

```bash
uv run python idasen_controller.py sit
uv run python idasen_controller.py stand
uv run python idasen_controller.py walk
```

### Move to Specific Height

```bash
# Move to 85cm
uv run python idasen_controller.py move 0.85

# Move to 1 meter
uv run python idasen_controller.py move 1.0
```

Height range: **0.62m - 1.27m** (62cm - 127cm)

### Custom Presets

Save any height with a custom name:

```bash
# Save current height as a preset
uv run python idasen_controller.py save gaming

# List all saved presets
uv run python idasen_controller.py presets

# Move to a saved preset
uv run python idasen_controller.py go gaming

# Delete a preset
uv run python idasen_controller.py delete gaming
```

Presets are stored in `presets.json`.

## Configuration

### config.toml

Main configuration file with desk UUID and default heights:

```toml
addr = "YOUR-DESK-UUID-HERE"
sit_height = 0.761
stand_height = 1.1
walk_height = 1.18
```

### Changing Default Heights

```bash
# Change sit height to 75cm
uv run python idasen_controller.py --sit-height 0.75 config

# Change all heights at once
uv run python idasen_controller.py --sit-height 0.75 --stand-height 1.08 --walk-height 1.20 config
```

### presets.json

Custom presets are stored here:

```json
{
  "gaming": 0.78,
  "drawing": 0.95,
  "meeting": 1.05
}
```

## Shell Alias (Optional)

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
alias desk="uv run python ~/Code/lab/ikea-table/idasen_controller.py"
```

Then use:

```bash
desk sit
desk stand
desk go gaming
desk height
```

## Troubleshooting

### Desk not found during scan

1. Make sure Bluetooth is enabled on your Mac
2. Put the desk in pairing mode (Bluetooth button blinking)
3. Ensure the desk isn't connected to another device (phone app, etc.)

### Permission denied / Exit code 134

Grant Bluetooth permission to your terminal:
- **System Settings > Privacy & Security > Bluetooth**
- Add your terminal app to the list

### Desk doesn't move

1. Make sure you're not holding the physical buttons
2. Try the `up` or `down` command first to test basic movement
3. Check that the desk isn't at its height limit

### Connection fails

The desk may have gone to sleep. Press any button on the physical controller to wake it up, then try again.

## Technical Details

This tool communicates with the LINAK DPG1C Bluetooth controller built into IKEA IDÅSEN desks using the following BLE characteristics:

- **Height**: `99fa0021-338a-1024-8a49-009c0215f78a`
- **Command**: `99fa0002-338a-1024-8a49-009c0215f78a`
- **Reference Input**: `99fa0031-338a-1024-8a49-009c0215f78a`

Protocol information reverse-engineered by the community. See:
- [newAM/idasen](https://github.com/newAM/idasen)
- [rhyst/linak-controller](https://github.com/rhyst/linak-controller)

## License

MIT
