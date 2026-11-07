;;; ============================================================
;;; BKD.lsp  圖塊到牆的連續尺寸標註
;;; 指令：BKD
;;; 1. 選方向（水平H／垂直V）
;;; 2. 用鎖點點選牆面一點（牆可為圖塊或外部參考，會自動排除）
;;; 3. 框選設備圖塊
;;; 4. 指定尺寸線位置
;;; 標註點：圖塊內第一個圓的圓心；沒有圓則用插入點
;;; ============================================================

(vl-load-com)

;; 取得圖塊中的圓心（找不到圓就用插入點）
(defun bk:center (e / ed ins sx sy ang blk base ent d c dx dy)
  (setq ed  (entget e)
        ins (cdr (assoc 10 ed))
        sx  (cond ((cdr (assoc 41 ed))) (1.0))
        sy  (cond ((cdr (assoc 42 ed))) (1.0))
        ang (cond ((cdr (assoc 50 ed))) (0.0))
        blk (tblobjname "BLOCK" (cdr (assoc 2 ed)))
        base (cdr (assoc 10 (entget blk)))
        ent (entnext blk))
  (while (and ent (not c))
    (setq d (entget ent))
    (if (= (cdr (assoc 0 d)) "CIRCLE") (setq c (cdr (assoc 10 d))))
    (setq ent (entnext ent)))
  (if c
    (progn
      (setq dx (* sx (- (car c) (car base)))
            dy (* sy (- (cadr c) (cadr base))))
      (trans (list (+ (car ins) (- (* dx (cos ang)) (* dy (sin ang))))
                   (+ (cadr ins) (* dx (sin ang)) (* dy (cos ang)))
                   (caddr ins))
             e 1))
    (trans ins e 1)))

;; BKD：圖塊到牆的連續尺寸標註（抓圓心、可排除牆圖塊）
(defun c:BKD (/ *error* oldos oldce dir wp wall ss i e pts dl prev key)
  (defun *error* (msg)
    (if oldos (setvar "OSMODE" oldos))
    (if oldce (setvar "CMDECHO" oldce))
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*"))
      (princ (strcat "\n錯誤: " msg)))
    (princ))
  (setq oldos (getvar "OSMODE") oldce (getvar "CMDECHO"))
  (initget "H V")
  (setq dir (cond ((getkword "\n標註方向 [水平(H)/垂直(V)] <H>: ")) ("H")))
  (setq key (if (= dir "H") car cadr))
  (setq wp (getpoint "\n點選牆面上一點(用垂直/端點鎖點): "))
  (setq wall (ssget wp))
  (princ "\n選取要標註的圖塊(框到牆也沒關係): ")
  (if (setq ss (ssget '((0 . "INSERT"))))
    (progn
      (if wall
        (progn (setq i 0)
          (repeat (sslength wall)
            (if (ssmemb (ssname wall i) ss) (ssdel (ssname wall i) ss))
            (setq i (1+ i)))))
      (setq i 0 pts '())
      (repeat (sslength ss)
        (setq e (ssname ss i)
              pts (cons (bk:center e) pts)
              i (1+ i)))
      (setq pts (vl-sort pts
        (function (lambda (a b)
          (< (abs (- (key a) (key wp))) (abs (- (key b) (key wp))))))))
      (setq dl (getpoint "\n指定尺寸線位置: "))
      (setvar "OSMODE" 0) (setvar "CMDECHO" 0)
      (setq prev wp)
      (foreach p pts
        (if (> (abs (- (key p) (key prev))) 1e-4)
          (progn
            (command "_.DIMLINEAR" "_non" prev "_non" p
                     (if (= dir "H") "_H" "_V") "_non" dl)
            (setq prev p))))
      (setvar "OSMODE" oldos) (setvar "CMDECHO" oldce)))
  (princ))

(princ "\nBKD 已載入，輸入 BKD 執行。")
(princ)
