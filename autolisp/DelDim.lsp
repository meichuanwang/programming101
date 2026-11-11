;;; ============================================================
;;; DelDim.lsp  -  刪除標註尺寸 (Delete Dimensions)
;;;
;;; 載入方式：APPLOAD 選取本檔，或將檔案拖曳進 AutoCAD 視窗
;;;
;;; 指令：
;;;   DELDIM  - 互動選擇刪除範圍
;;;             [Select]  框選物件，只刪除其中的標註
;;;             [Current] 刪除目前空間(模型/目前配置)所有標註
;;;             [All]     刪除整張圖(所有配置)的標註
;;;   DDA     - 快速指令：直接刪除整張圖所有標註
;;;
;;; 涵蓋類型：線性、對齊、角度、半徑、直徑、座標、弧長、轉折
;;;           (所有 *DIMENSION 物件)
;;; 鎖定圖層上的標註不會被刪除，會另外統計顯示。
;;; 可用 U / UNDO 一次復原。
;;; ============================================================

(vl-load-com)

;; 刪除選集內的物件，回傳 (成功數 . 失敗數)
(defun deldim:erase (ss / i obj ok bad)
  (setq i 0 ok 0 bad 0)
  (repeat (sslength ss)
    (setq obj (vlax-ename->vla-object (ssname ss i)))
    (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-delete (list obj)))
      (setq bad (1+ bad))   ; 通常是在鎖定圖層上
      (setq ok (1+ ok))
    )
    (setq i (1+ i))
  )
  (cons ok bad)
)

;; 主程式：mode = "Select" / "Current" / "All"
(defun deldim:run (mode / doc flt ss res)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        flt '((0 . "*DIMENSION")))
  (setq ss
    (cond
      ((= mode "Select")
       (princ "\n選取要刪除標註的範圍 (其他物件會自動忽略): ")
       (ssget flt))
      ((= mode "Current")
       (ssget "_X" (append flt (list (cons 410 (getvar "CTAB"))))))
      ((= mode "All")
       (ssget "_X" flt))
    )
  )
  (if ss
    (progn
      (vla-StartUndoMark doc)
      (setq res (deldim:erase ss))
      (vla-EndUndoMark doc)
      (princ (strcat "\n已刪除 " (itoa (car res)) " 個標註尺寸。"))
      (if (> (cdr res) 0)
        (princ (strcat "\n有 " (itoa (cdr res)) " 個標註在鎖定圖層上，未刪除。"))
      )
    )
    (princ "\n找不到任何標註尺寸。")
  )
  (princ)
)

(defun c:DELDIM (/ mode)
  (initget "Select Current All")
  (setq mode (getkword "\n刪除標註尺寸 [Select選取/Current目前空間/All整張圖] <Select>: "))
  (deldim:run (if mode mode "Select"))
)

(defun c:DDA () (deldim:run "All"))

(princ "\nDelDim.lsp 已載入。指令：DELDIM (選擇範圍)  /  DDA (刪除整張圖所有標註)")
(princ)
