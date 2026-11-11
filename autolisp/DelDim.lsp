;;; ============================================================
;;; DelDim.lsp  -  刪除標註尺寸 (Delete Dimensions)，含圖塊內的標註
;;;
;;; 載入方式：APPLOAD 選取本檔，或將檔案拖曳進 AutoCAD 視窗
;;;
;;; 指令：
;;;   DELDIM  - 互動選擇刪除範圍
;;;             [Select]  框選物件：刪除選到的標註，以及選到的圖塊內的標註
;;;             [Current] 目前空間(模型/目前配置)的標註，以及其中圖塊內的標註
;;;             [All]     整張圖所有標註，包含所有圖塊定義內的標註
;;;   DDA     - 快速指令：等同 All
;;;
;;; 注意：
;;;   - 圖塊內的標註是修改「圖塊定義」，同名圖塊的所有複本都會一起改變。
;;;   - 巢狀圖塊(圖塊裡的圖塊)、動態圖塊都會處理。
;;;   - 外部參考(Xref)不會被修改。
;;;   - 鎖定圖層上的標註不會被刪除，會另外統計顯示。
;;;   - 可用 U / UNDO 一次復原。
;;; ============================================================

(vl-load-com)

;; 刪除單一物件，更新 ok / bad 計數 (由 deldim:run 宣告的區域變數)
(defun deldim:del (obj)
  (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-delete (list obj)))
    (setq bad (1+ bad))   ; 通常是在鎖定圖層上
    (setq ok (1+ ok))
  )
)

(defun deldim:isdim (obj)
  (wcmatch (strcase (vla-get-ObjectName obj)) "ACDB*DIMENSION*")
)

;; 處理一個圖塊定義：刪除內部標註，並遞迴處理巢狀圖塊
(defun deldim:doblock (blk / name lst)
  (setq name (strcase (vla-get-Name blk)))
  (if (and (not (member name done))
           (= (vla-get-IsXRef blk) :vlax-false)
           (= (vla-get-IsLayout blk) :vlax-false))
    (progn
      (setq done (cons name done))
      ;; 先收集再刪除，避免在走訪集合時修改它
      (vlax-for o blk (setq lst (cons o lst)))
      (foreach o lst
        (cond
          ((deldim:isdim o) (deldim:del o))
          ((= (vla-get-ObjectName o) "AcDbBlockReference") (deldim:doinsert o))
        )
      )
    )
  )
)

;; 處理一個圖塊參考：找出它的定義 (動態圖塊同時處理匿名圖塊與原始定義)
(defun deldim:doinsert (ref / blks nm blk)
  (setq blks (vla-get-Blocks doc))
  (foreach nm (list (vla-get-Name ref)
                    (vl-catch-all-apply 'vla-get-EffectiveName (list ref)))
    (if (and (= (type nm) 'STR)
             (not (vl-catch-all-error-p
                    (setq blk (vl-catch-all-apply 'vla-item (list blks nm))))))
      (deldim:doblock blk)
    )
  )
)

;; 處理選集：標註直接刪除，圖塊參考進入定義處理
(defun deldim:doss (ss / i obj)
  (if ss
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq obj (vlax-ename->vla-object (ssname ss i)))
        (if (deldim:isdim obj) (deldim:del obj) (deldim:doinsert obj))
        (setq i (1+ i))
      )
    )
  )
)

;; 主程式：mode = "Select" / "Current" / "All"
(defun deldim:run (mode / doc flt ok bad done)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        ok 0 bad 0 done nil
        flt '((-4 . "<OR") (0 . "*DIMENSION") (0 . "INSERT") (-4 . "OR>")))
  (vla-StartUndoMark doc)
  (cond
    ((= mode "Select")
     (princ "\n選取標註或圖塊 (其他物件會自動忽略): ")
     (deldim:doss (ssget flt)))
    ((= mode "Current")
     (deldim:doss (ssget "_X" (append flt (list (cons 410 (getvar "CTAB")))))))
    ((= mode "All")
     (deldim:doss (ssget "_X" '((0 . "*DIMENSION"))))
     (vlax-for blk (vla-get-Blocks doc) (deldim:doblock blk)))
  )
  (vla-EndUndoMark doc)
  (if (> ok 0) (vla-Regen doc acAllViewports))
  (if (> (+ ok bad) 0)
    (progn
      (princ (strcat "\n已刪除 " (itoa ok) " 個標註尺寸 (含圖塊內)。"))
      (if (> bad 0)
        (princ (strcat "\n有 " (itoa bad) " 個標註在鎖定圖層上，未刪除。"))
      )
    )
    (princ "\n找不到任何標註尺寸。")
  )
  (princ)
)

(defun c:DELDIM (/ mode)
  (initget "Select Current All")
  (setq mode (getkword "\n刪除標註尺寸(含圖塊內) [Select選取/Current目前空間/All整張圖] <Select>: "))
  (deldim:run (if mode mode "Select"))
)

(defun c:DDA () (deldim:run "All"))

(princ "\nDelDim.lsp 已載入。指令：DELDIM (選擇範圍)  /  DDA (刪除整張圖所有標註，含圖塊內)")
(princ)
