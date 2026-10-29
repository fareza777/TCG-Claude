"""Package image_gen masters as shipped WebP assets without cropping or resizing."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

def package(source: Path, asset_id: str, prompt: str, reference: str, kind: str):
    if not asset_id.startswith(("SF002-", "STORY-vow", "TOKEN-")) or any(ch not in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-" for ch in asset_id):
        raise ValueError("Invalid expansion asset id")
    destination = ROOT / "app/assets/art" / (asset_id + ".webp")
    if destination.exists():
        raise FileExistsError("Refusing to replace existing art: " + str(destination))
    with Image.open(source) as master:
        master.load()
        width, height = master.size
        if width < 900 or height < 600:
            raise ValueError("Generated master is below production resolution")
        if master.mode != "RGB":
            master = master.convert("RGB")
        master.save(destination, "WEBP", quality=88, method=6)
    with Image.open(destination) as shipped:
        shipped.load()
        if shipped.size != (width, height):
            raise ValueError("Packaging changed image dimensions")
    entry = {
        "id": asset_id, "kind": kind, "prompt": prompt, "reference": reference,
        "master": str(source), "asset": str(destination.relative_to(ROOT)).replace("\\", "/"),
        "width": width, "height": height,
        "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
        "review": "generated; composition inspected in batch; final in-game review pending"
    }
    entry_dir = ROOT / "tools/art_cache/set02/ledger"
    entry_dir.mkdir(parents=True, exist_ok=True)
    temp = entry_dir / (asset_id + ".json.tmp")
    temp.write_text(json.dumps(entry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temp.replace(entry_dir / (asset_id + ".json"))
    return {"id": asset_id, "width": width, "height": height, "bytes": destination.stat().st_size}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--id", required=True)
    parser.add_argument("--metadata", required=True, type=Path)
    args = parser.parse_args()
    meta = json.loads(args.metadata.read_text(encoding="utf-8"))
    print(json.dumps(package(args.source, args.id, meta["prompt"], meta["reference"], meta["kind"])))
