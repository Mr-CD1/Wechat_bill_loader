"""生成应用图标 PNG（1024×1024）。"""

from pathlib import Path

from PIL import Image, ImageDraw

GREEN = (7, 193, 96, 255)
GREEN_DARK = (5, 160, 78, 255)
WHITE = (255, 255, 255, 255)


def main() -> None:
    size = 1024
    img = Image.new("RGBA", (size, size), GREEN)
    draw = ImageDraw.Draw(img)

    pad = 168
    inner = [pad, pad, size - pad, size - pad]
    draw.rounded_rectangle(inner, radius=128, fill=WHITE)

    # 装订线
    spine_x = pad + 72
    draw.rounded_rectangle(
        [pad + 24, pad + 40, spine_x, size - pad - 40],
        radius=24,
        fill=(240, 248, 244, 255),
    )

    line_left = spine_x + 48
    line_right = size - pad - 56
    for i in range(4):
        y = pad + 200 + i * 120
        draw.rounded_rectangle(
            [line_left, y, line_right, y + 16],
            radius=8,
            fill=GREEN_DARK if i == 0 else (180, 230, 200, 255),
        )

    # 记账圆点标记
    cx, cy = size - pad - 120, pad + 130
    r = 48
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GREEN)
    draw.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=WHITE)

    out_dir = Path(__file__).resolve().parents[1] / "assets" / "icon"
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / "app_icon.png"
    img.save(out, "PNG")
    print(f"已写入 {out}")


if __name__ == "__main__":
    main()
