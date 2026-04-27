<p align="center">
  <img src="logo.png" alt="Manual Filament Change Tracking Logo" width="420">
</p>

A Better M600 – Automatic Filament Tracking for Multi-Color Prints!

Tired of manually tracking your filament changes? This improved M600 macro for Klipper not only pauses for color swaps but also keeps track of your filament changes automatically! Easily swap colors mid-print without losing track of what comes next.

How It Works

Filament Change Logging:
Uses a combination of Python and Bash scripts to log each filament change automatically, so you can seamlessly print multicolor prints without having to keep track of which color comes next.

OrcaSlicer Integration:
Works seamlessly with OrcaSlicer

Automatic Tool Color Updates:
Automatically updates tool colors, so you can focus on printing rather than manual adjustments. Just use the color palette on Orca Slicer and select the color for your filament, Orca Slicer uses Hex data to keep track of the color, the script will use that hex data using CSS color library with 147 colors!


Installation Instructions

1. Prerequisites

Klipper Firmware:
Ensure Klipper is installed.

Make sure to install the Gcode Shell Command extension using KIAUH installer.

[Click here to open KIAUH](https://github.com/dw-0/kiauh)

Install Dynamic Macros
```sh
cd ~
git clone https://github.com/3DCoded/DynamicMacros
cd DynamicMacros
sh install.sh
sudo service klipper restart
```
KIAUH (Klipper Installation And Update Helper):
Install the Shell Command Add-on via KIAUH if it's not already installed.

Install jq

```sh
sudo apt-get install jq
```



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
generate_filament_prompt_macro.py

Copy the files with this command:

```sh
cp get_tool_change_status.sh tool_change_tracker.py update_tool_change.py generate_filament_prompt_macro.py ~/
chmod +x ~/get_tool_change_status.sh ~/tool_change_tracker.py ~/update_tool_change.py generate_filament_prompt_macro.py
```

5. Update Your printer.cfg using add_to_printer.cfg

Copy and paste the provided macros that are inside add_to_printer.cfg and shell command definitions into your printer.cfg, replacing the resume and pause with the ones I provided in add_to_printer.cfg

(alternatively, you can just add it to the dynamic macros section.)

#What it should look like with alternative method.

you should comment out your current resume and and pause macro and any m600 macros you have.

```sh
[dynamicmacros]
configs: dynamic.cfg, dynamic_prompt.cfg, add_to_printer.cfg
```

Insert them above the auto-generated section that gets created when setting z offset(look for the marker #*# <---------------------- SAVE_CONFIG in your printer.cfg). 



6. Set Up OrcaSlicer

Filament Change G-code:
In OrcaSlicer, add the M600 command in the Filament Change G-code section.

Start G-code:
Insert the PRE_SCAN_TOOL_CHANGES macro at the beginning of your Start G-code.


Why This Is Useful

I built this solution for my Ender 3 Pro to simplify multi-color printing. It eliminates the hassle of manually tracking filament changes and ensures smooth color transitions during prints. 


---

Feel free to contribute, suggest improvements, or report issues via the repository's issue tracker. Enjoy your effortless multi-color printing! (Manually of course)
