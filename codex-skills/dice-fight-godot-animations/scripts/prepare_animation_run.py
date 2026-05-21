#!/usr/bin/env python3
"""Prepare a Dice Fight character animation run."""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Tuple

from PIL import Image, ImageDraw, ImageFont


DEFAULT_SPECS = {
    "select_idle": {"frames": 8, "fps": 6, "loop": True},
    "battle_idle": {"frames": 6, "fps": 6, "loop": True},
    "attack": {"frames": 6, "fps": 10, "loop": False},
    "skill_cast": {"frames": 8, "fps": 10, "loop": False},
    "guard": {"frames": 4, "fps": 8, "loop": False},
    "hurt": {"frames": 4, "fps": 8, "loop": False},
    "victory": {"frames": 6, "fps": 6, "loop": True},
    "defeat": {"frames": 6, "fps": 6, "loop": False},
    "rebirth": {"frames": 8, "fps": 10, "loop": False},
}

ANIMATION_INTENT = {
    "select_idle": "gentle character select idle loop with hair, clothing, weapon sway, and a subtle forward-back body rock",
    "battle_idle": "combat-ready breathing loop with stable weapon silhouette",
    "attack": "anticipation, weapon strike, and recovery for the primary attack",
    "skill_cast": "class-specific casting or skill pose without detached large VFX",
    "guard": "defensive brace or block pose",
    "hurt": "short compact hit reaction without gore",
    "victory": "small confident victory loop",
    "defeat": "readable defeated pose ending in a stable final frame",
    "rebirth": "Pyromancer rebirth motion with character-attached hard-edged flame only",
}


def parse_size(value: str) -> Tuple[int, int]:
    match = re.fullmatch(r"(\d+)x(\d+)", value.strip().lower())
    if not match:
        raise argparse.ArgumentTypeError("size must look like 128x128")
    width, height = int(match.group(1)), int(match.group(2))
    if width <= 0 or height <= 0:
        raise argparse.ArgumentTypeError("size values must be positive")
    return width, height


def parse_animations(value: str) -> List[str]:
    names = [item.strip() for item in value.split(",") if item.strip()]
    if not names:
        raise argparse.ArgumentTypeError("provide at least one animation")
    unknown = [name for name in names if name not in DEFAULT_SPECS]
    if unknown:
        raise argparse.ArgumentTypeError("unknown animation(s): %s" % ", ".join(unknown))
    return names


def make_guide(path: Path, animation: str, frame_count: int, cell_size: Tuple[int, int]) -> None:
    cell_w, cell_h = cell_size
    image = Image.new("RGB", (cell_w * frame_count, cell_h), (0, 255, 0))
    draw = ImageDraw.Draw(image)
    guide_color = (255, 0, 255)
    baseline_y = int(cell_h * 0.82)
    center_y = int(cell_h * 0.50)
    for index in range(frame_count):
        x0 = index * cell_w
        x1 = x0 + cell_w - 1
        draw.rectangle((x0, 0, x1, cell_h - 1), outline=guide_color, width=1)
        draw.line((x0 + cell_w // 2, 0, x0 + cell_w // 2, cell_h - 1), fill=(0, 128, 255))
        draw.line((x0, baseline_y, x1, baseline_y), fill=(255, 128, 0))
        draw.line((x0, center_y, x1, center_y), fill=(0, 128, 255))
        draw.text((x0 + 4, 4), str(index + 1), fill=guide_color)
    draw.text((4, cell_h - 18), "%s: guide only, do not copy marks" % animation, fill=guide_color)
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def make_prompt(
    character_id: str,
    display_name: str,
    animation: str,
    frame_count: int,
    cell_size: Tuple[int, int],
    character_notes: str,
    style_notes: str,
) -> str:
    cell_w, cell_h = cell_size
    intent = ANIMATION_INTENT.get(animation, animation.replace("_", " "))
    notes = character_notes.strip() or "Use the reference image as the canonical character identity."
    style = style_notes.strip() or "Dice Fight 2D pixel-art-adjacent fantasy combat sprite, limited palette, crisp readable silhouette, dark outline."
    return "\n".join(
        [
            "Create one horizontal animation row for Dice Fight Godot.",
            "",
            "Character: %s (%s)." % (display_name, character_id),
            "Canonical identity: %s" % notes,
            "Animation: %s - %s." % (animation, intent),
            "Frame count: exactly %d frames in one left-to-right row." % frame_count,
            "Cell intent: each frame should fit an implied %dx%d cell with stable baseline and generous padding." % (cell_w, cell_h),
            "Style: %s" % style,
            "",
            "Background: perfectly flat solid #00ff00 chroma-key background for removal.",
            "Do not use #00ff00 in the character, props, outline, highlights, or effects.",
            "No shadows, floor plane, scenery, UI, text, labels, frame numbers, visible grid, watermark, motion blur, speed lines, or detached symbols.",
            "Preserve the same silhouette, face, palette, outfit, weapon, handedness, and facing direction in every frame.",
            "Keep frames separated; no body, weapon, hair, or effect may cross into a neighboring frame slot.",
        ]
    )


def write_json(path: Path, data: Dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-path", required=True)
    parser.add_argument("--character-id", required=True)
    parser.add_argument("--display-name", default="")
    parser.add_argument("--reference", action="append", default=[])
    parser.add_argument("--output-dir", default="")
    parser.add_argument("--animations", type=parse_animations, default=parse_animations("select_idle,battle_idle,attack,hurt,guard,victory,defeat"))
    parser.add_argument("--cell-size", type=parse_size, default=(128, 128))
    parser.add_argument("--character-notes", default="")
    parser.add_argument("--style-notes", default="")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    project_path = Path(args.project_path).resolve()
    character_id = args.character_id.strip()
    if not re.fullmatch(r"[a-z0-9_]+", character_id):
        raise SystemExit("character-id must use lowercase letters, digits, or underscores")

    display_name = args.display_name.strip() or character_id.replace("_", " ").title()
    run_dir = Path(args.output_dir).resolve() if args.output_dir else project_path / "tmp" / "animation-runs" / character_id
    if run_dir.exists() and any(run_dir.iterdir()) and not args.force:
        raise SystemExit("run directory exists and is not empty; pass --force to reuse it: %s" % run_dir)

    prompts_dir = run_dir / "prompts"
    decoded_dir = run_dir / "decoded"
    guide_dir = run_dir / "references" / "layout-guides"
    for directory in (prompts_dir, decoded_dir, guide_dir):
        directory.mkdir(parents=True, exist_ok=True)

    references = []
    for raw_path in args.reference:
        ref_path = Path(raw_path).resolve()
        references.append({"path": str(ref_path), "role": "canonical character reference"})

    animations = {}
    jobs = []
    cell_size = list(args.cell_size)
    for animation in args.animations:
        spec = dict(DEFAULT_SPECS[animation])
        prompt_path = prompts_dir / ("%s.txt" % animation)
        guide_path = guide_dir / ("%s.png" % animation)
        decoded_path = decoded_dir / ("%s.png" % animation)
        make_guide(guide_path, animation, int(spec["frames"]), args.cell_size)
        prompt_path.write_text(
            make_prompt(
                character_id,
                display_name,
                animation,
                int(spec["frames"]),
                args.cell_size,
                args.character_notes,
                args.style_notes,
            )
            + "\n",
            encoding="utf-8",
        )
        animations[animation] = {
            "frames": int(spec["frames"]),
            "fps": float(spec["fps"]),
            "loop": bool(spec["loop"]),
            "row": len(animations),
        }
        jobs.append(
            {
                "id": animation,
                "status": "pending",
                "animation": animation,
                "prompt_file": str(prompt_path),
                "decoded_path": str(decoded_path),
                "input_images": references
                + [
                    {
                        "path": str(guide_path),
                        "role": "layout guide only; do not copy visible marks",
                    }
                ],
            }
        )

    request = {
        "project_path": str(project_path),
        "character_id": character_id,
        "display_name": display_name,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "cell_size": cell_size,
        "chroma_key": [0, 255, 0],
        "animations": animations,
        "references": references,
        "character_notes": args.character_notes,
        "style_notes": args.style_notes,
    }
    write_json(run_dir / "animation_request.json", request)
    write_json(run_dir / "imagegen-jobs.json", {"jobs": jobs})
    print("Prepared animation run: %s" % run_dir)
    print("Jobs: %s" % ", ".join(job["id"] for job in jobs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
