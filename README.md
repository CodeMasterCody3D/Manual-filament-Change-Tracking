A Better M600 – Automatic Filament Tracking for Multi-Color Prints!

Tired of manually tracking your filament changes? This improved M600 macro for Klipper not only pauses for color swaps but also keeps track of your filament changes automatically! Easily swap colors mid-print without losing track of what comes next.

How It Works

Filament Change Logging:
Uses a combination of Python and Bash scripts to log each filament change automatically.

OrcaSlicer Integration:
Works seamlessly with OrcaSlicer

Automatic Tool Color Updates:
Automatically updates tool colors, so you can focus on printing rather than manual adjustments. Just use the color palette on Orca Slicer and select the color for your filament, Orca Slicer uses Hex data to keep track of the color, the script will use that hex data using CSS color library with 147 colors!


Installation Instructions

1. Prerequisites

Klipper Firmware:
Ensure Klipper is installed.

KIAUH (Klipper Installation And Update Helper):
Install the Shell Command Add-on via KIAUH if it's not already installed.

You will need to fix your z offset after installing because it places the shell command activation under the z offset. Just move it above the z offset section. 


2. Download the Repository

Clone or download this repository to your local machine:

```sh
git clone https://github.com/CodeMasterCody3D/Manual-filament-Change-Tracking.git
cd Manual-filament-Change-Tracking
```

3. Replace Hardcoded Username

This repository uses cody as a placeholder. Run the provided script to replace all occurrences of cody with your username--(HINT:VERY COMMONLY THE USERNAME IS ( pi ) IF YOUR RUNNING ON A RASPBERRY PI):

```sh
chmod +x replace_username.sh
./replace_username.sh
```

> Note: This script scans all files in the repository folder and only modifies files within that folder.



4. Install the Scripts

Copy the following scripts to your home directory (e.g., /home/$USER/):

get_tool_change_status.sh
tool_change_tracker.py
update_tool_change.py

For example:

```sh
cp get_tool_change_status.sh tool_change_tracker.py update_tool_change.py ~/
chmod +x ~/get_tool_change_status.sh ~/tool_change_tracker.py ~/update_tool_change.py
```

5. Update Your printer.cfg using add_to_printer.cfg

Copy and paste the provided macros and shell command definitions into your printer.cfg, replacing the resume and pause with the ones I provided in add_to_printer.cfg

Insert them above the auto-generated section (look for the marker #*# <---------------------- SAVE_CONFIG in your printer.cfg).


Macros: PAUSE, RESUME, M600, GET_PRINT_FILENAME, PRE_SCAN_TOOL_CHANGES, SAVE_PRINT_FILE, SHOW_TOOL_CHANGE_STATUS

Shell Commands: update_tool_change, pre_scan_tool_changes, track_tool_change, get_tool_change_status



6. Set Up OrcaSlicer

Filament Change G-code:
In OrcaSlicer, add the M600 command in the Filament Change G-code section.

Start G-code:
Insert the PRE_SCAN_TOOL_CHANGES macro at the beginning of your Start G-code.


Why This Is Useful

I built this solution for my Ender 3 Pro to simplify multi-color printing. It eliminates the hassle of manually tracking filament changes and ensures smooth color transitions during prints. 


---

Feel free to contribute, suggest improvements, or report issues via the repository's issue tracker. Enjoy your effortless multi-color printing! (Manually of course)
