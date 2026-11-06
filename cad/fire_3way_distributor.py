"""產生「消防電3路分配器 122x158x24mm」CAD 圖塊 (DXF, 單位 mm)。

圖塊名稱: FIRE_3WAY_DIST_122x158x24
  - 正視圖: 122(寬) x 158(高), 插入基點 = 正視圖左下角
  - 側視圖: 24(厚) x 158(高), 置於正視圖右側 40mm
執行: python3 fire_3way_distributor.py  ->  fire_3way_distributor.dxf
"""
import ezdxf
from ezdxf import units
from ezdxf.enums import TextEntityAlignment

W, H, D = 122.0, 158.0, 24.0
R = 4.0             # 外殼圓角
GAP = 40.0          # 正視圖與側視圖間距
BLOCK = "FIRE_3WAY_DIST_122x158x24"

doc = ezdxf.new("R2010", setup=True)
doc.units = units.MM
doc.header["$INSUNITS"] = 4
doc.styles.add("CHT", font="msjh.ttc")  # 微軟正黑體; 缺字型時 CAD 會自動替代

for name, color, lt in [("FA-OUTLINE", 1, "CONTINUOUS"), ("FA-DETAIL", 3, "CONTINUOUS"),
                        ("FA-CENTER", 6, "CENTER"), ("FA-TEXT", 7, "CONTINUOUS"),
                        ("FA-DIM", 4, "CONTINUOUS")]:
    doc.layers.add(name, color=color, linetype=lt)

blk = doc.blocks.new(BLOCK, base_point=(0, 0))


def rrect(x, y, w, h, r, layer):
    """圓角矩形 (bulge 0.4142 = 90° 圓弧)。"""
    b = 0.41421356
    pts = [(x + r, y, 0, 0, 0), (x + w - r, y, 0, 0, b), (x + w, y + r, 0, 0, 0),
           (x + w, y + h - r, 0, 0, b), (x + w - r, y + h, 0, 0, 0),
           (x + r, y + h, 0, 0, b), (x, y + h - r, 0, 0, 0), (x, y + r, 0, 0, b)]
    blk.add_lwpolyline(pts, format="xyseb", close=True, dxfattribs={"layer": layer})


def rect(x, y, w, h, layer):
    blk.add_lwpolyline([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], close=True,
                       dxfattribs={"layer": layer})


def text(s, x, y, h, layer="FA-TEXT"):
    blk.add_text(s, height=h, dxfattribs={"layer": layer, "style": "CHT"}).set_placement(
        (x, y), align=TextEntityAlignment.MIDDLE_CENTER)


def cross(x, y, s, layer="FA-CENTER"):
    blk.add_line((x - s, y), (x + s, y), dxfattribs={"layer": layer})
    blk.add_line((x, y - s), (x, y + s), dxfattribs={"layer": layer})


# ---------------- 正視圖 ----------------
rrect(0, 0, W, H, R, "FA-OUTLINE")          # 外殼
rrect(3, 3, W - 6, H - 6, R - 1, "FA-DETAIL")  # 上蓋邊框

# 四角固定孔 Ø5
for hx, hy in [(8, 8), (W - 8, 8), (8, H - 8), (W - 8, H - 8)]:
    blk.add_circle((hx, hy), 2.5, dxfattribs={"layer": "FA-DETAIL"})
    cross(hx, hy, 4)

# 銘牌
rect(16, H - 40, W - 32, 26, "FA-DETAIL")
text("消防電3路分配器", W / 2, H - 22, 6)
text("FIRE ALARM 3-WAY DISTRIBUTOR", W / 2, H - 33, 3.2)

# 端子台: 1 進 3 出
TB_Y, TB_H = 58, 24
rect(14, TB_Y, W - 28, TB_H, "FA-DETAIL")
labels = ["IN", "OUT1", "OUT2", "OUT3"]
pitch = (W - 28) / 4
for i, lb in enumerate(labels):
    cx = 14 + pitch * (i + 0.5)
    if i:
        blk.add_line((14 + pitch * i, TB_Y), (14 + pitch * i, TB_Y + TB_H),
                     dxfattribs={"layer": "FA-DETAIL"})
    for dx in (-5, 5):  # 每路 +/- 兩個端子螺絲
        blk.add_circle((cx + dx, TB_Y + 14), 3, dxfattribs={"layer": "FA-DETAIL"})
        blk.add_line((cx + dx - 2, TB_Y + 14), (cx + dx + 2, TB_Y + 14),
                     dxfattribs={"layer": "FA-DETAIL"})
    text("+   -", cx, TB_Y + 5, 2.5)
    text(lb, cx, TB_Y + TB_H + 4, 3)

# 頂部 1 個進線孔、底部 3 個出線孔 (Ø16 防水接頭示意)
GL = 8.0
blk.add_circle((W / 2, H - 50), GL, dxfattribs={"layer": "FA-DETAIL"})
cross(W / 2, H - 50, GL + 2)
text("IN", W / 2 + GL + 7, H - 50, 3)
for i in range(3):
    gx = W / 4 * (i + 1)
    blk.add_circle((gx, 30), GL, dxfattribs={"layer": "FA-DETAIL"})
    cross(gx, 30, GL + 2)
    text(f"OUT{i + 1}", gx, 15, 3)

# ---------------- 側視圖 ----------------
SX = W + GAP
rect(SX, 0, D, H, "FA-OUTLINE")
blk.add_line((SX + D - 3, 0), (SX + D - 3, H), dxfattribs={"layer": "FA-DETAIL"})  # 蓋板分模線
# 防水接頭凸出示意 (頂 1 / 底 1 可見)
for y0, y1 in [(H, H + 10), (0, -10)]:
    rect(SX + D / 2 - 7, min(y0, y1), 14, 10, "FA-DETAIL")
text("側視", SX + D / 2, H + 18, 4)
text("正視", W / 2, H + 18, 4)

# ---------------- 模型空間: 插入圖塊 + 尺寸 ----------------
msp = doc.modelspace()
msp.add_blockref(BLOCK, (0, 0), dxfattribs={"layer": "0"})
dim_attr = {"layer": "FA-DIM"}
ov = {"dimlfac": 1, "dimtxt": 3.5, "dimasz": 3, "dimexo": 1.5, "dimdec": 0}
msp.add_linear_dim(base=(0, -22), p1=(0, 0), p2=(W, 0), override=ov, dxfattribs=dim_attr).render()
msp.add_linear_dim(base=(-15, 0), p1=(0, 0), p2=(0, H), angle=90, override=ov,
                   dxfattribs=dim_attr).render()
msp.add_linear_dim(base=(0, -22), p1=(SX, 0), p2=(SX + D, 0), override=ov,
                   dxfattribs=dim_attr).render()

doc.saveas(__file__.replace(".py", ".dxf"))
print("saved", BLOCK)
