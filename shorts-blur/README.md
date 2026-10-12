# 橫式影片批次轉 Shorts（模糊背景）

把資料夾裡的橫式影片（16:9）全部轉成 1080×1920 的直式影片：
中間放原本的畫面，上下用同一段影片模糊放大補滿，可直接上傳 YouTube Shorts。

## 準備
1. 安裝 Python 3
2. 安裝 ffmpeg（https://ffmpeg.org/download.html），確認命令列打 `ffmpeg` 有反應
   - Windows：`winget install ffmpeg`
   - macOS：`brew install ffmpeg`

## 使用
```bash
python make_shorts.py 影片資料夾
python make_shorts.py 影片資料夾 輸出資料夾
python make_shorts.py 影片資料夾 --blur 30   # 背景更模糊
```
沒指定輸出資料夾時，結果會放在 `影片資料夾/shorts/`，檔名為 `原檔名_shorts.mp4`。
支援 mp4、mov、mkv、avi、webm、m4v。

> Shorts 長度上限為 3 分鐘；超過的影片請先剪短。
