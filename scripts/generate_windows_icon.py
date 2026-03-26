from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("用法: python scripts/generate_windows_icon.py <source_image> <output_ico>")
        return 1

    source = Path(sys.argv[1])
    output = Path(sys.argv[2])

    if not source.exists():
        print(f"未找到图标源文件: {source}")
        return 1

    try:
        from PIL import Image
    except ModuleNotFoundError:
        print("缺少 Pillow，请先安装: python -m pip install pillow")
        return 1

    output.parent.mkdir(parents=True, exist_ok=True)

    with Image.open(source) as img:
        img = img.convert("RGBA")
        sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        img.save(output, format="ICO", sizes=sizes)

    print(f"已生成 Windows 图标: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())