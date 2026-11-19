;;; TH300.lsp  -- 限制文字高度不超過 300，文字保持在原位
;;; 指令：TH300
;;; 支援：TEXT、MTEXT、圖塊屬性 ATTRIB，以及「圖塊內部」的文字（含巢狀圖塊）
;;; 原理：只修改高度碼 40，不動插入點(10)/對齊點(11)，因此文字留在原位。
;;; 圖塊內文字會考慮圖塊的 Y 比例：顯示出來的字高 = 定義字高 x 比例，
;;; 程式會讓顯示字高 <= 300（同一圖塊多個比例時，以選取中最大的比例為準）。
;;; 注意：修改的是圖塊定義，同名圖塊在整張圖中都會一起改變。

(setq *th:maxh* 300.0)   ; 最大字高，要改上限改這裡

;; 若圖元字高 > lim 則改成 lim，有修改回傳 T
(defun th:fixh (e lim / ed h)
  (setq ed (entget e)
        h  (cdr (assoc 40 ed)))
  (if (and h (> h lim))
    (progn
      (entmod (subst (cons 40 lim) (assoc 40 ed) ed))
      T
    )
  )
)

;; 收集每個圖塊定義需要考慮的最大累積比例（含巢狀）
(defun th:collect (name scl / bd old e ed)
  (setq bd (tblsearch "BLOCK" name))
  (if (and bd (= 0 (logand 4 (cdr (assoc 70 bd)))))   ; 跳過外部參考
    (progn
      (setq old (assoc name *th:map*))
      (if (or (null old) (> scl (cdr old)))
        (progn
          (setq *th:map*
                 (if old
                   (subst (cons name scl) old *th:map*)
                   (cons (cons name scl) *th:map*)
                 )
          )
          (setq e (cdr (assoc -2 bd)))
          (while e
            (setq ed (entget e))
            (if (= (cdr (assoc 0 ed)) "INSERT")
              (th:collect (cdr (assoc 2 ed))
                          (* scl (abs (cdr (assoc 42 ed)))))
            )
            (setq e (entnext e))
          )
        )
      )
    )
  )
)

;; 修改圖塊定義內的文字
(defun th:apply (name scl / e lim)
  (setq e   (cdr (assoc -2 (tblsearch "BLOCK" name)))
        lim (/ *th:maxh* scl))
  (while e
    (if (wcmatch (cdr (assoc 0 (entget e))) "TEXT,MTEXT,ATTDEF,ATTRIB")
      (if (th:fixh e lim) (setq *th:n* (1+ *th:n*)))
    )
    (setq e (entnext e))
  )
)

(defun c:TH300 (/ ss i e a ed)
  (setq *th:n* 0 *th:map* nil)
  (princ "\n選取文字或圖塊（字高 > 300 的會改成 300）：")
  (if (setq ss (ssget '((0 . "TEXT,MTEXT,INSERT"))))
    (progn
      (repeat (setq i (sslength ss))
        (setq e  (ssname ss (setq i (1- i)))
              ed (entget e))
        (if (= (cdr (assoc 0 ed)) "INSERT")
          (progn
            ;; 1. 圖塊屬性（本身就是世界座標字高）
            (setq a (entnext e))
            (while (and a (= (cdr (assoc 0 (entget a))) "ATTRIB"))
              (if (th:fixh a *th:maxh*) (setq *th:n* (1+ *th:n*)))
              (entupd a)
              (setq a (entnext a))
            )
            ;; 2. 記錄圖塊定義與比例
            (th:collect (cdr (assoc 2 ed)) (abs (cdr (assoc 42 ed))))
          )
          ;; TEXT / MTEXT
          (if (th:fixh e *th:maxh*)
            (progn (entupd e) (setq *th:n* (1+ *th:n*)))
          )
        )
      )
      ;; 3. 修改圖塊定義內的文字
      (foreach p *th:map* (th:apply (car p) (cdr p)))
      (if *th:map* (command "_.REGEN"))
      (princ (strcat "\n完成，共修改 " (itoa *th:n*) " 個文字。"))
    )
    (princ "\n未選取任何物件。")
  )
  (princ)
)

(princ "\n已載入 TH300：輸入 TH300 執行（字高上限 300，含圖塊內文字，文字保持原位）。")
(princ)
