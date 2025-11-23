; dynamic_macro_m600.gcode - Example M600 filament change macro with tool tracking
;
; This file demonstrates how to integrate the manual filament change tracking
; with Klipper's M600 macro and dynamic macro system.
;
; USAGE:
;   1. Copy the macros below to your printer.cfg file
;   2. In OrcaSlicer, set the "Filament Change G-code" to: M600
;   3. In your Start G-code, add: PRE_SCAN_TOOL_CHANGES
;   4. The tracker will automatically log each filament change
;
; INTEGRATION NOTES:
;   - PRE_SCAN_TOOL_CHANGES must run at print start to scan the G-code file
;   - Each M600 call will update the tool change counter
;   - SHOW_TOOL_CHANGE_STATUS displays the current filament change info
;   - The tracking data is stored in /tmp/tool_change_data.json
;
; -----------------------------------------------------------------------------
; EXAMPLE KLIPPER MACROS
; -----------------------------------------------------------------------------

; Main M600 macro - handles filament change and tracking
[gcode_macro M600]
description: Filament change with automatic tracking
gcode:
    {% set X = params.X|default(50)|float %}
    {% set Y = params.Y|default(0)|float %}
    {% set Z = params.Z|default(10)|float %}
    
    ; Show which filament to load next
    SHOW_TOOL_CHANGE_STATUS
    
    ; Save current position
    SAVE_GCODE_STATE NAME=M600_state
    
    ; Pause the print
    PAUSE
    
    ; Move to change position
    G91                             ; Relative positioning
    G1 E-5 F2700                    ; Retract filament
    G1 Z{Z}                         ; Raise nozzle
    G90                             ; Absolute positioning
    G1 X{X} Y{Y} F3000              ; Move to change position
    
    ; Wait for user to change filament
    M117 Change filament - {printer.toolhead.extruder}
    
    ; Note: After changing filament, use RESUME to continue the print

; Display current tool change status
[gcode_macro SHOW_TOOL_CHANGE_STATUS]
description: Display current filament change information
gcode:
    {% set cmd = "get_tool_change_status.sh" %}
    RUN_SHELL_COMMAND CMD=get_tool_change_status PARAMS=""
    
; Pre-scan G-code file for tool changes before print starts
[gcode_macro PRE_SCAN_TOOL_CHANGES]
description: Scan G-code file for tool changes before printing
gcode:
    M117 Scanning for tool changes...
    SAVE_PRINT_FILE
    RUN_SHELL_COMMAND CMD=pre_scan_tool_changes PARAMS=""
    M117 Scan complete
    
; Save the current print file name for tracking
[gcode_macro SAVE_PRINT_FILE]
description: Save current print filename for tool tracking
gcode:
    {% set filename = printer.print_stats.filename %}
    M118 Current file: {filename}
    
; Update tool change counter (called after each M600)
[gcode_macro UPDATE_TOOL_CHANGE]
description: Increment tool change counter
gcode:
    RUN_SHELL_COMMAND CMD=update_tool_change PARAMS=""

; Modified RESUME macro to update tracking
[gcode_macro RESUME]
description: Resume print and update tool change tracking
rename_existing: BASE_RESUME
gcode:
    ; Restore position
    RESTORE_GCODE_STATE NAME=M600_state MOVE=1
    
    ; Update the tool change counter
    UPDATE_TOOL_CHANGE
    
    ; Resume the print
    BASE_RESUME

; -----------------------------------------------------------------------------
; SHELL COMMAND DEFINITIONS (add to printer.cfg)
; -----------------------------------------------------------------------------
;
; [gcode_shell_command get_tool_change_status]
; command: /home/YOUR_USERNAME/get_tool_change_status.sh
; timeout: 5.0
; verbose: True
;
; [gcode_shell_command pre_scan_tool_changes]
; command: /home/YOUR_USERNAME/tool_change_tracker.py scan
; timeout: 30.0
; verbose: True
;
; [gcode_shell_command update_tool_change]
; command: /home/YOUR_USERNAME/update_tool_change.py
; timeout: 5.0
; verbose: True
;
; -----------------------------------------------------------------------------
; EXAMPLE PRINT SEQUENCE
; -----------------------------------------------------------------------------
;
; START G-CODE (in OrcaSlicer):
;   G28                          ; Home all axes
;   PRE_SCAN_TOOL_CHANGES        ; Scan for tool changes
;   G1 Z5 F5000                  ; Raise nozzle
;   ; ... rest of start g-code
;
; FILAMENT CHANGE G-CODE (in OrcaSlicer):
;   M600                         ; Trigger filament change
;
; DURING PRINT:
;   - Printer will pause at each tool change marker
;   - Display shows which color/filament to load
;   - User changes filament manually
;   - User resumes print from control interface
;   - Tracking automatically updates
;
; -----------------------------------------------------------------------------
; TROUBLESHOOTING
; -----------------------------------------------------------------------------
;
; Issue: "No tool change data found"
; Solution: Ensure PRE_SCAN_TOOL_CHANGES runs in start g-code
;
; Issue: Shell commands not working
; Solution: Check paths in shell_command definitions match your installation
;
; Issue: Tracking not updating
; Solution: Verify update_tool_change.py has execute permissions
;           Check /tmp/tool_change_data.json exists and is readable
;
; For more help, see: https://github.com/CodeMasterCody3D/Manual-filament-Change-Tracking
