# -*- coding: utf-8 -*-
"""
2D 平面圖 (DXF) -> 建模資料 (JSON)

讀取 AutoCAD 匯出的 DXF 平面圖，依圖層抓出：
  - 牆 (WALL 圖層)：單線(中心線) 或 雙線(牆的兩側邊線) 皆可
  - 門 (DOOR 圖層)：圖塊插入點 (INSERT)
  - 窗 (WINDOW 圖層)：圖塊插入點 (INSERT)
  - 樓板 (FLOOR 圖層)：封閉的聚合線 (LWPOLYLINE)
輸出成 JSON (單位：公尺)，給 revit_build_from_json.py 在 Revit 裡產生 3D 模型。

用法:
    pip install ezdxf
    python dxf_to_json.py plan.dxf plan.json
    python dxf_to_json.py plan.dxf plan.json --double-line --unit mm
"""
import argparse
import json
import math

import ezdxf

# DXF $INSUNITS 代碼 -> 換算成公尺的倍率
INSUNITS_TO_M = {1: 0.0254, 2: 0.3048, 4: 0.001, 5: 0.01, 6: 1.0}
UNIT_TO_M = {"mm": 0.001, "cm": 0.01, "m": 1.0, "in": 0.0254, "ft": 0.3048}


# ---------------------------------------------------------------- 幾何小工具
def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1]


def cross(a, b):
    return a[0] * b[1] - a[1] * b[0]


def length(a):
    return math.hypot(a[0], a[1])


def seg_len(s):
    return length(sub(s[1], s[0]))


# ---------------------------------------------------------------- 讀取 DXF
def layer_match(entity, names):
    return entity.dxf.layer.upper() in names


def collect_segments(msp, layers):
    """把指定圖層上的 LINE / LWPOLYLINE / POLYLINE 拆成線段 [(p1, p2), ...]"""
    segs = []
    for e in msp:
        if not layer_match(e, layers):
            continue
        t = e.dxftype()
        if t == "LINE":
            segs.append(((e.dxf.start.x, e.dxf.start.y), (e.dxf.end.x, e.dxf.end.y)))
        elif t in ("LWPOLYLINE", "POLYLINE"):
            pts = [(p[0], p[1]) for p in (e.get_points("xy") if t == "LWPOLYLINE" else e.points())]
            if e.is_closed and len(pts) > 2:
                pts.append(pts[0])
            segs.extend(zip(pts[:-1], pts[1:]))
    return [s for s in segs if seg_len(s) > 1e-9]


def collect_inserts(msp, layers):
    """抓指定圖層上的圖塊 (門/窗)，回傳插入點、旋轉角與圖塊名稱"""
    result = []
    for e in msp.query("INSERT"):
        if layer_match(e, layers):
            result.append({
                "x": e.dxf.insert.x,
                "y": e.dxf.insert.y,
                "rotation": e.dxf.rotation,
                "block": e.dxf.name,
            })
    return result


def collect_floors(msp, layers):
    """抓封閉聚合線當作樓板邊界"""
    floors = []
    for e in msp.query("LWPOLYLINE"):
        if layer_match(e, layers) and e.is_closed:
            pts = [(p[0], p[1]) for p in e.get_points("xy")]
            if len(pts) >= 3:
                floors.append(pts)
    return floors


# ---------------------------------------------------------------- 雙線牆 -> 中心線
def double_lines_to_centerlines(segs, min_t, max_t, angle_tol_deg=1.0):
    """
    台灣常見的平面圖牆是畫成兩條平行線。
    這裡找出「互相平行、距離介於 min_t~max_t、投影有重疊」的線段配對，
    取兩線中間當牆中心線，距離當牆厚。
    """
    walls = []
    used = set()
    sin_tol = math.sin(math.radians(angle_tol_deg))
    # 長的線先配，比較不會被短線搶走
    order = sorted(range(len(segs)), key=lambda i: -seg_len(segs[i]))
    for i in order:
        if i in used:
            continue
        a1, a2 = segs[i]
        d = sub(a2, a1)
        la = length(d)
        u = (d[0] / la, d[1] / la)
        best = None
        for j in order:
            if j == i or j in used:
                continue
            b1, b2 = segs[j]
            db = sub(b2, b1)
            lb = length(db)
            if abs(cross(u, db)) / lb > sin_tol:
                continue  # 不平行
            dist = abs(cross(u, sub(b1, a1)))
            if not (min_t <= dist <= max_t):
                continue
            # 把 b 投影到 a 的方向上，算重疊區間
            t1, t2 = sorted((dot(sub(b1, a1), u), dot(sub(b2, a1), u)))
            lo, hi = max(0.0, t1), min(la, t2)
            overlap = hi - lo
            if overlap <= max_t:  # 重疊太短，多半是門窗旁的小線段
                continue
            if best is None or overlap > best[0]:
                best = (overlap, j, dist, lo, hi, b1)
        if best is None:
            continue
        _, j, dist, lo, hi, b1 = best
        used.update((i, j))
        # 法向量指向 b 那條線，中心線往那邊平移 dist/2
        n = (-u[1], u[0])
        if dot(sub(b1, a1), n) < 0:
            n = (-n[0], -n[1])
        off = dist / 2.0
        p1 = (a1[0] + u[0] * lo + n[0] * off, a1[1] + u[1] * lo + n[1] * off)
        p2 = (a1[0] + u[0] * hi + n[0] * off, a1[1] + u[1] * hi + n[1] * off)
        walls.append({"start": p1, "end": p2, "thickness": dist})
    return snap_corners(walls, max_t)


def snap_corners(walls, tol):
    """
    雙線配對出的中心線在轉角會少半個牆厚 (L 型、T 型接頭有缺口)，
    把端點延伸到附近另一道牆中心線的交點，Revit 才會自動接合。
    """
    for w in walls:
        for key in ("start", "end"):
            p = w[key]
            best = None
            for o in walls:
                if o is w:
                    continue
                a, b = w["start"], w["end"]
                c, d = o["start"], o["end"]
                r, s = sub(b, a), sub(d, c)
                den = cross(r, s)
                if abs(den) < 1e-9 * length(r) * length(s):
                    continue  # 平行
                t = cross(sub(c, a), s) / den
                x = (a[0] + r[0] * t, a[1] + r[1] * t)
                dist = length(sub(x, p))
                # 交點要靠近端點，而且落在另一道牆 (含容許延伸) 上
                u = dot(sub(x, c), s) / length(s)
                if dist <= tol and -tol <= u <= length(s) + tol:
                    if best is None or dist < best[0]:
                        best = (dist, x)
            if best is not None:
                w[key] = best[1]
    return walls


# ---------------------------------------------------------------- 主流程
def convert(path, args):
    doc = ezdxf.readfile(path)
    msp = doc.modelspace()

    if args.unit:
        scale = UNIT_TO_M[args.unit]
    else:
        scale = INSUNITS_TO_M.get(doc.header.get("$INSUNITS", 4), 0.001)

    up = lambda names: {n.strip().upper() for n in names.split(",")}
    wall_segs = collect_segments(msp, up(args.wall_layers))

    if args.double_line:
        walls = double_lines_to_centerlines(
            wall_segs, args.min_thickness / scale, args.max_thickness / scale)
    else:
        walls = [{"start": a, "end": b, "thickness": args.thickness / scale} for a, b in wall_segs]

    def pt(p):
        return [round(p[0] * scale, 4), round(p[1] * scale, 4)]

    data = {
        "unit": "m",
        "levels": [{"name": "1F", "elevation": 0.0}],
        "wall_height": args.height,
        "walls": [
            {"start": pt(w["start"]), "end": pt(w["end"]),
             "thickness": round(w["thickness"] * scale, 4), "level": "1F"}
            for w in walls
        ],
        "doors": [dict(o, x=round(o["x"] * scale, 4), y=round(o["y"] * scale, 4), level="1F")
                  for o in collect_inserts(msp, up(args.door_layers))],
        "windows": [dict(o, x=round(o["x"] * scale, 4), y=round(o["y"] * scale, 4), level="1F",
                         sill_height=args.sill_height)
                    for o in collect_inserts(msp, up(args.window_layers))],
        "floors": [{"points": [pt(p) for p in f], "level": "1F"}
                   for f in collect_floors(msp, up(args.floor_layers))],
    }
    return data


def main():
    ap = argparse.ArgumentParser(description="DXF 平面圖轉 Revit 建模 JSON")
    ap.add_argument("dxf")
    ap.add_argument("json")
    ap.add_argument("--unit", choices=sorted(UNIT_TO_M), help="DXF 繪圖單位 (預設讀 $INSUNITS，沒有就當 mm)")
    ap.add_argument("--wall-layers", default="WALL,牆", help="牆圖層名稱，逗號分隔")
    ap.add_argument("--door-layers", default="DOOR,門")
    ap.add_argument("--window-layers", default="WINDOW,窗")
    ap.add_argument("--floor-layers", default="FLOOR,樓板")
    ap.add_argument("--double-line", action="store_true", help="牆是畫成雙線 (兩側邊線)")
    ap.add_argument("--thickness", type=float, default=0.15, help="單線牆的預設厚度 (m)")
    ap.add_argument("--min-thickness", type=float, default=0.08, help="雙線牆最小厚度 (m)")
    ap.add_argument("--max-thickness", type=float, default=0.40, help="雙線牆最大厚度 (m)")
    ap.add_argument("--height", type=float, default=3.0, help="牆高 (m)")
    ap.add_argument("--sill-height", type=float, default=0.9, help="窗台高 (m)")
    args = ap.parse_args()

    data = convert(args.dxf, args)
    with open(args.json, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("牆 %d 道、門 %d 樘、窗 %d 樘、樓板 %d 片 -> %s" % (
        len(data["walls"]), len(data["doors"]), len(data["windows"]), len(data["floors"]), args.json))


if __name__ == "__main__":
    main()
