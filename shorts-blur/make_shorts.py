#!/usr/bin/env python3
"""把資料夾裡的橫式影片批次轉成「模糊背景」的直式 Shorts（1080x1920）。

用法：
    python make_shorts.py 輸入資料夾 [輸出資料夾] [--blur 20]

需要先安裝 ffmpeg，並確認在命令列打 ffmpeg 找得到。
"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

VIDEO_EXTS = {".mp4", ".mov", ".mkv", ".avi", ".webm", ".m4v"}
WIDTH, HEIGHT = 1080, 1920


def build_filter(blur):
    return (
        f"[0:v]scale={WIDTH}:{HEIGHT}:force_original_aspect_ratio=increase,"
        f"crop={WIDTH}:{HEIGHT},boxblur={blur}:5[bg];"
        f"[0:v]scale={WIDTH}:-2[fg];"
        f"[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1[v]"
    )


def convert(src, dst, blur):
    cmd = [
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(src),
        "-filter_complex", build_filter(blur),
        "-map", "[v]", "-map", "0:a?",
        "-c:v", "libx264", "-preset", "medium", "-crf", "20",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k",
        "-movflags", "+faststart",
        str(dst),
    ]
    return subprocess.run(cmd).returncode == 0


def main():
    parser = argparse.ArgumentParser(description="橫式影片批次轉成模糊背景直式 Shorts")
    parser.add_argument("input_dir", help="放橫式影片的資料夾")
    parser.add_argument("output_dir", nargs="?", help="輸出資料夾（預設：輸入資料夾/shorts）")
    parser.add_argument("--blur", type=int, default=20, help="背景模糊程度，數字越大越模糊（預設 20）")
    args = parser.parse_args()

    if shutil.which("ffmpeg") is None:
        sys.exit("找不到 ffmpeg，請先安裝：https://ffmpeg.org/download.html")

    in_dir = Path(args.input_dir)
    if not in_dir.is_dir():
        sys.exit(f"找不到資料夾：{in_dir}")
    out_dir = Path(args.output_dir) if args.output_dir else in_dir / "shorts"
    out_dir.mkdir(parents=True, exist_ok=True)

    videos = sorted(p for p in in_dir.iterdir()
                    if p.is_file() and p.suffix.lower() in VIDEO_EXTS)
    if not videos:
        sys.exit(f"{in_dir} 裡沒有影片檔")

    ok = 0
    for i, src in enumerate(videos, 1):
        dst = out_dir / f"{src.stem}_shorts.mp4"
        print(f"[{i}/{len(videos)}] {src.name} -> {dst.name}")
        if convert(src, dst, args.blur):
            ok += 1
        else:
            print(f"  失敗：{src.name}")

    print(f"完成 {ok}/{len(videos)} 支，輸出在 {out_dir}")


if __name__ == "__main__":
    main()
