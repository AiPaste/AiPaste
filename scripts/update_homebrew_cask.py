#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 4:
        print("Usage: update_homebrew_cask.py <cask-path> <version> <sha256>", file=sys.stderr)
        return 1

    cask_path = Path(sys.argv[1])
    version = sys.argv[2]
    sha256 = sys.argv[3]

    if not cask_path.exists():
        print(f"Missing cask file: {cask_path}", file=sys.stderr)
        return 1

    content = cask_path.read_text()
    content = re.sub(r'version\s+"[^"]+"', f'version "{version}"', content, count=1)
    content = re.sub(r'sha256\s+(:no_check|"[^"]+")', f'sha256 "{sha256}"', content, count=1)
    cask_path.write_text(content)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
