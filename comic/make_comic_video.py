# -*- coding: utf-8 -*-
"""
《陳美美的工地日常》EP.03 新人李不會 — 漫畫轉直式短影音 (1080x1920)

鏡頭依序推進到每一格，停留時間依對白長度而定，最後拉回整頁。
畫面下方有逐句字幕，另輸出 ep03_li_buhui.srt 供平台上傳。
背景音樂由 bgm.py 合成 (原創，無版權問題)。
需求: python3, pillow, numpy, ffmpeg
執行: python3 comic/make_comic_video.py
"""
import os
import subprocess
import tempfile

import bgm

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "ep03_li_buhui.png")
OUT = os.path.join(HERE, "ep03_li_buhui.mp4")
SRT = os.path.join(HERE, "ep03_li_buhui.srt")
W, H, FPS = 1080, 1920, 30
MOVE = 0.55  # 格與格之間的鏡頭移動秒數
FONT = "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"
SUB_TOP, SUB_H = 1500, 380  # 字幕區

# (x0, y0, x1, y1) 原圖座標, 最短停留秒數, [(說話者, 字幕)]
BOSS, MEI, LI, NARR = "老闆", "美美", "小李", ""
PANELS = [
    ((0, 0, 342, 392), 3.8, [(BOSS, "美美，明天有新人小李來工地報到喔。"), (MEI, "好啊，他會什麼？")]),
    ((345, 0, 670, 392), 2.6, [(BOSS, "他什麼都不會。"), (MEI, "……蛤？")]),
    ((673, 0, 1024, 392), 4.2, [(BOSS, "人家是理多惠，他是李不會。"), (MEI, "老闆，這不是諧音梗，這是工安預告。")]),
    ((0, 395, 467, 961), 4.8, [(LI, "主任好！我是李不會！"), (MEI, "……你自己也這樣自我介紹？"), (LI, "老闆說這樣比較好記。")]),
    ((472, 395, 761, 711), 2.6, [(MEI, "會看圖嗎？"), (LI, "會……轉。")]),
    ((764, 395, 1024, 711), 2.8, [(MEI, "那你還會什麼？"), (LI, "我什麼都不會。")]),
    ((472, 714, 761, 961), 2.2, [(MEI, "那你到底會什麼？")]),
    ((764, 714, 1024, 961), 2.6, [(LI, "我會說「好」。")]),
    ((0, 964, 315, 1536), 4.0, [(BOSS, "美美，下禮拜再來一個新人，叫王都會。"), (MEI, "太好了！他什麼都會？")]),
    ((319, 964, 640, 1536), 3.6, [(BOSS, "對，他什麼都會……就是不會來上班。"), (MEI, "……崩潰。")]),
    ((643, 964, 1024, 1536), 4.0, [(NARR, "工地主任的日常，就是一直在帶新人。"), (NARR, "你們公司有沒有一個「李不會」？")]),
]
SPEAKER_COLOR = {BOSS: (255, 214, 0), MEI: (255, 120, 170), LI: (80, 160, 255)}
CPS = 7.0  # 字幕閱讀速度 (字/秒)


def line_dur(text):
    return max(1.3, len(text) / CPS + 0.4)


FULL = (0, 0, 1024, 1536)
INTRO, OUTRO = 1.6, 2.6


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def lerp_rect(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(4))


def zoom(r, k):
    """以中心縮放矩形 (k<1 = 拉近)。"""
    cx, cy = (r[0] + r[2]) / 2, (r[1] + r[3]) / 2
    hw, hh = (r[2] - r[0]) / 2 * k, (r[3] - r[1]) / 2 * k
    return (cx - hw, cy - hh, cx + hw, cy + hh)


def build_timeline():
    """回傳 ([(起始秒, 結束秒, 起始矩形, 結束矩形)], 總秒數, 每格停留開始秒數)。"""
    tl, t, starts, subs = [], 0.0, [], []
    tl.append((t, t + INTRO, FULL, FULL)); t += INTRO
    prev = FULL
    for rect, hold, lines in PANELS:
        tl.append((t, t + MOVE, prev, rect)); t += MOVE
        starts.append(t)
        # 停留時間至少要夠讀完字幕；多出的時間按字數比例分給每句
        need = [line_dur(x) for _, x in lines]
        hold = max(hold, sum(need))
        st = t
        for (who, text), d in zip(lines, need):
            d = d * hold / sum(need)
            subs.append((st, st + d, who, text))
            st += d
        # 停留時緩慢推近 4%，畫面不會死板
        tl.append((t, t + hold, rect, zoom(rect, 0.96))); t += hold
        prev = zoom(rect, 0.96)
    tl.append((t, t + 0.9, prev, FULL)); t += 0.9
    tl.append((t, t + OUTRO, FULL, FULL)); t += OUTRO
    return tl, t, starts, subs


def wrap(d, text, font, width):
    lines, cur = [], ""
    for ch in text:
        if d.textlength(cur + ch, font=font) > width and cur:
            lines.append(cur)
            cur = ""
        cur += ch
    return lines + [cur]


def draw_subtitle(frame, who, text, alpha):
    """畫面下方的字幕條：說話者標籤 + 白字黑邊。"""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f_txt, f_who = ImageFont.truetype(FONT, 52), ImageFont.truetype(FONT, 38)
    rows = wrap(d, text, f_txt, W - 140)
    tag_h = 60 if who else 0
    box_h = tag_h + len(rows) * 70 + 40
    top = SUB_TOP + (SUB_H - box_h) // 2
    d.rounded_rectangle([40, top, W - 40, top + box_h], radius=24, fill=(0, 0, 0, 175))
    y = top + 20
    if who:
        col = SPEAKER_COLOR[who]
        tw = d.textlength(who, font=f_who)
        d.rounded_rectangle([(W - tw) / 2 - 18, y, (W + tw) / 2 + 18, y + 50], radius=14, fill=col + (255,))
        d.text(((W - tw) / 2, y + 4), who, font=f_who, fill=(20, 20, 20))
        y += tag_h
    for r in rows:
        d.text(((W - d.textlength(r, font=f_txt)) / 2, y), r, font=f_txt, fill=(255, 255, 255),
               stroke_width=3, stroke_fill=(0, 0, 0))
        y += 70
    if alpha < 1:
        layer.putalpha(layer.getchannel("A").point(lambda v: int(v * alpha)))
    frame.paste(layer, (0, 0), layer)


def srt_time(t):
    ms = int(round(t * 1000))
    return "%02d:%02d:%02d,%03d" % (ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000)


def write_srt(path, subs):
    with open(path, "w", encoding="utf-8") as f:
        for i, (a, b, who, text) in enumerate(subs, 1):
            f.write("%d\n%s --> %s\n%s\n\n" % (i, srt_time(a), srt_time(b), (who + "：" if who else "") + text))


def main():
    comic = Image.open(SRC).convert("RGB")
    # 背景：整頁漫畫放大、模糊、壓暗
    s = max(W / comic.width, H / comic.height)
    bg = comic.resize((int(comic.width * s), int(comic.height * s)), Image.LANCZOS)
    bg = bg.crop(((bg.width - W) // 2, (bg.height - H) // 2, (bg.width - W) // 2 + W, (bg.height - H) // 2 + H))
    bg = bg.filter(ImageFilter.GaussianBlur(28))
    bg = Image.blend(bg, Image.new("RGB", (W, H), (0, 0, 0)), 0.55)

    f_title = ImageFont.truetype(FONT, 46)
    f_sub = ImageFont.truetype(FONT, 34)
    header = ImageDraw.Draw(bg)
    t1, t2 = "《陳美美的工地日常》", "EP.03  新人李不會"
    header.text(((W - header.textlength(t1, font=f_title)) / 2, 70), t1, font=f_title, fill=(255, 214, 0))
    header.text(((W - header.textlength(t2, font=f_sub)) / 2, 135), t2, font=f_sub, fill=(255, 255, 255))

    box_w, box_h, box_top = 1000, 1270, 210  # 漫畫顯示區 (下方留給字幕)
    tl, total, starts, subs = build_timeline()
    write_srt(SRT, subs)
    tmp = tempfile.mkdtemp()
    music = os.path.join(tmp, "bgm.wav")
    # 「崩潰」那格 (第 10 格) 停下音樂放長號，片尾標題 (第 11 格) 前回到主旋律
    bgm.render(music, total, break_at=starts[9], resume_at=starts[10] - MOVE)

    cmd = [
        "ffmpeg", "-v", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H), "-r", str(FPS), "-i", "-",
        "-i", music,
        "-map", "0:v", "-map", "1:a", "-shortest",
        "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", OUT,
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    seg = 0
    for n in range(int(total * FPS)):
        t = n / FPS
        while seg < len(tl) - 1 and t >= tl[seg][1]:
            seg += 1
        t0, t1_, a, b = tl[seg]
        k = (t - t0) / (t1_ - t0)
        # 移動段用 ease，停留段線性慢推
        r = lerp_rect(a, b, ease(k) if a != b and (t1_ - t0) <= 1.0 else k)
        crop = comic.crop(tuple(int(round(v)) for v in r))
        sc = min(box_w / crop.width, box_h / crop.height)
        cw, ch = int(crop.width * sc), int(crop.height * sc)
        crop = crop.resize((cw, ch), Image.LANCZOS)
        frame = bg.copy()
        x, y = (W - cw) // 2, box_top + (box_h - ch) // 2
        ImageDraw.Draw(frame).rectangle([x - 6, y - 6, x + cw + 5, y + ch + 5], fill=(255, 255, 255))
        frame.paste(crop, (x, y))
        for a, b, who, text in subs:
            if a <= t < b:
                draw_subtitle(frame, who, text, min(1.0, (t - a) / 0.12, (b - t) / 0.12))
        # 淡入淡出
        fade = min(1.0, t / 0.5, (total - t) / 0.6)
        if fade < 1:
            frame = Image.blend(Image.new("RGB", (W, H)), frame, max(0.0, fade))
        proc.stdin.write(frame.tobytes())
    proc.stdin.close()
    if proc.wait():
        raise SystemExit("ffmpeg failed")
    print("wrote %s (%.1f s)" % (OUT, total))


if __name__ == "__main__":
    main()
