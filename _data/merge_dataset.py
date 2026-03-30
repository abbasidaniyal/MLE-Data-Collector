"""
merge_dataset.py
----------------
Merges all zip datasets in this folder into a single standardized dataset.

Standardization rules:
  - Fix known typos in class names (e.g. "caluclator" -> "calculator")
  - Multi-class folder names are sorted alphabetically (e.g. "book_backpack" -> "backpack_book")
  - Strip any top-level wrapper folder inside a zip
  - For flat zips where the label is encoded in the filename (e.g. out_final.zip),
    derive the label from the filename stem (stripping trailing numbers/suffixes)
  - Loose image files in _data/ (not inside a zip) are also ingested;
    their label is derived from the filename stem
  - Skip files that are not images
  - Convert every image to 128x128 RGB PNG (resize if needed)
  - Re-number images per class as img0.png, img1.png, ...

Output:
  - merged/ directory with the standardized structure
  - merged_dataset.zip containing the same structure
  - A summary report printed to stdout
"""

import os
import re
import zipfile
import io
import sys
from collections import defaultdict
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required. Install with: pip install Pillow")

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

DATA_DIR = Path(__file__).parent
OUTPUT_DIR = DATA_DIR / "merged"
OUTPUT_ZIP = DATA_DIR / "merged_dataset.zip"
REVIEW_DIR = DATA_DIR / "merged_review"

EXPECTED_SIZE = (128, 128)
EXPECTED_MODE = "RGB"

# Known class-name typos: wrong -> correct
TYPO_MAP = {
    "caluclator": "calculator",
    "calcultor": "calculator",
    "calulator": "calculator",
    "bootle": "bottle",
    "bottel": "bottle",
    "laptops": "laptop",
    "chairs": "chair",
    "books": "book",
    "bottles": "bottle",
    "backpacks": "backpack",
    "pens": "pen",
    "phones": "phone",
    "clocks": "clock",
    "keychains": "keychain",
    "papers": "paper",
    "desks": "desk",
}

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif", ".tiff"}

# Zips where images are flat (no class sub-folders) and the label is
# encoded in the image filename stem instead.
FILENAME_LABEL_ZIPS = {"out_final.zip"}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def normalize_folder_name(raw: str) -> str:
    """Return the canonical folder name for a given raw label string."""
    parts = raw.strip().lower().split("_")
    corrected = [TYPO_MAP.get(p, p) for p in parts if p]
    corrected_sorted = sorted(set(corrected))   # deduplicate + sort
    return "_".join(corrected_sorted)


def label_from_stem(stem: str) -> str:
    """
    Derive a class label from an image filename stem.
    e.g. "clock_desk_paper"    -> "clock_desk_paper"
         "bootle_clock_desk1"  -> "bottle_clock_desk"  (typo fix + trailing digit strip)
         "desk_1"              -> "desk"
         "desk (2)"            -> "desk"  (copy-number suffix stripped)
         "chair_desk (2)"      -> "chair_desk"
    """
    # Strip OS copy-number suffixes like " (2)", " (3)", " copy", etc.
    cleaned = re.sub(r'\s*\(\d+\)\s*$', '', stem.strip())
    cleaned = re.sub(r'\s+copy\s*\d*$', '', cleaned, flags=re.IGNORECASE)
    # Replace spaces with underscores, then split
    parts = cleaned.lower().replace(" ", "_").split("_")
    # Drop tokens that are purely numeric; strip trailing digits glued to word (e.g. "desk1" -> "desk")
    parts = [re.sub(r'\d+$', '', p) for p in parts if p and not p.isdigit()]
    parts = [p for p in parts if p]  # drop any that became empty after digit strip
    raw = "_".join(parts)
    return normalize_folder_name(raw)


def is_top_level_wrapper(namelist: list[str]) -> str | None:
    """
    If every path inside the zip starts with the same single directory,
    return that directory name (acts as a wrapper to strip).
    """
    prefixes = set()
    for name in namelist:
        top = name.split("/")[0]
        if top:
            prefixes.add(top)
    if len(prefixes) == 1:
        prefix = next(iter(prefixes))
        # Make sure it really is a wrapper (not just a single class folder)
        second_levels = set()
        for name in namelist:
            parts = name.split("/")
            if len(parts) >= 2 and parts[1]:
                second_levels.add(parts[1])
        if len(second_levels) > 1:
            return prefix + "/"
    return None


def load_image_bytes(data: bytes, filename: str) -> Image.Image | None:
    """Load an image from bytes; return None on failure."""
    try:
        img = Image.open(io.BytesIO(data))
        img.load()
        return img
    except Exception as e:
        print(f"  [WARN] Cannot open {filename}: {e}")
        return None


def to_128_rgb_png(img: Image.Image) -> bytes:
    """Convert a PIL image to 128x128 RGB PNG bytes."""
    if img.mode != EXPECTED_MODE:
        img = img.convert(EXPECTED_MODE)
    if img.size != EXPECTED_SIZE:
        img = img.resize(EXPECTED_SIZE, Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    zip_files = sorted(
        p for p in DATA_DIR.iterdir()
        if p.suffix == ".zip" and p.name != OUTPUT_ZIP.name
    )
    loose_images = sorted(
        p for p in DATA_DIR.iterdir()
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    )

    if not zip_files and not loose_images:
        sys.exit("No zip files or loose images found in _data/")

    print(f"Found {len(zip_files)} zip file(s): {[z.name for z in zip_files]}")
    print(f"Found {len(loose_images)} loose image file(s): {[f.name for f in loose_images]}\n")

    # class_label -> list of PNG bytes
    class_images: dict[str, list[bytes]] = defaultdict(list)
    # track issues for reporting
    issues: list[str] = []
    source_stats: dict[str, dict] = {}

    for zip_path in zip_files:
        print(f"Processing: {zip_path.name}")
        use_filename_label = zip_path.name in FILENAME_LABEL_ZIPS
        with zipfile.ZipFile(zip_path, "r") as zf:
            namelist = zf.namelist()
            wrapper = is_top_level_wrapper(namelist)
            zip_counts: dict[str, int] = defaultdict(int)

            for entry in namelist:
                # Strip wrapper prefix
                rel = entry[len(wrapper):] if wrapper and entry.startswith(wrapper) else entry

                parts = rel.rstrip("/").split("/")
                filename = parts[-1]

                # Skip directories and hidden files
                if not filename or filename.startswith("."):
                    continue

                ext = Path(filename).suffix.lower()
                if ext not in IMAGE_EXTENSIONS:
                    continue

                if use_filename_label:
                    # Label is encoded in the filename stem, not the folder
                    stem = Path(filename).stem
                    label = label_from_stem(stem)
                else:
                    if len(parts) < 2:
                        continue  # stray top-level file in a folder-based zip
                    folder_raw = parts[0]
                    label = normalize_folder_name(folder_raw)

                if not label:
                    issues.append(f"  Empty label from '{entry}' in {zip_path.name}")
                    continue

                # Read and convert image
                data = zf.read(entry)
                img = load_image_bytes(data, entry)
                if img is None:
                    issues.append(f"  Unreadable: {entry} in {zip_path.name}")
                    continue

                png_bytes = to_128_rgb_png(img)
                class_images[label].append(png_bytes)
                zip_counts[label] += 1

            source_stats[zip_path.name] = dict(zip_counts)
            total_in_zip = sum(zip_counts.values())
            if use_filename_label:
                print(f"  Extracted {total_in_zip} image(s) across {len(zip_counts)} class(es) [label-from-filename mode]")
            else:
                print(f"  Extracted {total_in_zip} image(s) across {len(zip_counts)} class folder(s)")

    # Process loose image files in _data/ (label derived from filename stem)
    if loose_images:
        print(f"Processing loose images...")
        loose_counts: dict[str, int] = defaultdict(int)
        for img_path in loose_images:
            label = label_from_stem(img_path.stem)
            if not label:
                issues.append(f"  Empty label from loose file '{img_path.name}'")
                continue
            data = img_path.read_bytes()
            img = load_image_bytes(data, img_path.name)
            if img is None:
                issues.append(f"  Unreadable loose file: {img_path.name}")
                continue
            png_bytes = to_128_rgb_png(img)
            class_images[label].append(png_bytes)
            loose_counts[label] += 1
        source_stats["(loose files)"] = dict(loose_counts)
        print(f"  Extracted {sum(loose_counts.values())} image(s) across {len(loose_counts)} class(es)")

    print()

    # ---------------------------------------------------------------------------
    # Write output
    # ---------------------------------------------------------------------------
    OUTPUT_DIR.mkdir(exist_ok=True)

    # Clear old output dir
    for old in OUTPUT_DIR.rglob("*"):
        if old.is_file():
            old.unlink()
    for old in sorted(OUTPUT_DIR.rglob("*/"), reverse=True):
        try:
            old.rmdir()
        except OSError:
            pass

    # Clear old review dir
    REVIEW_DIR.mkdir(exist_ok=True)
    for old in REVIEW_DIR.iterdir():
        if old.is_file():
            old.unlink()

    with zipfile.ZipFile(OUTPUT_ZIP, "w", zipfile.ZIP_DEFLATED) as out_zip:
        for label, images in sorted(class_images.items()):
            label_dir = OUTPUT_DIR / label
            label_dir.mkdir(parents=True, exist_ok=True)
            for i, png_bytes in enumerate(images):
                fname = f"img{i}.png"
                (label_dir / fname).write_bytes(png_bytes)
                out_zip.writestr(f"{label}/{fname}", png_bytes)
                # Flat review copy: prefix with label so filenames are unique
                (REVIEW_DIR / f"{label}__{fname}").write_bytes(png_bytes)

    print(f"Merged dataset written to:  {OUTPUT_DIR}")
    print(f"Flat review folder:         {REVIEW_DIR}")
    print(f"ZIP archive written to:     {OUTPUT_ZIP}\n")

    # ---------------------------------------------------------------------------
    # Statistics & validation report
    # ---------------------------------------------------------------------------
    total_images = sum(len(v) for v in class_images.values())
    print("=" * 60)
    print("DATASET REPORT")
    print("=" * 60)
    print(f"\nTotal images: {total_images}\n")

    print(f"{'Class':<35} {'Count':>6}  {'% of total':>10}  {'≥10%?':>6}")
    print("-" * 65)

    class_violations: list[str] = []
    for label in sorted(class_images.keys()):
        count = len(class_images[label])
        pct = count / total_images * 100 if total_images else 0

        # For ≥10% requirement we count each single-class constituent
        # The requirement says each CLASS LABEL must appear in ≥10% of images.
        # Each multi-class folder contributes to each constituent class.
        pass  # handled below

        ok = ""  # placeholder, recalculated after class-level aggregation
        print(f"  {label:<33} {count:>6}  {pct:>9.1f}%  {ok:>6}")

    # Count per individual class label (each folder contributes to all its classes)
    per_class_count: dict[str, int] = defaultdict(int)
    for label, images in class_images.items():
        for cls in label.split("_"):
            per_class_count[cls] += len(images)

    print()
    print(f"{'Individual class':<20}  {'Images containing class':>22}  {'% of total':>10}  {'≥10%?':>6}")
    print("-" * 68)
    for cls in sorted(per_class_count.keys()):
        count = per_class_count[cls]
        pct = count / total_images * 100 if total_images else 0
        ok = "OK" if pct >= 10.0 else "FAIL"
        if ok == "FAIL":
            class_violations.append(cls)
        print(f"  {cls:<20}  {count:>22}  {pct:>9.1f}%  {ok:>6}")

    # Multi-object images check
    multi_object_count = sum(
        len(v) for k, v in class_images.items() if len(k.split("_")) >= 2
    )
    multi_pct = multi_object_count / total_images * 100 if total_images else 0
    multi_ok = "OK" if multi_pct >= 50.0 else "FAIL"

    print()
    print("=" * 60)
    print("REQUIREMENT CHECKS")
    print("=" * 60)
    print(f"  Images with 2-3 objects: {multi_object_count}/{total_images} ({multi_pct:.1f}%)  [{multi_ok}]")

    if class_violations:
        print(f"  Classes below 10% threshold: {', '.join(class_violations)}  [FAIL]")
    else:
        print("  All individual classes meet ≥10% threshold  [OK]")

    print()
    print("FORMAT VERIFICATION (all images converted to 128x128 RGB PNG):")
    # Spot-check by re-reading a few written files
    format_errors = 0
    for label_dir in OUTPUT_DIR.iterdir():
        for img_file in label_dir.iterdir():
            img = Image.open(img_file)
            if img.size != EXPECTED_SIZE or img.mode != EXPECTED_MODE:
                format_errors += 1
                issues.append(f"  Format error after conversion: {img_file}")
    if format_errors == 0:
        print("  All images are 128x128 RGB PNG  [OK]")
    else:
        print(f"  {format_errors} images failed format check  [FAIL]")

    if issues:
        print("\nWARNINGS / ISSUES:")
        for issue in issues:
            print(issue)

    print()
    print("PER-SOURCE BREAKDOWN:")
    for src, counts in source_stats.items():
        print(f"  {src}: {sum(counts.values())} images, {len(counts)} folders")

    print()
    print("Done.")


if __name__ == "__main__":
    main()
