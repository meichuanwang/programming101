# -*- coding: utf-8 -*-
"""產生測試用的 DXF 平面圖 (單位 mm)：6m x 4m 的房間，中間一道隔間牆，一扇門、兩扇窗、給水管與排水管。

    python make_sample_dxf.py            -> sample_single.dxf (單線牆)
    python make_sample_dxf.py --double   -> sample_double.dxf (雙線牆, 牆厚 200)
"""
import sys

import ezdxf

double = "--double" in sys.argv
doc = ezdxf.new(units=4)  # 4 = mm
msp = doc.modelspace()
for name in ("WALL", "DOOR", "WINDOW", "FLOOR"):
    doc.layers.add(name)

W, H, T = 6000, 4000, 200
if double:
    # 外牆：外框 + 內框；隔間牆：兩條平行線
    msp.add_lwpolyline([(-T / 2, -T / 2), (W + T / 2, -T / 2), (W + T / 2, H + T / 2), (-T / 2, H + T / 2)],
                       close=True, dxfattribs={"layer": "WALL"})
    msp.add_lwpolyline([(T / 2, T / 2), (W - T / 2, T / 2), (W - T / 2, H - T / 2), (T / 2, H - T / 2)],
                       close=True, dxfattribs={"layer": "WALL"})
    msp.add_line((3500 - T / 2, T / 2), (3500 - T / 2, H - T / 2), dxfattribs={"layer": "WALL"})
    msp.add_line((3500 + T / 2, T / 2), (3500 + T / 2, H - T / 2), dxfattribs={"layer": "WALL"})
else:
    msp.add_lwpolyline([(0, 0), (W, 0), (W, H), (0, H)], close=True, dxfattribs={"layer": "WALL"})
    msp.add_line((3500, 0), (3500, H), dxfattribs={"layer": "WALL"})

msp.add_lwpolyline([(0, 0), (W, 0), (W, H), (0, H)], close=True, dxfattribs={"layer": "FLOOR"})

door = doc.blocks.new("DOOR_900")
door.add_line((0, 0), (900, 0))
win = doc.blocks.new("WIN_1500")
win.add_line((0, 0), (1500, 0))
msp.add_blockref("DOOR_900", (1500, 0), dxfattribs={"layer": "DOOR"})
msp.add_blockref("WIN_1500", (W, 2000), dxfattribs={"layer": "WINDOW", "rotation": 90})
msp.add_blockref("WIN_1500", (1800, H), dxfattribs={"layer": "WINDOW"})

# 給水管 (管徑 25mm)：沿著牆內側走一個 L 型；排水管 (管徑 75mm) 一段直管
doc.layers.add("PIPE-給水-25")
doc.layers.add("PIPE-排水-75")
msp.add_lwpolyline([(500, 3500), (3000, 3500), (3000, 800)], dxfattribs={"layer": "PIPE-給水-25"})
msp.add_line((4000, 600), (5500, 600), dxfattribs={"layer": "PIPE-排水-75"})

out = "sample_double.dxf" if double else "sample_single.dxf"
doc.saveas(out)
print("已產生", out)
