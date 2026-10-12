# 2D 平面圖轉 Revit 3D

把 AutoCAD 的 2D 平面圖 (DXF) 自動轉成 Revit 3D 模型（牆、樓板、門、窗）。

分成兩個步驟：

```
plan.dxf ──(1) dxf_to_json.py──> plan.json ──(2) revit_build_from_json.py (在 Revit 內執行)──> 3D 模型
```

把 DXF 解析和 Revit 建模拆開有兩個好處：解析可以在任何電腦上用一般的 Python 跑、用 `ezdxf` 套件；
Revit 端只需要讀一個簡單的 JSON，不用安裝額外套件。

## 檔案

| 檔案 | 用途 |
| --- | --- |
| `dxf_to_json.py` | 讀 DXF，依圖層抓出牆、門、窗、樓板，輸出 JSON（單位：公尺） |
| `revit_build_from_json.py` | 在 Revit 中執行，讀 JSON 建立樓層、牆、樓板、門、窗 |
| `make_sample_dxf.py` | 產生測試用的 DXF（單線牆 / 雙線牆兩種） |

## 步驟 1：DXF → JSON

```bash
pip install ezdxf
python make_sample_dxf.py                 # 產生 sample_single.dxf 測試
python dxf_to_json.py sample_single.dxf plan.json

# 牆畫成雙線（台灣常見畫法）時加 --double-line
python make_sample_dxf.py --double
python dxf_to_json.py sample_double.dxf plan.json --double-line
```

DWG 請先在 AutoCAD 用「另存新檔 → DXF」轉存。

### 圖面要求（圖層名稱可用參數改）

| 圖層 | 內容 | 參數 |
| --- | --- | --- |
| `WALL` / `牆` | 牆：LINE 或 LWPOLYLINE。單線 = 牆中心線；雙線 = 牆兩側邊線 | `--wall-layers` |
| `DOOR` / `門` | 門圖塊 (INSERT)，插入點要在牆上 | `--door-layers` |
| `WINDOW` / `窗` | 窗圖塊 (INSERT)，插入點要在牆上 | `--window-layers` |
| `FLOOR` / `樓板` | 封閉聚合線，當作樓板邊界 | `--floor-layers` |

其他參數：

- `--unit mm|cm|m|in|ft`：DXF 的繪圖單位（預設讀檔案的 `$INSUNITS`，沒有就當 mm）
- `--height 3.0`：牆高 (m)
- `--thickness 0.15`：單線牆的厚度 (m)
- `--min-thickness 0.08 --max-thickness 0.40`：雙線牆配對時允許的牆厚範圍 (m)
- `--sill-height 0.9`：窗台高 (m)

## 步驟 2：在 Revit 中產生 3D

已針對 **Revit 2026** 調整（Revit 2025 起改用 .NET 8，Dynamo 預設改用 CPython 3；程式兩種 Python 都相容）。任選一種方式執行 `revit_build_from_json.py`：

### 方法 A：pyRevit（推薦）

1. 安裝支援 Revit 2026 的 pyRevit 版本（5.x 以上，到 GitHub `pyrevitlabs/pyRevit` 的 Releases 下載）
2. 建立按鈕資料夾，把程式改名為 `script.py` 放進去：
   ```
   我的工具.extension\我的工具.tab\建模.panel\2D轉3D.pushbutton\script.py
   ```
3. pyRevit 頁籤 → Settings → Custom Extension Directories 加入 `.extension` 的上層資料夾 → Reload
4. 點「2D轉3D」按鈕，選 JSON 檔即可

### 方法 B：Dynamo（Revit 2026 內建）

1. 管理 → Dynamo，新增空白圖面
2. 放一個 **File Path** 節點（選 JSON）接到 **Python Script** 節點的 `IN[0]`
3. Python Script 節點右鍵 → 引擎選 **CPython3** 或 **PythonNet3**，把程式內容貼進去
4. 執行（Dynamo 會自己管 Transaction，程式已自動處理）

程式會：

1. 建立 JSON 裡的樓層（已存在同名樓層就沿用）
2. 依厚度找相符的基本牆類型，沒有就複製一個並調整結構層厚度（命名為「2D轉3D 牆 200mm」）
3. 建立牆、樓板（使用 `Floor.Create`，Revit 2022 以後的寫法）
4. 把門窗放在離插入點最近的牆上（窗會設定窗台高度）

pyRevit 執行時所有動作包在同一個 Transaction 裡，出錯會整個復原；成功後可以 Ctrl+Z 一次復原。

門窗預設使用專案中第一個已載入的門 / 窗族群，要指定類型請改 `DOOR_TYPE_NAME` / `WINDOW_TYPE_NAME`
（格式 `"族群名稱: 類型名稱"`）。

## 限制

- 弧形牆、圓弧聚合線目前只取頂點（會變成直線）
- 雙線牆：門窗開口處的牆線若被切斷，會產生兩段牆；門窗仍會放在附近的牆上，但可能需手動調整
- 門窗的開門方向、尺寸沿用族群類型預設值，不讀圖塊內容
- 目前只有一個樓層 (1F)；多樓層可在 JSON 的 `levels` 增加，並把牆的 `level` 改成對應名稱
