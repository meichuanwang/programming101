;;; TH300.lsp  -- 限制文字高度不超過 300，文字保持在原位
;;; 指令：TH300
;;; 支援：TEXT（單行文字）、MTEXT（多行文字）、圖塊內的屬性 ATTRIB
;;; 原理：只修改高度碼 40，不動插入點(10)/對齊點(11)，因此文字留在原位。

(setq *th:maxh* 300.0)   ; 最大字高，要改上限改這裡

;; 修正單一圖元的字高，有修改回傳 T
(defun th:fix (e / ed h)
  (setq ed (entget e)
        h  (cdr (assoc 40 ed)))
  (if (and h (> h *th:maxh*))
    (progn
      (entmod (subst (cons 40 *th:maxh*) (assoc 40 ed) ed))
      (entupd e)
      T
    )
  )
)

(defun c:TH300 (/ ss i e a ed n)
  (setq n 0)
  (princ (strcat "\n選取文字（字高 > " (rtos *th:maxh* 2 0) " 的會改成 " (rtos *th:maxh* 2 0) "）："))
  (if (setq ss (ssget '((0 . "TEXT,MTEXT,INSERT"))))
    (progn
      (repeat (setq i (sslength ss))
        (setq e (ssname ss (setq i (1- i))))
        (if (= (cdr (assoc 0 (entget e))) "INSERT")
          ;; 圖塊：處理其屬性
          (progn
            (setq a (entnext e))
            (while (and a (= (cdr (assoc 0 (setq ed (entget a)))) "ATTRIB"))
              (if (th:fix a) (setq n (1+ n)))
              (setq a (entnext a))
            )
            (entupd e)
          )
          ;; TEXT / MTEXT
          (if (th:fix e) (setq n (1+ n)))
        )
      )
      (princ (strcat "\n完成，共修改 " (itoa n) " 個文字。"))
    )
    (princ "\n未選取任何物件。")
  )
  (princ)
)

(princ "\n已載入 TH300：輸入 TH300 執行（字高上限 300，文字保持原位）。")
(princ)
