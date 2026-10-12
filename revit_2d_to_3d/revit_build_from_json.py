# -*- coding: utf-8 -*-
"""
建模資料 (JSON) -> Revit 3D 模型

在 Revit 裡執行 (pyRevit / Dynamo 的 Python Script 節點皆可，已針對 Revit 2026 調整)，
讀取 dxf_to_json.py 產生的 JSON，自動建立：樓層、牆、樓板、門、窗。

注意：
  - 寫成 IronPython 2.7 / CPython 3 (PythonNet) 都能跑的語法 (不用 f-string)
  - Dynamo 中可把 JSON 路徑接到節點的 IN[0]，否則會跳出選檔視窗
  - Revit 內部單位是「英尺」，JSON 是公尺，這裡會自動換算
  - 門窗會使用專案中「第一個」已載入的門 / 窗族群類型，
    想指定的話改下面 DOOR_TYPE_NAME / WINDOW_TYPE_NAME
"""
import io
import json
import os

import clr
clr.AddReference("RevitAPI")
from Autodesk.Revit.DB import (
    BuiltInCategory, BuiltInParameter, CurveArray, CurveLoop, FilteredElementCollector,
    Floor, FloorType, Level, Line, Transaction, Wall, WallKind, WallType, XYZ,
)
from Autodesk.Revit.DB.Structure import StructuralType

# ------------------------------------------------------------------ 設定
JSON_PATH = r""            # 留空會跳出選檔視窗
DOOR_TYPE_NAME = None      # 例如 "M_單扇門: 0915 x 2134mm"，None = 用第一個
WINDOW_TYPE_NAME = None
MAX_OPENING_DIST_M = 0.5   # 門窗插入點離牆超過這個距離就略過

M_TO_FT = 1.0 / 0.3048


# ------------------------------------------------------------------ 取得目前文件
def get_document():
    """回傳 (doc, 是否在 Dynamo 中)"""
    try:  # pyRevit / RevitPythonShell
        return __revit__.ActiveUIDocument.Document, False  # noqa: F821
    except NameError:
        pass
    clr.AddReference("RevitServices")  # Dynamo
    from RevitServices.Persistence import DocumentManager
    return DocumentManager.Instance.CurrentDBDocument, True


class RevitTransaction(object):
    """
    pyRevit 用一般的 Transaction；
    Dynamo 自己已經開著 Transaction，不能再 new 一個，要改用 TransactionManager。
    """
    def __init__(self, doc, name, in_dynamo):
        self.doc, self.name, self.in_dynamo = doc, name, in_dynamo

    def __enter__(self):
        if self.in_dynamo:
            from RevitServices.Transactions import TransactionManager
            self.tm = TransactionManager.Instance
            self.tm.EnsureInTransaction(self.doc)
        else:
            self.t = Transaction(self.doc, self.name)
            self.t.Start()
        return self

    def __exit__(self, exc_type, exc, tb):
        if self.in_dynamo:
            self.tm.TransactionTaskDone()
        elif exc_type is None:
            self.t.Commit()
        else:
            self.t.RollBack()
        return False


def pick_json():
    try:  # Dynamo: 節點輸入 IN[0] 接檔案路徑
        if IN and IN[0] and os.path.exists(str(IN[0])):  # noqa: F821
            return str(IN[0])  # noqa: F821
    except NameError:
        pass
    if JSON_PATH and os.path.exists(JSON_PATH):
        return JSON_PATH
    clr.AddReference("System.Windows.Forms")
    from System.Windows.Forms import DialogResult, OpenFileDialog
    dlg = OpenFileDialog()
    dlg.Filter = "JSON (*.json)|*.json"
    dlg.Title = "選擇 dxf_to_json.py 產生的 JSON"
    if dlg.ShowDialog() == DialogResult.OK:
        return dlg.FileName
    return None


def ft(v):
    return v * M_TO_FT


def xyz(p, z=0.0):
    return XYZ(ft(p[0]), ft(p[1]), z)


# ------------------------------------------------------------------ 樓層
def get_or_create_levels(doc, levels):
    existing = dict((lv.Name, lv) for lv in FilteredElementCollector(doc).OfClass(Level))
    result = {}
    for info in levels:
        lv = existing.get(info["name"])
        if lv is None:
            lv = Level.Create(doc, ft(info["elevation"]))
            lv.Name = info["name"]
        result[info["name"]] = lv
    return result


# ------------------------------------------------------------------ 牆類型 (依厚度)
class WallTypeCache(object):
    def __init__(self, doc):
        self.doc = doc
        self.types = [t for t in FilteredElementCollector(doc).OfClass(WallType)
                      if t.Kind == WallKind.Basic]
        self.base = self.types[0]

    def get(self, thickness_m):
        width = ft(thickness_m)
        for t in self.types:
            if abs(t.Width - width) < ft(0.002):
                return t
        # 找不到相同厚度：複製一個基本牆，把結構層調成需要的厚度
        name = "2D轉3D 牆 %dmm" % round(thickness_m * 1000)
        for t in self.types:
            # CPython (PythonNet) 讀 ElementType.Name 有時會失敗，改讀參數
            if t.get_Parameter(BuiltInParameter.SYMBOL_NAME_PARAM).AsString() == name:  # 上次執行已建立過
                return t
        new_type = self.base.Duplicate(name)
        cs = new_type.GetCompoundStructure()
        if cs is not None:
            core = max(cs.GetFirstCoreLayerIndex(), 0)
            others = cs.GetWidth() - cs.GetLayerWidth(core)
            if width - others > 0:
                cs.SetLayerWidth(core, width - others)
                new_type.SetCompoundStructure(cs)
        self.types.append(new_type)
        return new_type


# ------------------------------------------------------------------ 樓板
def create_floor(doc, points, level):
    floor_type = FilteredElementCollector(doc).OfClass(FloorType).FirstElement()
    z = level.Elevation
    pts = [xyz(p, z) for p in points]
    lines = [Line.CreateBound(pts[i], pts[(i + 1) % len(pts)]) for i in range(len(pts))]
    try:  # Revit 2022 以後
        loop = CurveLoop()
        for ln in lines:
            loop.Append(ln)
        from System.Collections.Generic import List
        loops = List[CurveLoop]()
        loops.Add(loop)
        return Floor.Create(doc, loops, floor_type.Id, level.Id)
    except AttributeError:  # 舊版 Revit
        arr = CurveArray()
        for ln in lines:
            arr.Append(ln)
        return doc.Create.NewFloor(arr, floor_type, level, False)


# ------------------------------------------------------------------ 門窗
def find_symbol(doc, category, type_name):
    symbols = FilteredElementCollector(doc).OfCategory(category).WhereElementIsElementType()
    for s in symbols:
        full = "%s: %s" % (s.FamilyName, s.get_Parameter(BuiltInParameter.SYMBOL_NAME_PARAM).AsString())
        if type_name is None or type_name in (full, s.FamilyName):
            if not s.IsActive:
                s.Activate()
            return s
    return None


def nearest_wall(walls, point):
    best = None
    for wall in walls:
        line = wall.Location.Curve
        proj = line.Project(XYZ(point.X, point.Y, line.GetEndPoint(0).Z))
        if proj is None:
            continue
        if best is None or proj.Distance < best[0]:
            best = (proj.Distance, wall, proj.XYZPoint)
    return best


def place_openings(doc, items, symbol, walls, levels, is_window, log):
    if symbol is None:
        log.append("找不到%s族群，略過 %d 個" % ("窗" if is_window else "門", len(items)))
        return 0
    count = 0
    for o in items:
        level = levels[o["level"]]
        hit = nearest_wall(walls, xyz((o["x"], o["y"]), level.Elevation))
        if hit is None or hit[0] > ft(MAX_OPENING_DIST_M):
            log.append("(%.2f, %.2f) 附近沒有牆，略過" % (o["x"], o["y"]))
            continue
        _, wall, p = hit
        inst = doc.Create.NewFamilyInstance(
            XYZ(p.X, p.Y, level.Elevation), symbol, wall, level, StructuralType.NonStructural)
        if is_window:
            sill = inst.get_Parameter(BuiltInParameter.INSTANCE_SILL_HEIGHT_PARAM)
            if sill is not None and not sill.IsReadOnly:
                sill.Set(ft(o.get("sill_height", 0.9)))
        count += 1
    return count


# ------------------------------------------------------------------ 主流程
def build(doc, data, in_dynamo):
    log = []
    with RevitTransaction(doc, "2D 平面圖轉 3D", in_dynamo):
        levels = get_or_create_levels(doc, data["levels"])
        wall_types = WallTypeCache(doc)
        height = ft(data.get("wall_height", 3.0))

        walls = []
        for w in data["walls"]:
            level = levels[w["level"]]
            p1, p2 = xyz(w["start"], level.Elevation), xyz(w["end"], level.Elevation)
            if p1.DistanceTo(p2) < doc.Application.ShortCurveTolerance:
                continue
            wt = wall_types.get(w["thickness"])
            walls.append(Wall.Create(doc, Line.CreateBound(p1, p2), wt.Id, level.Id,
                                     height, 0.0, False, False))

        for f in data.get("floors", []):
            create_floor(doc, f["points"], levels[f["level"]])

        # 先讓牆生成，門窗才找得到宿主
        doc.Regenerate()
        n_door = place_openings(doc, data.get("doors", []),
                                find_symbol(doc, BuiltInCategory.OST_Doors, DOOR_TYPE_NAME),
                                walls, levels, False, log)
        n_win = place_openings(doc, data.get("windows", []),
                               find_symbol(doc, BuiltInCategory.OST_Windows, WINDOW_TYPE_NAME),
                               walls, levels, True, log)

    log.insert(0, "完成：牆 %d 道、樓板 %d 片、門 %d 樘、窗 %d 樘" % (
        len(walls), len(data.get("floors", [])), n_door, n_win))
    return "\n".join(log)


doc, in_dynamo = get_document()
path = pick_json()
if path:
    with io.open(path, encoding="utf-8") as fp:
        data = json.load(fp)
    msg = build(doc, data, in_dynamo)
    print(msg)
    OUT = msg  # Dynamo 節點輸出
else:
    OUT = "未選擇檔案"
