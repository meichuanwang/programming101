# -*- coding: utf-8 -*-
"""
原創輕快喜劇風背景音樂 (程式合成，無版權問題)。

120 BPM、C 大調，和弦 C - Am - F - G 循環；
在「崩潰」那格停下音樂，改放「哇哇哇哇～」下滑長號音效，片尾再回到主旋律。
"""
import wave

import numpy as np

SR = 44100
BEAT = 0.5  # 120 BPM
BAR = BEAT * 4


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env(n, attack=0.005, decay=4.0):
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / attack)
    return a * np.exp(-decay * t)


def pluck(freq, dur, decay=5.0):
    """類似烏克麗麗的撥弦：幾個泛音 + 快速衰減。"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = sum(np.sin(2 * np.pi * freq * k * t) / k ** 1.6 for k in range(1, 6))
    return s * env(n, decay=decay)


def marimba(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-30 * t)
    return s * env(n, attack=0.002, decay=7.0)


def bass(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2 * t)
    return s * env(n, attack=0.01, decay=3.0)


def kick(dur=0.25):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 50 + 90 * np.exp(-30 * t)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-12 * t)


def hat(dur=0.05, rng=np.random.default_rng(1)):
    n = int(dur * SR)
    noise = rng.uniform(-1, 1, n)
    noise = np.diff(noise, prepend=0)  # 高通
    return noise * np.exp(-np.arange(n) / SR * 80)


def trombone(notes):
    """notes: [(midi, 秒數)]，鋸齒波 + 低通 + 顫音；最後一個音下滑。"""
    out = []
    for i, (m, dur) in enumerate(notes):
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = midi(m) * np.ones(n)
        if i == len(notes) - 1:
            f *= 2 ** (-1.2 * t / dur / 12 * 2)  # 尾音往下滑
            f *= 1 + 0.012 * np.sin(2 * np.pi * 6 * t) * np.minimum(1, t / 0.4)
        ph = np.cumsum(f) / SR
        saw = 2 * (ph % 1.0) - 1
        # 簡單一階低通讓音色變悶
        y = np.zeros(n)
        acc = 0.0
        alpha = 0.18
        for j in range(n):
            acc += alpha * (saw[j] - acc)
            y[j] = acc
        e = np.minimum(1, t / 0.04) * np.minimum(1, (dur - t) / 0.08)
        out.append(y * e)
    return np.concatenate(out)


CHORDS = [  # (bass, 和弦音)
    (36, [60, 64, 67]),  # C
    (33, [57, 60, 64]),  # Am
    (29, [57, 60, 65]),  # F
    (31, [59, 62, 67]),  # G
]
# 每小節 8 個八分音符，None 為休止
MELODY = [
    [72, None, 76, 79, None, 76, 74, None],
    [72, None, 69, None, 72, 74, 76, None],
    [77, None, 76, 74, None, 72, 69, None],
    [71, 74, None, 79, None, 77, 76, 74],
    [72, None, 76, 79, None, 81, 79, None],
    [76, None, 72, None, 69, 72, 76, None],
    [77, 77, 76, 74, None, 72, 74, None],
    [79, None, 74, None, 71, None, 72, None],
]


def add(buf, sig, at, gain):
    i = int(at * SR)
    j = min(len(buf), i + len(sig))
    if i < j:
        buf[i:j] += sig[: j - i] * gain


def loop_section(buf, start, end, bar_offset=0, melody_from_bar=1):
    bar = 0
    t = start
    while t < end - 1e-6:
        b, chord = CHORDS[(bar + bar_offset) % 4]
        for beat in range(4):
            bt = t + beat * BEAT
            if bt >= end:
                break
            add(buf, kick(), bt, 0.55 if beat in (0, 2) else 0.0)
            add(buf, bass(midi(b), BEAT * 0.9), bt, 0.35 if beat in (0, 2) else 0.2)
            # 反拍撥弦
            for k, m in enumerate(chord):
                add(buf, pluck(midi(m), 0.4), bt + BEAT / 2 + k * 0.008, 0.09)
            add(buf, hat(), bt + BEAT / 2, 0.12)
        if bar + bar_offset >= melody_from_bar:
            for k, m in enumerate(MELODY[(bar + bar_offset) % len(MELODY)]):
                at = t + k * BEAT / 2
                if m is not None and at < end:
                    add(buf, marimba(midi(m), 0.6), at, 0.22)
        bar += 1
        t += BAR


def render(path, total, break_at, resume_at):
    """total 秒長；break_at 停下主旋律放長號，resume_at 回到主旋律。"""
    buf = np.zeros(int(total * SR) + SR)
    loop_section(buf, 0.0, break_at)
    wah = trombone([(67, 0.55), (66, 0.55), (65, 0.55), (64, 2.0)])
    add(buf, wah, break_at + 0.15, 0.35)
    loop_section(buf, resume_at, total + BAR, bar_offset=4, melody_from_bar=0)
    buf = buf[: int(total * SR)]
    # 淡入淡出 + 正規化
    n = len(buf)
    fade_in, fade_out = int(0.4 * SR), int(2.0 * SR)
    buf[:fade_in] *= np.linspace(0, 1, fade_in)
    buf[-fade_out:] *= np.linspace(1, 0, fade_out)
    buf = np.tanh(buf * 1.2)
    buf *= 0.7 / max(1e-9, np.abs(buf).max())
    pcm = (buf * 32767).astype("<i2")
    stereo = np.repeat(pcm[:, None], 2, axis=1)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(stereo.tobytes())
