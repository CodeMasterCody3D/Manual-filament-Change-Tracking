#!/usr/bin/env python3
"""Generate a KlipperScreen prompt macro from tool-change tracker JSON."""

import argparse
import json
import os#
import sys
from typing import Any, Dict


DEFAULT_JSON_PATH = "/tmp/tool_change_data.json"


def _load_data(path: str) -> Dict[str, Any]:
    if not os.path.exists(path):
        raise FileNotFoundError(f"Tool-change data file not found: {path}")
    with open(path, "r", encoding="utf-8") as infile:
        return json.load(infile)


def _escape_msg_text(value: str) -> str:
    # Keep Klipper RESPOND MSG parser happy.
    return str(value).replace('"', '\\"').replace("#", "\\#")


def _build_macro(
    data: Dict[str, Any],
    macro_name: str,
    include_brand_material: bool,
    resume_gcode: str,
    extrude_gcode: str,
    retract_gcode: str,
    cancel_gcode: str,
) -> str:
    total_changes = int(data.get("total_changes", 0))
    current_change = int(data.get("current_change", 0))
    changes = data.get("changes", [])

    if total_changes <= 0 or not changes:
        title = "No tool changes found"
        body = "No manual tool change markers were detected in this file."
        lines = [
            f"[gcode_macro {macro_name}]",
            "description: Show next filament change prompt",
            "gcode:",
            f'  RESPOND TYPE=command MSG="action:prompt_begin {_escape_msg_text(title)}"',
            f'  RESPOND TYPE=command MSG="action:prompt_text {_escape_msg_text(body)}"',
            '  RESPOND TYPE=command MSG="action:prompt_footer_button Close|RESPOND MSG=No_Changes|secondary"',
            '  RESPOND TYPE=command MSG="action:prompt_show"',
        ]
        return "\n".join(lines) + "\n"

    if current_change >= total_changes:
        title = "Tool changes completed"
        body = f"All {total_changes} planned filament changes are complete."
        lines = [
            f"[gcode_macro {macro_name}]",
            "description: Show next filament change prompt",
            "gcode:",
            f'  RESPOND TYPE=command MSG="action:prompt_begin {_escape_msg_text(title)}"',
            f'  RESPOND TYPE=command MSG="action:prompt_text {_escape_msg_text(body)}"',
            '  RESPOND TYPE=command MSG="action:prompt_footer_button Close|RESPOND MSG=Completed|secondary"',
            '  RESPOND TYPE=command MSG="action:prompt_show"',
        ]
        return "\n".join(lines) + "\n"

    next_idx = current_change
    change = changes[next_idx]
    change_no = next_idx + 1

    tool = change.get("tool_number", "Unknown")
    color = change.get("color", "Unknown")
    line = change.get("line", "Unknown")
    full_name = change.get("full_name", "Unknown")
    brand = change.get("brand", "Unknown")
    material = change.get("material", "Unknown")

    detail = f"Change {change_no}/{total_changes}: Load {color} on T{tool} (line {line})."
    if include_brand_material:
        detail += f" Filament: {brand} {material} ({full_name})."

    lines = [
        f"[gcode_macro {macro_name}]",
        "description: Show next filament change prompt",
        "gcode:",
        '  RESPOND TYPE=command MSG="action:prompt_begin Filament change required"',
        f'  RESPOND TYPE=command MSG="action:prompt_text {_escape_msg_text(detail)}"',
        f'  RESPOND TYPE=command MSG="action:prompt_footer_button Resume|{_escape_msg_text(resume_gcode)}|primary"',
        f'  RESPOND TYPE=command MSG="action:prompt_footer_button Retract|{_escape_msg_text(retract_gcode)}|warning"',
        f'  RESPOND TYPE=command MSG="action:prompt_footer_button Extrude|{_escape_msg_text(extrude_gcode)}|info"',
        f'  RESPOND TYPE=command MSG="action:prompt_footer_button Cancel|{_escape_msg_text(cancel_gcode)}|error"',
        '  RESPOND TYPE=command MSG="action:prompt_show"',
    ]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate a Klipper prompt macro from tool-change data."
    )
    parser.add_argument(
        "--json",
        default=DEFAULT_JSON_PATH,
        help=f"Path to tool-change JSON (default: {DEFAULT_JSON_PATH})",
    )
    parser.add_argument(
        "--macro-name",
        default="SHOW_NEXT_TOOL_CHANGE_PROMPT",
        help="Generated macro name",
    )
    parser.add_argument(
        "--resume-gcode",
        default="RESUME",
        help="G-code run by Resume button",
    )
    parser.add_argument(
        "--cancel-gcode",
        default="CANCEL_PRINT",
        help="G-code run by Cancel button",
    )
    parser.add_argument(
        "--retract-gcode",
        default="RETRACT_FILAMENT LEN=12",
        help="G-code run by Retract button",
    )
    parser.add_argument(
        "--extrude-gcode",
        default="EXTRUDE_FILAMENT LEN=12",
        help="G-code run by Extrude button",
    )
    parser.add_argument(
        "--include-brand-material",
        action="store_true",
        help="Include brand/material/full_name in prompt text",
    )
    parser.add_argument(
        "--output",
        default="",
        help="Write macro to file path (defaults to stdout)",
    )
    args = parser.parse_args()

    try:
        data = _load_data(args.json)
        macro = _build_macro(
            data=data,
            macro_name=args.macro_name,
            include_brand_material=args.include_brand_material,
            resume_gcode=args.resume_gcode,
            extrude_gcode=args.extrude_gcode,
            retract_gcode=args.retract_gcode,
            cancel_gcode=args.cancel_gcode,
        )
    except Exception as exc:  # pragma: no cover
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if args.output:
        with open(args.output, "w", encoding="utf-8") as outfile:
            outfile.write(macro)
        print(f"Wrote macro to {args.output}")
    else:
        print(macro, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
