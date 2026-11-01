"""
用 Python 自動畫出「給排水（污水 / 廢水）管線平面圖」
================================================

輸出：
  - plumbing_plan.dxf  ：可直接用 AutoCAD / DWG TrueView / LibreCAD 開啟（有分圖層）
  - plumbing_plan.png  ：深色底預覽圖（類似 AutoCAD 模型空間的樣子）

需要套件：
  pip install ezdxf matplotlib

管線代號說明（常見的 MEP 標註）：
  SP = Soil Pipe      污水管（馬桶）
  WP = Waste Pipe     廢水管（洗手台、地排）
  KP = Kitchen Pipe   廚房排水管
  VP = Vent Pipe      通氣管
  DN100 = 管徑 100 mm，1% = 坡度，CL = 管中心高程
"""

import math

import ezdxf
import ezdxf.zoom
from ezdxf.addons.drawing import matplotlib as dxf_mpl

# ---------------------------------------------------------------------------
# 1. 管線設定：名稱、圖層、顏色（AutoCAD ACI 色號）、管徑(mm)
# ---------------------------------------------------------------------------
PIPES = [
    # 名稱       圖層            顏色  外徑
    ("SP-DN100", "P-SP-SOIL",    6,   110),   # 洋紅：污水
    ("WP-DN100", "P-WP-WASTE",   4,   110),   # 青色：廢水
    ("KP-DN65",  "P-KP-KITCHEN", 3,    75),   # 綠色：廚房排水
    ("VP-DN65",  "P-VP-VENT",   40,    75),   # 橘色：通氣
]

SPACING = 260        # 管與管的中心間距 (mm)
CHAMFER = 450        # 45° 彎頭的斜邊長度 (mm)


# ---------------------------------------------------------------------------
# 2. 幾何工具
# ---------------------------------------------------------------------------
def chamfer_route(points, c):
    """把直角轉折改成 45° 彎頭（在每個轉角前後各退 c 的距離）。"""
    out = [points[0]]
    for i in range(1, len(points) - 1):
        p0, p1, p2 = points[i - 1], points[i], points[i + 1]
        d1 = _unit(p1, p0)
        d2 = _unit(p1, p2)
        out.append((p1[0] - d1[0] * c, p1[1] - d1[1] * c))
        out.append((p1[0] - d2[0] * c, p1[1] - d2[1] * c))
    out.append(points[-1])
    return out


def offset_polyline(points, dist):
    """把中心線往左（dist>0）或右（dist<0）平移，轉角用斜接 (miter)。"""
    n = len(points)
    normals = []
    for i in range(n - 1):
        dx, dy = _unit(points[i + 1], points[i])
        normals.append((-dy, dx))
    out = []
    for i in range(n):
        if i == 0:
            nx, ny = normals[0]
            scale = 1
        elif i == n - 1:
            nx, ny = normals[-1]
            scale = 1
        else:
            a, b = normals[i - 1], normals[i]
            nx, ny = a[0] + b[0], a[1] + b[1]
            length = math.hypot(nx, ny)
            nx, ny = nx / length, ny / length
            scale = 1 / (nx * a[0] + ny * a[1])   # 斜接長度修正
        out.append((points[i][0] + nx * dist * scale,
                    points[i][1] + ny * dist * scale))
    return out


def _unit(a, b):
    """從 b 指向 a 的單位向量。"""
    dx, dy = a[0] - b[0], a[1] - b[1]
    length = math.hypot(dx, dy)
    return dx / length, dy / length


# ---------------------------------------------------------------------------
# 3. 繪圖
# ---------------------------------------------------------------------------
def setup_layers(doc):
    layers = doc.layers
    for _, layer, color, _ in PIPES:
        layers.add(layer, color=color)
    layers.add("A-WALL",  color=8)     # 牆：灰
    layers.add("A-HATCH", color=8)
    layers.add("S-GRID",  color=7, linetype="DASHDOT")   # 柱線：白色點鏈線
    layers.add("P-TEXT",  color=7)
    layers.add("P-LEADER", color=1)    # 引線：紅
    layers.add("P-DIM",   color=1)


def draw_pipe(msp, route, layer, od):
    """雙線管：中心線兩側各畫一條管壁線 + 彎頭兩端的接頭短線。"""
    r = od / 2
    left = offset_polyline(route, r)
    right = offset_polyline(route, -r)
    msp.add_lwpolyline(left, dxfattribs={"layer": layer})
    msp.add_lwpolyline(right, dxfattribs={"layer": layer})

    # 在每個彎頭的起點/終點畫接頭（法蘭）短線，看起來像管件
    for i in range(1, len(route) - 1):
        lx, ly = left[i]
        rx, ry = right[i]
        mx, my = (lx - rx) * 0.25, (ly - ry) * 0.25   # 稍微凸出管壁
        msp.add_line((lx + mx, ly + my), (rx - mx, ry - my),
                     dxfattribs={"layer": layer})


def draw_pipes(msp):
    n = len(PIPES)
    for i, (_, layer, _, od) in enumerate(PIPES):
        # 巢狀 U 型路徑：從上方下來 → 水平走 → 右側上去
        x_left = 1000 + i * SPACING
        y_bottom = 1000 + i * SPACING
        x_right = 11000 - i * SPACING
        corners = [
            (x_left, 7000),
            (x_left, y_bottom),
            (x_right, y_bottom),
            (x_right, 4300 + (n - i) * 120),
        ]
        route = chamfer_route(corners, CHAMFER)
        draw_pipe(msp, route, layer, od)

    # 一支從上方接進來的分支管 + 存水彎 (P-trap 示意)
    branch = chamfer_route([(3000, 7000), (3000, 3300), (2200, 2500),
                            (2200, 1000 + 2 * SPACING)], 300)
    draw_pipe(msp, branch, "P-KP-KITCHEN", 75)


def draw_walls(msp):
    """右上角的牆 + 斜線填充（ANSI31）。"""
    walls = [
        [(8200, 4200), (12500, 4200), (12500, 4400), (8400, 4400),
         (8400, 7200), (8200, 7200)],
        [(4000, 300), (12500, 300), (12500, 500), (4000, 500)],
    ]
    for pts in walls:
        msp.add_lwpolyline(pts, close=True, dxfattribs={"layer": "A-WALL"})
        hatch = msp.add_hatch(color=8, dxfattribs={"layer": "A-HATCH"})
        hatch.set_pattern_fill("ANSI31", scale=8)
        hatch.paths.add_polyline_path(pts, is_closed=True)

    # 地板落水頭（U 形小圖示）
    for k in range(6):
        x = 9800 + k * 280
        msp.add_arc((x, 4100), radius=110, start_angle=180, end_angle=360,
                    dxfattribs={"layer": "A-WALL"})


def draw_grid(msp):
    msp.add_line((-500, 5200), (8200, 5200),
                 dxfattribs={"layer": "S-GRID", "ltscale": 40})


def draw_labels(msp):
    """標註文字 + 紅色引線箭頭。"""
    labels = [
        ("KP-DN65,1%,CL8.5",  (3600, 6500), (1260 + 2 * SPACING, 6500)),
        ("SP-DN100,1%,CL8.5", (3600, 5800), (1000, 5800)),
        ("WP-DN100,1%,CL8.5", (3600, 4800), (1000 + SPACING, 4800)),
        ("SP-DN100,BOP=2850", (9200, 1500), (10900, 1060)),
    ]
    for text, text_pos, arrow_to in labels:
        msp.add_text(text, height=220, dxfattribs={"layer": "P-TEXT"}) \
           .set_placement(text_pos)
        # LEADER 的箭頭畫在第一個點，所以先放箭頭位置，再接到文字下方
        msp.add_leader(
            [arrow_to, (text_pos[0] + 3200, text_pos[1] - 60)],
            dxfattribs={"layer": "P-LEADER"},
            override={"dimasz": 200, "dimclrd": 1},
        )

    # 尺寸標註（像圖中的 3794）
    dim = msp.add_linear_dim(
        base=(0, 3600), p1=(1000, 3000), p2=(4794, 3000),
        dimstyle="EZDXF", override={"dimtxt": 380, "dimlfac": 1, "dimdec": 0, "dimasz": 160,
                                     "dimclrt": 4, "dimclrd": 1},
        dxfattribs={"layer": "P-DIM"},
    )
    dim.render()


def main():
    doc = ezdxf.new("R2018", setup=True)   # setup=True 會載入線型與文字樣式
    setup_layers(doc)
    msp = doc.modelspace()

    draw_grid(msp)
    draw_walls(msp)
    draw_pipes(msp)
    draw_labels(msp)

    # 寫入圖面範圍並把視窗縮放到全圖，CAD 一打開就看得到整張圖
    doc.header["$INSUNITS"] = 4          # 單位：公釐 (mm)
    ezdxf.zoom.extents(msp)
    doc.saveas("plumbing_plan.dxf")
    dxf_mpl.qsave(msp, "plumbing_plan.png", bg="#212830", dpi=200, size_inches=(16, 10))
    print("已輸出 plumbing_plan.dxf 與 plumbing_plan.png")


if __name__ == "__main__":
    main()
