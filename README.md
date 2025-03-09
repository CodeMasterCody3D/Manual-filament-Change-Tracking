A Better M600 – Automatic Filament Tracking for Multi-Color Prints! 

Tired of manually tracking your filament changes? This improved M600 macro for Klipper not only pauses for color swaps but also keeps track of your filament changes! Now, you can easily swap colors mid-print without losing track of what's next. 

How It Works: 

Uses a Python script & bash script to log filament changes. 

Works with OrcaSlicer to enable seamless multi-color printing (up to 5 colors or more with modifications). 

Automatically updates tool colors so you can focus on the print, not the process!


Installation Steps: 

1. Install the Shell Command Add-on via KIAUH.


2. Place the scripts in your home directory (/home/$USER/).


3. Modify and add the provided macros to your printer.cfg.


4. Use hardcoded paths (until $HOME support is figured out).


5. Set up OrcaSlicer: 

Add M600 in the Filament Change G-code section. 

Add PRE_SCAN_TOOL_CHANGES at the beginning of your Start G-code.






My user name is cody, search my user name and edit it to be your user name.


Why This Is Useful 

I built this for my Ender 3 Pro so I can do multi-color prints without worrying about what color comes next. Works great on my mini HP computer running Klipper instead of a Raspberry Pi! 

If you find a way to get $HOME working in #3dprinting​ #3dprinteverything​ #3dprintlife​ stead of hardcoded paths, let me know! 

Subscribe for more Klipper mods & 3D printing tips!

   / a6m2cxqrbf  ​

#orcaslicer​ #3dprintingcommunity​ #android​
