;;=========================================================
;; OUTSRC ：另存「-外包用」檔案，並刪除中心線圖層
;;          目前開著的工作檔不受影響
;;=========================================================
(vl-load-com)

(defun c:OUTSRC ( / lay src dst ver dbx lst cnt lyr)
  (setq lay "P-中心線")            ; ← 中心線圖層名稱，可自行修改

  (if (= 0 (getvar "DWGTITLED"))
    (progn (princ "\n請先存檔後再執行。") (exit))
  )
  ;; 避免目前圖層停在中心線圖層
  (if (= (strcase (getvar "CLAYER")) (strcase lay))
    (setvar "CLAYER" "0")
  )
  (command "_.QSAVE")

  (setq src (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))
        dst (strcat (getvar "DWGPREFIX") (vl-filename-base src) "-外包用.dwg"))

  (if (findfile dst) (vl-file-delete dst))
  (if (not (vl-file-copy src dst))
    (progn (princ "\n複製檔案失敗，請確認資料夾權限。") (exit))
  )

  ;; 用 ObjectDBX 在背景開啟複製檔
  (setq ver (substr (getvar "ACADVER") 1 2)
        dbx (vla-GetInterfaceObject (vlax-get-acad-object)
              (strcat "ObjectDBX.AxDbDocument." ver)))
  (vla-Open dbx dst)

  ;; 解鎖中心線圖層，避免刪不掉
  (if (not (vl-catch-all-error-p
             (setq lyr (vl-catch-all-apply 'vla-Item (list (vla-get-Layers dbx) lay)))))
    (vla-put-Lock lyr :vlax-false)
    (setq lyr nil)
  )

  ;; 收集所有空間、圖塊內在中心線圖層上的物件
  (setq lst '() cnt 0)
  (vlax-for blk (vla-get-Blocks dbx)
    (vlax-for obj blk
      (if (= (strcase (vla-get-Layer obj)) (strcase lay))
        (setq lst (cons obj lst))
      )
    )
  )
  (foreach obj lst
    (if (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-Delete (list obj))))
      (setq cnt (1+ cnt))
    )
  )
  ;; 刪除圖層本身
  (if lyr (vl-catch-all-apply 'vla-Delete (list lyr)))

  (vla-SaveAs dbx dst)
  (vlax-release-object dbx)

  (princ (strcat "\n完成：已刪除 " (itoa cnt) " 個中心線物件。"
                 "\n外包檔案：" dst))
  (princ)
)

(princ "\n已載入：OUTSRC = 另存外包用檔案（刪除中心線）")
(princ)
