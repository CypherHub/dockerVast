#!/usr/bin/env python3
"""Patch hy3dshape pipelines so flat safetensors keys group into ckpt['model'], ckpt['vae'], etc."""
from __future__ import annotations

import sys
from pathlib import Path


def patch_file(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    anchor = (
        "        ckpt = load_torch_file(ckpt_path)\n"
        "        # load model\n"
        "        model = instantiate_from_config(config['model'])"
    )
    insert = (
        "        ckpt = load_torch_file(ckpt_path)\n"
        "        if isinstance(ckpt, dict) and 'model' not in ckpt:\n"
        "            _buckets = {}\n"
        "            for _k, _v in ckpt.items():\n"
        "                if not isinstance(_k, str) or '.' not in _k:\n"
        "                    continue\n"
        "                _h, _t = _k.split('.', 1)\n"
        "                _buckets.setdefault(_h, {})[_t] = _v\n"
        "            ckpt = _buckets\n"
        "        # load model\n"
        "        model = instantiate_from_config(config['model'])"
    )
    if anchor not in text:
        raise SystemExit(f"patch_hy3dshape_pipelines: anchor not found in {path}")
    path.write_text(text.replace(anchor, insert, 1), encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: patch_hy3dshape_pipelines.py <path/to/pipelines.py>", file=sys.stderr)
        sys.exit(2)
    patch_file(Path(sys.argv[1]))


if __name__ == "__main__":
    main()
