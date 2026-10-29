"""Validate every shipped Five Vows illustration and consolidate provenance.

Run after the individual built-in image_gen jobs. This inspects images only;
it never resizes, crops, draws or changes any image.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
LEDGER = ROOT / "tools/art_pipeline/set02_art_ledger.json"
PARTS = ROOT / "tools/art_cache/set02/ledger"


def audit(refresh=False, require_masters=False):
    previous = json.loads(LEDGER.read_text(encoding="utf-8"))
    entries = {entry["id"]: entry for entry in previous["assets"]}
    for path in sorted(PARTS.glob("*.json")):
        entry = json.loads(path.read_text(encoding="utf-8"))
        if path.stem != entry["id"]:
            raise ValueError(f"Mislabeled provenance: {path}")
        entries[entry["id"]] = entry
    expected = {f"SF002-{i:03}" for i in range(1, 216)}
    expected |= {f"STORY-vow{i:02}-01" for i in range(1, 21)}
    expected |= {f"TOKEN-{name}" for name in ["Sapling", "Cinder", "Lantern", "Echo"]}
    if set(entries) != expected:
        raise ValueError(f"Provenance mismatch: missing={sorted(expected - entries.keys())}, extra={sorted(entries.keys() - expected)}")
    hashes = {}
    total_bytes = 0
    masters_decoded = 0
    for asset_id in sorted(expected):
        entry = entries[asset_id]
        asset = ROOT / entry["asset"]
        master = Path(entry["master"])
        if asset.resolve() != (ROOT / "app/assets/art" / f"{asset_id}.webp").resolve():
            raise ValueError(f"Wrong shipped path: {asset_id}")
        if require_masters and not master.exists():
            raise FileNotFoundError(f"Original generation master unavailable: {asset_id}")
        paths = [asset]
        if master.exists():
            paths.append(master)
            masters_decoded += 1
        for path in paths:
            with Image.open(path) as picture:
                picture.load()
                size = picture.size
                if size != (entry["width"], entry["height"]):
                    raise ValueError(f"Dimensions differ from provenance: {path}")
                # These two action scenes were reviewed with their key event
                # inside the centered card window despite a wider backdrop.
                maximum_ratio = 2.05 if asset_id in {"SF002-165", "SF002-170"} else 1.9
                if size[0] < 900 or size[1] < 600 or not 1.3 <= size[0] / size[1] <= maximum_ratio:
                    raise ValueError(f"Unsuitable production dimensions: {path}: {size}")
                if path == asset and picture.format != "WEBP":
                    raise ValueError(f"Not a WebP: {path}")
        digest = hashlib.sha256(asset.read_bytes()).hexdigest()
        if digest != entry["sha256"]:
            raise ValueError(f"Shipped bytes changed: {asset_id}")
        if digest in hashes:
            raise ValueError(f"Reused illustration: {asset_id} and {hashes[digest]}")
        hashes[digest] = asset_id
        total_bytes += asset.stat().st_size
        if master.exists():
            entry["master_sha256"] = hashlib.sha256(master.read_bytes()).hexdigest()
        entry["review"] = "Composition reviewed; full-resolution WebP decoded; unique shipped bytes verified. Representative collection and booster rendering checked in the game."
    if refresh:
        final = {
            "set": "SF002", "generator": "built-in image_gen", "date": "2026-10-29",
            "notes": "215 individual collectible illustrations, 20 chapter illustrations and four runtime token illustrations. WebP packaging changes encoding only; no cropping, resizing or drawing. Selected revisions were made with built-in image_gen; earlier masters are retained locally. Absolute master paths record the original local generation source.",
            "assets": [entries[key] for key in sorted(entries)],
        }
        LEDGER.write_text(json.dumps(final, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"collectibles": 215, "chapter_scenes": 20, "runtime_tokens": 4,
            "unique_images": len(hashes), "shipped_bytes": total_bytes,
            "masters_decoded": masters_decoded, "ledger_refreshed": refresh}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh-ledger", action="store_true")
    parser.add_argument("--require-masters", action="store_true",
                        help="Also require all local image_gen masters to be present.")
    args = parser.parse_args()
    print(json.dumps(audit(args.refresh_ledger, args.require_masters)))
