;;; ============================================================
;;; DelBlockHatch.lsp  -  刪除圖塊(Block)內的填充線(Hatch)
;;;
;;; 指令：
;;;   DELBHATCH   刪除「整張圖」所有圖塊定義內的 Hatch
;;;   DELBHATCHS  只刪除「選取的圖塊」(含其巢狀圖塊)內的 Hatch
;;;
;;; 說明：
;;;   - 直接修改圖塊定義，所以同名圖塊的每一個插入都會一起更新。
;;;   - 支援動態圖塊(會同時處理 *U 匿名圖塊與原始定義)。
;;;   - 鎖定圖層會暫時解鎖，完成後自動恢復。
;;;   - 不處理外部參考(Xref)；模型/配置空間本身的 Hatch 不會被刪。
;;;   - 可用 UNDO 一次復原。
;;;
;;; 使用：APPLOAD 載入本檔，或拖曳 .lsp 進 AutoCAD 視窗。
;;; ============================================================

(vl-load-com)

;; 刪除單一圖塊定義中的所有 Hatch，回傳刪除數量
(defun _dbh:clean-block (blk / lst n)
  (setq n 0)
  ;; 先收集再刪，避免邊走訪邊刪除
  (vlax-for obj blk
    (if (= (vla-get-ObjectName obj) "AcDbHatch")
      (setq lst (cons obj lst))
    )
  )
  (foreach obj lst
    (if (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-delete (list obj))))
      (setq n (1+ n))
    )
  )
  n
)

;; 暫時解鎖所有圖層，回傳原本被鎖的圖層清單
(defun _dbh:unlock-layers (doc / lst)
  (vlax-for lay (vla-get-Layers doc)
    (if (= (vla-get-Lock lay) :vlax-true)
      (progn (vla-put-Lock lay :vlax-false) (setq lst (cons lay lst)))
    )
  )
  lst
)

(defun _dbh:relock-layers (lst)
  (foreach lay lst
    (vl-catch-all-apply 'vla-put-Lock (list lay :vlax-true))
  )
)

;; 遞迴收集圖塊名稱(含巢狀圖塊)
(defun _dbh:collect-names (blocks name acc / blk)
  (if (and name
           (not (member (strcase name) (mapcar 'strcase acc)))
           (not (vl-catch-all-error-p
                  (setq blk (vl-catch-all-apply 'vla-item (list blocks name)))))
           (= (vla-get-IsXRef blk) :vlax-false)
      )
    (progn
      (setq acc (cons name acc))
      (vlax-for obj blk
        (if (= (vla-get-ObjectName obj) "AcDbBlockReference")
          (progn
            (setq acc (_dbh:collect-names blocks (vla-get-Name obj) acc))
            (if (vlax-property-available-p obj 'EffectiveName)
              (setq acc (_dbh:collect-names blocks (vla-get-EffectiveName obj) acc))
            )
          )
        )
      )
    )
  )
  acc
)

;; 共用執行流程：names = nil 代表處理全部圖塊
(defun _dbh:run (doc names / *error* blocks locked total)
  (setq blocks (vla-get-Blocks doc)
        total  0)
  (defun *error* (msg)
    (_dbh:relock-layers locked)
    (vla-EndUndoMark doc)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*"))
      (princ (strcat "\n錯誤: " msg))
    )
    (princ)
  )
  (vla-StartUndoMark doc)
  (setq locked (_dbh:unlock-layers doc))
  (vlax-for blk blocks
    (if (and (= (vla-get-IsLayout blk) :vlax-false)
             (= (vla-get-IsXRef blk) :vlax-false)
             (or (null names)
                 (member (strcase (vla-get-Name blk)) (mapcar 'strcase names)))
        )
      (setq total (+ total (_dbh:clean-block blk)))
    )
  )
  (_dbh:relock-layers locked)
  (vla-Regen doc acAllViewports)
  (vla-EndUndoMark doc)
  (princ (strcat "\n已刪除圖塊內 Hatch 共 " (itoa total) " 個。"))
  (princ)
)

;; 指令：刪除全圖所有圖塊內的 Hatch
(defun c:DELBHATCH (/ doc)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (initget "Yes No")
  (if (/= (getkword "\n確定要刪除「所有圖塊」內的 Hatch？[Yes/No] <Yes>: ") "No")
    (_dbh:run doc nil)
  )
  (princ)
)

;; 指令：只刪除選取圖塊(含巢狀)內的 Hatch
(defun c:DELBHATCHS (/ doc blocks ss i obj names)
  (setq doc    (vla-get-ActiveDocument (vlax-get-acad-object))
        blocks (vla-get-Blocks doc))
  (princ "\n選取要清除 Hatch 的圖塊: ")
  (if (setq ss (ssget '((0 . "INSERT"))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq obj   (vlax-ename->vla-object (ssname ss i))
              names (_dbh:collect-names blocks (vla-get-Name obj) names))
        (if (vlax-property-available-p obj 'EffectiveName)
          (setq names (_dbh:collect-names blocks (vla-get-EffectiveName obj) names))
        )
        (setq i (1+ i))
      )
      (if names (_dbh:run doc names))
    )
    (princ "\n未選取任何圖塊。")
  )
  (princ)
)

(princ "\nDelBlockHatch 已載入：DELBHATCH = 全部圖塊，DELBHATCHS = 選取圖塊。")
(princ)
