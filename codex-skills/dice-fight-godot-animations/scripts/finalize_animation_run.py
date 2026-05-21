#!/usr/bin/env python3
"""Finalize a Dice Fight character animation run into Godot-ready assets."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from typing import Dict, List, Tuple

from PIL import Image, ImageDraw


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def res_path(project_path: Path, file_path: Path) -> str:
    try:
        rel = file_path.resolve().relative_to(project_path.resolve())
        return "res://" + rel.as_posix()
    except ValueError:
        return file_path.as_posix()


def key_to_alpha(image: Image.Image, key: Tuple[int, int, int], threshold: int = 18) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            dist = abs(r - key[0]) + abs(g - key[1]) + abs(b - key[2])
            if dist <= threshold:
                pixels[x, y] = (r, g, b, 0)
    return rgba


def trim_and_center(frame: Image.Image, cell_size: Tuple[int, int]) -> Image.Image:
    cell_w, cell_h = cell_size
    alpha = frame.getchannel("A")
    bbox = alpha.getbbox()
    output = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
    if bbox is None:
        return output
    subject = frame.crop(bbox)
    scale = min((cell_w - 8) / max(1, subject.width), (cell_h - 8) / max(1, subject.height), 1.0)
    if scale < 1.0:
        subject = subject.resize((max(1, int(subject.width * scale)), max(1, int(subject.height * scale))), Image.Resampling.NEAREST)
    x = (cell_w - subject.width) // 2
    y = cell_h - subject.height - max(4, int(cell_h * 0.08))
    y = max(0, min(cell_h - subject.height, y))
    output.alpha_composite(subject, (x, y))
    return output


def extract_frames(row_image: Image.Image, frame_count: int, cell_size: Tuple[int, int], key: Tuple[int, int, int]) -> List[Image.Image]:
    keyed = key_to_alpha(row_image, key)
    frames = []
    source_w, source_h = keyed.size
    segment_w = source_w / float(frame_count)
    for index in range(frame_count):
        left = int(round(index * segment_w))
        right = int(round((index + 1) * segment_w))
        segment = keyed.crop((left, 0, right, source_h))
        frames.append(trim_and_center(segment, cell_size))
    return frames


def alpha_coverage(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    hist = alpha.histogram()
    nonzero = sum(hist[1:])
    return nonzero / float(image.width * image.height)


def make_contact_sheet(frames_by_animation: Dict[str, List[Image.Image]], cell_size: Tuple[int, int], path: Path) -> None:
    cell_w, cell_h = cell_size
    row_names = list(frames_by_animation.keys())
    max_frames = max(len(frames) for frames in frames_by_animation.values())
    label_w = 140
    sheet = Image.new("RGBA", (label_w + max_frames * cell_w, len(row_names) * cell_h), (32, 34, 38, 255))
    draw = ImageDraw.Draw(sheet)
    for row_index, name in enumerate(row_names):
        y = row_index * cell_h
        draw.text((8, y + 8), name, fill=(230, 230, 230, 255))
        for frame_index, frame in enumerate(frames_by_animation[name]):
            x = label_w + frame_index * cell_w
            draw.rectangle((x, y, x + cell_w - 1, y + cell_h - 1), outline=(80, 84, 92, 255), width=1)
            sheet.alpha_composite(frame, (x, y))
            draw.text((x + 4, y + 4), str(frame_index), fill=(230, 230, 230, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def make_spriteframes_tres(character_id: str, atlas_res_path: str, animations: Dict, cell_size: Tuple[int, int]) -> str:
    cell_w, cell_h = cell_size
    total_frames = sum(int(spec["frames"]) for spec in animations.values())
    lines = [
        '[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (total_frames + 2),
        "",
        '[ext_resource type="Texture2D" path="%s" id="1_atlas"]' % atlas_res_path,
        "",
    ]
    sub_ids = {}
    for name, spec in animations.items():
        frames = int(spec["frames"])
        row = int(spec["row"])
        sub_ids[name] = []
        for index in range(frames):
            sub_id = "%s_%02d" % (name, index)
            sub_ids[name].append(sub_id)
            lines.extend(
                [
                    '[sub_resource type="AtlasTexture" id="AtlasTexture_%s"]' % sub_id,
                    'atlas = ExtResource("1_atlas")',
                    "region = Rect2(%d, %d, %d, %d)" % (index * cell_w, row * cell_h, cell_w, cell_h),
                    "",
                ]
            )
    lines.append("[resource]")
    lines.append("animations = [")
    animation_chunks = []
    for name, spec in animations.items():
        frame_entries = []
        for sub_id in sub_ids[name]:
            frame_entries.append('{"duration": 1.0, "texture": SubResource("AtlasTexture_%s")}' % sub_id)
        chunk = (
            '{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.3f}'
            % (", ".join(frame_entries), "true" if spec["loop"] else "false", name, float(spec["fps"]))
        )
        animation_chunks.append(chunk)
    lines.append(",\n".join(animation_chunks))
    lines.append("]")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--project-path", default="")
    parser.add_argument("--install", action="store_true")
    args = parser.parse_args()

    run_dir = Path(args.run_dir).resolve()
    request = load_json(run_dir / "animation_request.json")
    jobs = load_json(run_dir / "imagegen-jobs.json")["jobs"]
    project_path = Path(args.project_path or request["project_path"]).resolve()
    character_id = request["character_id"]
    cell_size = tuple(request["cell_size"])
    key = tuple(request.get("chroma_key", [0, 255, 0]))
    animations = request["animations"]

    missing = [job["id"] for job in jobs if job.get("status") != "completed" or not Path(job["decoded_path"]).exists()]
    if missing:
        raise SystemExit("missing completed row(s): %s" % ", ".join(missing))

    frames_by_animation: Dict[str, List[Image.Image]] = {}
    review = {"errors": [], "warnings": [], "coverage": {}}
    frames_dir = run_dir / "frames"
    for job in jobs:
        name = job["id"]
        spec = animations[name]
        row_image = Image.open(job["decoded_path"])
        frames = extract_frames(row_image, int(spec["frames"]), cell_size, key)
        frames_by_animation[name] = frames
        out_dir = frames_dir / name
        out_dir.mkdir(parents=True, exist_ok=True)
        for index, frame in enumerate(frames):
            coverage = alpha_coverage(frame)
            review["coverage"]["%s/%02d" % (name, index)] = coverage
            if coverage < 0.005:
                review["errors"].append("%s frame %d appears empty" % (name, index))
            elif coverage < 0.02:
                review["warnings"].append("%s frame %d has very low subject coverage" % (name, index))
            frame.save(out_dir / ("%02d.png" % index))

    max_frames = max(int(spec["frames"]) for spec in animations.values())
    atlas_w = max_frames * cell_size[0]
    atlas_h = len(animations) * cell_size[1]
    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    for name, spec in animations.items():
        row = int(spec["row"])
        for index, frame in enumerate(frames_by_animation[name]):
            atlas.alpha_composite(frame, (index * cell_size[0], row * cell_size[1]))

    final_dir = run_dir / "final"
    qa_dir = run_dir / "qa"
    final_dir.mkdir(parents=True, exist_ok=True)
    atlas_path = final_dir / ("%s_animations.png" % character_id)
    atlas.save(atlas_path)
    make_contact_sheet(frames_by_animation, cell_size, qa_dir / "contact-sheet.png")

    manifest = {
        "character_id": character_id,
        "cell_size": list(cell_size),
        "atlas_size": [atlas_w, atlas_h],
        "atlas_path": str(atlas_path),
        "animations": animations,
    }
    manifest_path = final_dir / ("%s_animation_manifest.json" % character_id)
    write_json(manifest_path, manifest)

    spriteframes_path = final_dir / ("%s_sprite_frames.tres" % character_id)
    atlas_res = res_path(project_path, atlas_path)
    spriteframes_path.write_text(make_spriteframes_tres(character_id, atlas_res, animations, cell_size), encoding="utf-8")
    review["final_atlas"] = str(atlas_path)
    write_json(qa_dir / "review.json", review)

    if args.install:
        install_dir = project_path / "assets" / "characters" / character_id / "animations"
        install_dir.mkdir(parents=True, exist_ok=True)
        installed_atlas = install_dir / atlas_path.name
        installed_manifest = install_dir / manifest_path.name
        installed_tres = install_dir / spriteframes_path.name
        shutil.copy2(atlas_path, installed_atlas)
        shutil.copy2(manifest_path, installed_manifest)
        atlas_res = res_path(project_path, installed_atlas)
        installed_tres.write_text(make_spriteframes_tres(character_id, atlas_res, animations, cell_size), encoding="utf-8")
        manifest["atlas_path"] = res_path(project_path, installed_atlas)
        manifest["sprite_frames_path"] = res_path(project_path, installed_tres)
        write_json(installed_manifest, manifest)
        print("Installed assets to %s" % install_dir)

    print("Final atlas: %s" % atlas_path)
    print("SpriteFrames: %s" % spriteframes_path)
    print("QA contact sheet: %s" % (qa_dir / "contact-sheet.png"))
    if review["errors"]:
        print("Review errors: %d" % len(review["errors"]))
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
