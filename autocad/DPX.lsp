;;=========================================================
;; DPX  ：交叉自動斷線（上層管連續，下層管在交叉處斷開）
;; DPXS ：設定處理方式（斷開 / 虛線）與斷線間隙
;;=========================================================
(vl-load-com)

(if (not *DP-CL*)    (setq *DP-CL* "P-中心線"))   ; 中心線圖層，不會被處理
(if (not *DPX-mode*) (setq *DPX-mode* "B"))       ; B = 斷開，H = 虛線
(if (not *DPX-gap*)  (setq *DPX-gap* 50.0))       ; 斷開時，離上層管邊線的間隙 (mm)

;; 選集轉清單
(defun DPX:ss->list (ss / i lst)
  (if ss
    (repeat (setq i (sslength ss))
      (setq lst (cons (ssname ss (setq i (1- i))) lst))))
  lst
)

;; 兩物件的交點
(defun DPX:inters (e1 e2 / r v lst)
  (setq r (vl-catch-all-apply 'vla-IntersectWith
            (list (vlax-ename->vla-object e1)
                  (vlax-ename->vla-object e2)
                  acExtendNone)))
  (if (and (not (vl-catch-all-error-p r))
           (setq v (vlax-variant-value r))
           (>= (vlax-safearray-get-u-bound v 1) 0))
    (progn
      (setq v (vlax-safearray->list v))
      (while v
        (setq lst (cons (list (car v) (cadr v) (caddr v)) lst)
              v   (cdddr v)))))
  lst
)

;; 找出同時包含 p1、p2 的線段（斷開後線會分成好幾段）
(defun DPX:find (p1 p2 pieces / found)
  (foreach e pieces
    (if (and (not found) (entget e)
             (< (distance p1 (vlax-curve-getClosestPointTo e p1)) 0.01)
             (< (distance p2 (vlax-curve-getClosestPointTo e p2)) 0.01))
      (setq found e)))
  found
)

;; 載入線型
(defun DPX:ltype (name / lin)
  (if (not (tblsearch "LTYPE" name))
    (progn
      (setq lin (if (= 1 (getvar "MEASUREMENT")) "acadiso.lin" "acad.lin"))
      (vl-catch-all-apply 'vla-Load
        (list (vla-get-Linetypes (vla-get-ActiveDocument (vlax-get-acad-object)))
              name lin))))
  (tblsearch "LTYPE" name)
)

;; 處理一條下層管邊線
(defun DPX:breakone (L upl gap mode / pts ds out len pairs a b lay pieces cnt p1 p2 tgt last)
  ;; 1. 找出和上層管的所有交點，換算成沿線距離
  (foreach U upl
    (if (not (equal U L)) (setq pts (append pts (DPX:inters L U)))))
  (setq ds (vl-sort
             (mapcar '(lambda (p)
                        (vlax-curve-getDistAtPoint L (vlax-curve-getClosestPointTo L p)))
                     pts)
             '<))
  ;; 去掉重複交點
  (foreach d ds
    (if (or (not out) (> (- d (car out)) 1e-4)) (setq out (cons d out))))
  (setq ds  (reverse out)
        len (vlax-curve-getDistAtParam L (vlax-curve-getEndParam L)))

  ;; 2. 兩兩配對（穿過上層管的兩條邊線），加上間隙，重疊的合併
  (while (cadr ds)
    (setq a (max 0.0 (- (car ds) gap))
          b (min len (+ (cadr ds) gap)))
    (if (and pairs (<= a (cadr (car pairs))))
      (setq pairs (cons (list (car (car pairs)) b) (cdr pairs)))
      (setq pairs (cons (list a b) pairs)))
    (setq ds (cddr ds)))
  ;; 整條都在上層管底下就不處理
  (setq pairs (vl-remove-if '(lambda (pr) (and (<= (car pr) 1e-6)
                                               (>= (cadr pr) (- len 1e-6))))
                            pairs))
  (setq pairs (mapcar '(lambda (pr)
                         (list (vlax-curve-getPointAtDist L (car pr))
                               (vlax-curve-getPointAtDist L (cadr pr))))
                      pairs))

  ;; 3. 斷開，虛線模式就補一條 HIDDEN 線
  (setq lay (cdr (assoc 8 (entget L))) pieces (list L) cnt 0)
  (foreach pr pairs
    (setq p1 (car pr) p2 (cadr pr) tgt (DPX:find p1 p2 pieces))
    (if tgt
      (progn
        (setq last (entlast))
        (command "_.BREAK" tgt "_F" p1 p2)
        (if (not (equal last (entlast))) (setq pieces (cons (entlast) pieces)))
        (if (= mode "H")
          (entmake (list '(0 . "LINE") (cons 8 lay) (cons 6 "HIDDEN")
                         (cons 10 p1) (cons 11 p2))))
        (setq cnt (1+ cnt)))))
  cnt
)

(defun c:DPX ( / *error* oldos oldecho filt upl lowl gap total)
  (defun *error* (msg)
    (if oldos   (setvar "OSMODE" oldos))
    (if oldecho (setvar "CMDECHO" oldecho))
    (command-s "_.UNDO" "_End")
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*"))
      (princ (strcat "\n錯誤：" msg)))
    (princ)
  )
  ;; 只選線、聚合線、弧；排除中心線和接頭圖層
  (setq filt (list '(0 . "LINE,LWPOLYLINE,ARC")
                   '(-4 . "<NOT") (cons 8 (strcat *DP-CL* ",*-接頭")) '(-4 . "NOT>")))

  (princ (strcat "\n目前設定：" (if (= *DPX-mode* "H") "虛線" "斷開")
                 (if (= *DPX-mode* "B") (strcat "，間隙 " (rtos *DPX-gap* 2 0)) "")
                 "（用 DPXS 修改）"))
  (princ "\n選【上層管】的兩條邊線（保持連續）：")
  (if (not (setq upl (DPX:ss->list (ssget filt)))) (exit))
  (princ "\n選【下層管】的邊線（會被斷開，可一次選多支）：")
  (if (not (setq lowl (DPX:ss->list (ssget filt)))) (exit))
  (setq lowl (vl-remove-if '(lambda (e) (member e upl)) lowl))

  (setq oldos (getvar "OSMODE") oldecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  (command "_.UNDO" "_Begin")

  (if (and (= *DPX-mode* "H") (not (DPX:ltype "HIDDEN")))
    (princ "\n找不到 HIDDEN 線型，虛線會顯示成實線。"))
  (setq gap   (if (= *DPX-mode* "H") 0.0 *DPX-gap*)
        total 0)
  (foreach L lowl
    (setq total (+ total (DPX:breakone L upl gap *DPX-mode*))))

  (command "_.UNDO" "_End")
  (setvar "OSMODE" oldos)
  (setvar "CMDECHO" oldecho)
  (princ (strcat "\n完成：處理 " (itoa total) " 處斷線。"))
  (princ)
)

;; 設定
(defun c:DPXS ( / m g)
  (initget "B H")
  (setq m (getkword (strcat "\n交叉處理方式 [斷開(B)/虛線(H)] <" *DPX-mode* ">: ")))
  (if m (setq *DPX-mode* m))
  (if (= *DPX-mode* "B")
    (progn
      (initget 4)
      (setq g (getdist (strcat "\n斷線間隙，離上層管邊線的距離 (mm) <"
                               (rtos *DPX-gap* 2 0) ">: ")))
      (if g (setq *DPX-gap* g))))
  (princ "\n設定完成。")
  (princ)
)

(princ "\n已載入：DPX = 交叉斷線，DPXS = 設定")
(princ)
