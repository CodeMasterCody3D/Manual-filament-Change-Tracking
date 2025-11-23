A Better M600 – Automatic Filament Tracking for Multi-Color Prints!

Tired of manually tracking your filament changes? This improved M600 macro for Klipper not only pauses for color swaps but also keeps track of your filament changes automatically! Easily swap colors mid-print without losing track of what comes next.

## How It Works

**Filament Change Logging:**
Uses a combination of Python and Bash scripts to log each filament change automatically.

**OrcaSlicer Integration:**
Works seamlessly with OrcaSlicer

**Automatic Tool Color Updates:**
Automatically updates tool colors, so you can focus on printing rather than manual adjustments. Just use the color palette on Orca Slicer and select the color for your filament, Orca Slicer uses Hex data to keep track of the color, the script will use that hex data using CSS color library with 147 colors!

## Installation Instructions

### 1. Prerequisites

**Klipper Firmware:**
Ensure Klipper is installed.

**KIAUH (Klipper Installation And Update Helper):**
Install the Shell Command Add-on via KIAUH if it's not already installed.

**Install jq:**

```sh
sudo apt-get install jq
```

> **Note:** You will need to fix your z offset after installing because it places the shell command activation under the z offset. Just move it above the z offset section.

### 2. Download the Repository

Clone or download this repository to your local machine:

```sh
git clone https://github.com/CodeMasterCody3D/Manual-filament-Change-Tracking.git
cd Manual-filament-Change-Tracking
```

### 3. Replace Hardcoded Username

This repository uses cody as a placeholder. Run the provided script to replace all occurrences of cody with your username (HINT: VERY COMMONLY THE USERNAME IS `pi` IF YOU'RE RUNNING ON A RASPBERRY PI):

```sh
chmod +x replace_username.sh
./replace_username.sh
```

> **Note:** This script scans all files in the repository folder and only modifies files within that folder.

### 4. Install the Scripts

**Option A: Use the Interactive Installer (Recommended)**

The easiest way to install is using the provided installer:

```sh
./scripts/install.sh
```

This will:
- Prompt you for the installation directory (default: `/usr/local/bin`)
- Check permissions and advise if sudo is needed
- Install all required scripts with correct permissions
- Display next steps

For non-interactive installation:

```sh
./scripts/install.sh --yes --install-dir /usr/local/bin
```

**Option B: Manual Installation**

Copy the following scripts to your home directory (e.g., `/home/$USER/`):

```sh
cp tool_change_tracker.py update_tool_change.py ~/
cp scripts/get_tool_change_status.sh ~/
chmod +x ~/get_tool_change_status.sh ~/tool_change_tracker.py ~/update_tool_change.py
```

### 5. Verify Installation

Run the verification script to ensure everything is installed correctly:

```sh
./scripts/verify_install.sh
```

This will check:
- Required dependencies (Python, jq)
- Script installation and permissions
- Basic command execution

### 6. Update Your printer.cfg using add_to_printer.cfg

Copy and paste the provided macros and shell command definitions into your `printer.cfg`, replacing the RESUME and PAUSE macros with the ones provided in `add_to_printer.cfg`.

Insert them above the auto-generated section (look for the marker `#*# <---------------------- SAVE_CONFIG` in your `printer.cfg`).

**Macros:** PAUSE, RESUME, M600, GET_PRINT_FILENAME, PRE_SCAN_TOOL_CHANGES, SAVE_PRINT_FILE, SHOW_TOOL_CHANGE_STATUS

**Shell Commands:** update_tool_change, pre_scan_tool_changes, track_tool_change, get_tool_change_status

See `examples/dynamic_macro_m600.gcode` for a complete example with comments.

### 7. Set Up OrcaSlicer

**Filament Change G-code:**
In OrcaSlicer, add the M600 command in the Filament Change G-code section.

**Start G-code:**
Insert the `PRE_SCAN_TOOL_CHANGES` macro at the beginning of your Start G-code.

## Usage

### Tool Change Tracker

The main tracking script with improved JSON handling and CLI options:

```sh
# Scan the latest G-code file
tool_change_tracker.py scan

# Scan a specific file
tool_change_tracker.py scan /path/to/file.gcode

# Dry run (preview without writing)
tool_change_tracker.py --dry-run scan

# Verbose output for debugging
tool_change_tracker.py --verbose scan
```

### Get Tool Change Status

Check the current tool change status:

```sh
# Human-readable output
get_tool_change_status.sh

# Machine-readable JSON output
get_tool_change_status.sh --json

# Use custom install directory
get_tool_change_status.sh --install-dir /usr/local/bin
```

Example JSON output:
```json
{
  "status": "in_progress",
  "current_change": 0,
  "total_changes": 3,
  "progress": 1,
  "tool_number": 1,
  "color": "Blue",
  "brand": "eSUN",
  "material": "PLA",
  "line": 1234
}
```

### Dynamic Macro Example

The `examples/dynamic_macro_m600.gcode` file contains:
- Complete M600 macro implementation
- Integration with tool tracking
- Klipper configuration examples
- Usage instructions and troubleshooting

This example shows how to:
- Trigger filament changes with M600
- Automatically track tool changes
- Display current filament information
- Integrate with OrcaSlicer

## Troubleshooting

### "No tool change data found"
**Solution:** Ensure `PRE_SCAN_TOOL_CHANGES` runs in your start G-code before any tool changes occur.

### Shell commands not working
**Solution:** 
- Verify paths in shell_command definitions match your installation
- Check that scripts have execute permissions: `ls -l ~/tool_change_tracker.py`
- Run `./scripts/verify_install.sh` to check installation

### Tracking not updating
**Solution:** 
- Verify `update_tool_change.py` has execute permissions
- Check that `/tmp/tool_change_data.json` exists and is readable
- Run the tracker in verbose mode: `tool_change_tracker.py --verbose scan`

### JSON file corruption
**Solution:**
- The new version uses atomic writes to prevent corruption
- If file is corrupted, delete `/tmp/tool_change_data.json` and re-scan
- Run with `--dry-run` first to test before writing

### Installation directory not in PATH
**Solution:**
Add to your `~/.bashrc` or `~/.profile`:
```sh
export PATH="/usr/local/bin:$PATH"
```
Then reload: `source ~/.bashrc`

## Advanced Usage

### Custom Install Location

Override the default install location:

```sh
# Using environment variable
INSTALL_DIR=/opt/klipper/bin get_tool_change_status.sh

# Using command-line flag
get_tool_change_status.sh --install-dir /opt/klipper/bin
```

### Custom JSON File Location

Override the default JSON file location:

```sh
# Using environment variable
JSON_FILE=/home/pi/toolchange.json get_tool_change_status.sh
```

## Why This Is Useful

I built this solution for my Ender 3 Pro to simplify multi-color printing. It eliminates the hassle of manually tracking filament changes and ensures smooth color transitions during prints.

## Contributing

Feel free to contribute, suggest improvements, or report issues via the repository's issue tracker. Enjoy your effortless multi-color printing! (Manually of course)
