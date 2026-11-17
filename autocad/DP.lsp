;;=========================================================
;; DP   ：畫複線管
;;        排水：ACENT 鑄鐵管 + 不鏽鋼壓環（彎頭、斜梯、順水梯查表）
;;        消防：金日 K01 機械接頭（查表）
;;        支管從主管中心線開始畫 → 自動判斷三通
;; DPR  ：彎頭半徑（給水等用；排水、消防一律直角 + 型錄 D/CE）
;; DPJ  ：手動加接頭（點中心線）
;; DPJS ：接頭設定
;;=========================================================
(vl-load-com)

;; ================= 外徑表 =================
;; PVC 管
(setq *DP-OD-PVC*
  '((13 . 18) (20 . 26) (25 . 32) (32 . 38) (40 . 48) (50 . 60)
    (65 . 76) (80 . 89) (100 . 114) (125 . 140) (150 . 165) (200 . 216)))
;; 鋼管（消防）
(setq *DP-OD-STL*
  '((15 . 21.7) (20 . 27.2) (25 . 34.0) (32 . 42.7) (40 . 48.6) (50 . 60.5)
    (65 . 76.3) (80 . 89.1) (100 . 114.3) (125 . 139.8) (150 . 165.2)
    (200 . 216.3) (250 . 267.4) (300 . 318.5)))
;; ACENT 鑄鐵管（排水）  1½"=40 2"=50 3"=80 4"=100 5"=125 6"=150 8"=200 10"=250 12"=300 15"=375
(setq *DP-OD-CI*
  '((40 . 48.26) (50 . 59.69) (80 . 85.09) (100 . 111.25) (125 . 134.62)
    (150 . 160.02) (200 . 212.85) (250 . 268.22) (300 . 317.5) (375 . 402.08)))

;; ================= ACENT 鑄鐵彎頭 + 壓環 =================
;; (管徑A  90°彎頭D  45°彎頭D  22.5°彎頭D  壓環寬度mm)
;; 彎頭 D：型錄值。壓環寬度：估計值（型錄沒有），請依實際尺寸修改
(setq *DP-ACENT*
  '((40  108 67  54  76)
    (50  114 70  54  76)
    (80  127 76  57  76)
    (100 140 79  59  76)
    (125 165 98  73  102)
    (150 178 103 76  102)
    (200 216 127 95  102)
    (250 241 151 nil 102)
    (300 330 167 nil 152)
    (375 nil 183 nil 152)))

;; ================= ACENT 斜梯（45° Y 型三通）=================
;; ((主管 支管) D F G)
;;   D = 交點到支管端  F = 主管全長  G = 交點到主管下游端
(setq *DP-WYE*
  '(((40 40) 102 152 51)   ((50 50) 117 168 51)
    ((80 50) 135 168 38)   ((80 80) 146 203 57)
    ((100 50) 152 168 25)  ((100 80) 165 203 43)  ((100 100) 179 241 62)
    ((125 50) 191 205 24)  ((125 80) 203 246 43)  ((125 100) 216 284 62)
    ((125 125) 241 321 79)
    ((150 50) 210 211 13)  ((150 80) 222 248 32)  ((150 100) 235 284 49)
    ((150 125) 260 318 65) ((150 150) 273 357 84)
    ((200 50) 238 216 14)  ((200 80) 249 252 3)   ((200 100) 264 291 24)
    ((200 125) 289 325 41) ((200 150) 300 360 59) ((200 200) 340 435 95)
    ((250 100) 297 321 19) ((250 125) 359 356 45) ((250 150) 333 392 56)
    ((250 200) 373 467 92) ((250 250) 419 546 129)
    ((300 150) 381 407 44) ((300 200) 408 479 80) ((300 250) 449 560 121)
    ((300 300) 502 648 146)
    ((375 375) 591 762 171)))

;; ================= ACENT 順水梯（90° TY 三通）=================
;; ((主管 支管) E D F)
;;   E = 主管中心到支管端  D = 支管中心到主管下游端  F = 主管全長
(setq *DP-TY*
  '(((40 40) 108 108 165)
    ((50 40) 114 108 168)  ((50 50) 114 114 175)
    ((80 40) 127 108 165)  ((80 50) 127 114 175)  ((80 80) 127 127 203)
    ((100 50) 140 114 175) ((100 80) 140 127 203) ((100 100) 140 140 232)
    ((125 50) 165 127 216) ((125 80) 152 140 237) ((125 100) 152 152 264)
    ((125 125) 165 165 291)
    ((150 50) 165 127 208) ((150 80) 165 140 233) ((150 100) 165 152 256)
    ((150 125) 178 165 292) ((150 150) 178 178 318)
    ((200 80) 190 152 264) ((200 100) 190 165 292) ((200 125) 203 178 318)
    ((200 150) 203 191 343) ((200 200) 216 216 395)
    ((250 100) 216 178 329) ((250 150) 264 236 423) ((250 200) 257 257 462)
    ((250 250) 257 257 462)
    ((300 100) 241 191 336) ((300 150) 254 229 394) ((300 200) 280 241 434)
    ((300 250) 280 267 488) ((300 300) 292 292 546)))

;; ================= 金日 K01 / K10 / K20 / K30 =================
;; (管徑A  X  Y  Z  90°彎頭CE  45°彎頭CE  正三通CE)
(setq *DP-KS*
  '((50   84.6 120 45  83.0  51.0  70.0)
    (65  101.6 136 47  95.0  57.0  78.0)
    (80  116.2 161 47 114.3  50.8  95.7)
    (100 144.0 195 50 152.4  63.5 113.6)
    (125 170.8 220 51 190.5  78.9 134.0)
    (150 197.2 260 51 228.6  95.2 150.0)
    (200 259.9 312 63 304.8 127.0 197.8)
    (250 312.0 403 66 381.0 157.8 215.9)
    (300 366.0 454 70 457.2 189.4 254.0)))

;; 金日 K31 異徑三通 支管 CE ((主管 支管) . CE)
(setq *DP-KS-RT*
  '(((65 50) . 78.0)   ((80 50) . 85.0)   ((80 65) . 85.0)
    ((100 50) . 97.0)  ((100 65) . 97.0)  ((100 80) . 98.6)
    ((125 65) . 111.3) ((125 80) . 111.3) ((125 100) . 117.3)
    ((150 80) . 124.0) ((150 100) . 130.0) ((150 125) . 136.7)
    ((200 100) . 160.2) ((200 150) . 168.1)))

;; ================= 系統 =================
;; 代號 圖層 顏色 名稱 材料(PVC/STL/CI) 接頭(nil/RING/GROOVE)
;; 通氣若也用鑄鐵管，把 V 那行改成 "CI" "RING"
(setq *DP-SYS*
  '(("W" "P-給水-管" 5  "給水" "PVC" nil)
    ("H" "P-熱水-管" 6  "熱水" "PVC" nil)
    ("D" "P-排水-管" 34 "排水" "CI"  "RING")
    ("V" "P-通氣-管" 3  "通氣" "PVC" nil)
    ("F" "P-消防-管" 1  "消防" "STL" "GROOVE")
    ("R" "P-冷媒-管" 4  "冷媒" "PVC" nil)))

;; ================= 接頭設定 =================
;; 排水壓環：(每側外凸mm  管長mm  型錄沒有時的轉角/三通距離=外徑×  管端加)
(setq *DP-RING* '(10.0 3000.0 1.0 T))
;; 消防機接：(管長mm  平面寬度用"X"或"Y"  管端加)
(setq *DP-GRV*  '(6000.0 "X" T))

(setq *DP-CL* "P-中心線")
(if (not *DP-elbow*) (setq *DP-elbow* 0))

;; ================= 共用函式 =================
(defun DP:layer (name color plot / doc lays lay lin)
  (setq doc  (vla-get-ActiveDocument (vlax-get-acad-object))
        lays (vla-get-Layers doc))
  (if (tblsearch "LAYER" name)
    (setq lay (vla-Item lays name))
    (progn
      (setq lay (vla-Add lays name))
      (vla-put-Color lay color)
      (if (not plot)
        (progn
          (setq lin (if (= 1 (getvar "MEASUREMENT")) "acadiso.lin" "acad.lin"))
          (if (not (tblsearch "LTYPE" "CENTER"))
            (vl-catch-all-apply 'vla-Load (list (vla-get-Linetypes doc) "CENTER" lin)))
          (if (tblsearch "LTYPE" "CENTER") (vla-put-Linetype lay "CENTER"))))))
  (if (not plot) (vla-put-Plottable lay :vlax-false))
  lay
)

(defun DP:od (sysdat size)
  (cdr (assoc size (cond ((= (nth 4 sysdat) "STL") *DP-OD-STL*)
                         ((= (nth 4 sysdat) "CI")  *DP-OD-CI*)
                         (T *DP-OD-PVC*)))))
(defun DP:jlayer (sysdat) (vl-string-subst "-接頭" "-管" (cadr sysdat)))
(defun DP:ks (size) (assoc size *DP-KS*))
(defun DP:step  (jt) (if (= jt "RING") (nth 1 *DP-RING*) (nth 0 *DP-GRV*)))
(defun DP:endon (jt) (if (= jt "RING") (nth 3 *DP-RING*) (nth 2 *DP-GRV*)))

;; 讀中心線上記錄的 (系統 外徑 管徑)
(defun DP:xd (ent / xd)
  (if (setq xd (cdr (assoc -3 (entget ent '("DPPIPE")))))
    (progn (setq xd (cdr (car xd)))
           (list (cdr (assoc 1000 xd)) (cdr (assoc 1040 xd)) (cdr (assoc 1070 xd))))))

;; 接頭尺寸 (橫寬 沿管長)；nil = 不加接頭
(defun DP:jsize (jt od size / r)
  (cond ((= jt "RING")
         (setq r (assoc size *DP-ACENT*))
         (list (+ od (* 2.0 (nth 0 *DP-RING*)))
               (if r (nth 4 r) (max 50.0 (* 0.6 od)))))
        ((and (= jt "GROOVE") (setq r (DP:ks size)))
         (list (if (= (nth 1 *DP-GRV*) "Y") (nth 2 r) (nth 1 r)) (nth 3 r)))))

;; 轉角：接頭中心離轉角點的距離（defl = 轉折角）
;;   < 33.75° → 22.5° 彎頭；< 67.5° → 45° 彎頭；其他 → 90° 彎頭
(defun DP:allow (jt od size defl / r v)
  (cond ((= jt "RING")
         (setq r (assoc size *DP-ACENT*))
         (setq v (if r (cond ((< defl (* pi 0.1875)) (cond ((nth 3 r)) ((nth 2 r))))
                             ((< defl (* pi 0.375))  (nth 2 r))
                             (T (nth 1 r)))))
         (if v v (* (nth 2 *DP-RING*) od)))
        ((setq r (DP:ks size))
         (if (< defl (* pi 0.375)) (nth 5 r) (nth 4 r)))
        (T od)))

(defun DP:unit (v / l)
  (setq l (distance '(0 0 0) v))
  (mapcar '(lambda (x) (/ x l)) v))
(defun DP:dot (a b) (apply '+ (mapcar '* a b)))

;; 三通距離一律回傳 (主管+方向距離 主管-方向距離 支管距離)
;; + 方向 = 主管畫線的方向

;; 消防：金日 K30 / K31
(defun DP:grvtee (msize bsize / r ce bce)
  (if (and (setq r (DP:ks msize)) (DP:ks bsize))
    (progn
      (setq ce  (nth 6 r)
            bce (if (= msize bsize)
                  ce
                  (cond ((cdr (assoc (list msize bsize) *DP-KS-RT*))) (T ce))))
      (list ce ce bce))))

;; 排水：ACENT 斜梯 / 順水梯
;;   tv = 主管方向（單位向量），bv = 支管從交點往外的方向（單位向量）
;;   夾角 < 60° → 斜梯（支管偏向哪邊，哪邊就是上游）
;;   其他      → 順水梯（主管畫線方向 = 水流方向）
(defun DP:ringtee (tv bv msize bsize mod / c r res k)
  (setq c (DP:dot tv bv))
  (setq res
    (if (> (abs c) 0.5)
      (if (setq r (cdr (assoc (list msize bsize) *DP-WYE*)))      ; (D F G)
        (if (> c 0)
          (list (- (nth 1 r) (nth 2 r)) (nth 2 r) (nth 0 r))
          (list (nth 2 r) (- (nth 1 r) (nth 2 r)) (nth 0 r))))
      (if (setq r (cdr (assoc (list msize bsize) *DP-TY*)))       ; (E D F)
        (list (nth 1 r) (- (nth 2 r) (nth 1 r)) (nth 0 r)))))
  (if res
    res
    (progn
      (setq k (* (nth 2 *DP-RING*) mod))
      (princ "\n型錄沒有這個三通尺寸，用估計值。")
      (list k k k))))

;; 同一點是否已經有別的支管（雙斜梯、雙順水梯）
(defun DP:otherbranch (pt self main / ss i e found)
  (setq pt (list (car pt) (cadr pt) 0.0))
  (if (setq ss (ssget "_X" (list '(0 . "LWPOLYLINE") (cons 8 *DP-CL*) '(-3 ("DPPIPE")))))
    (repeat (setq i (sslength ss))
      (setq e (ssname ss (setq i (1- i))))
      (if (and (not found) (not (equal e self)) (not (equal e main))
               (or (< (distance pt (vlax-curve-getStartPoint e)) 1.0)
                   (< (distance pt (vlax-curve-getEndPoint e)) 1.0)))
        (setq found T))))
  found)

(defun DP:defl (a1 a2 / d)
  (setq d (abs (- a2 a1)))
  (if (> d pi) (- (* 2.0 pi) d) d))

(defun DP:verts (ent / lst)
  (foreach g (entget ent)
    (cond ((= (car g) 10) (setq lst (cons (list (cdr g) 0.0) lst)))
          ((and (= (car g) 42) lst)
           (setq lst (cons (list (car (car lst)) (cdr g)) (cdr lst))))))
  (reverse lst))

;; 畫接頭：wh = (橫寬 沿管長)
(defun DP:collar (pt ang wh jt lay / w h v c1 c2 c3 c4)
  (setq w (car wh) h (cadr wh) v (+ ang (/ pi 2.0)))
  (setq c1 (polar (polar pt ang (/ h  2.0)) v (/ w  2.0))
        c2 (polar (polar pt ang (/ h  2.0)) v (/ w -2.0))
        c3 (polar (polar pt ang (/ h -2.0)) v (/ w -2.0))
        c4 (polar (polar pt ang (/ h -2.0)) v (/ w  2.0)))
  (entmake (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") (cons 8 lay)
                 '(100 . "AcDbPolyline") '(90 . 4) '(70 . 1)
                 (list 10 (car c1) (cadr c1)) (list 10 (car c2) (cadr c2))
                 (list 10 (car c3) (cadr c3)) (list 10 (car c4) (cadr c4))))
  ;; 機接中間加一條分割線
  (if (= jt "GROOVE")
    (entmake (list '(0 . "LINE") (cons 8 lay)
                   (cons 10 (polar pt v (/ w 2.0)))
                   (cons 11 (polar pt v (/ w -2.0)))))))

;; 找出 pt 落在哪一條 DP 中心線的「中間」（= 三通）
(defun DP:findmain (pt self / ss i e cp found)
  (setq pt (list (car pt) (cadr pt) 0.0))
  (if (setq ss (ssget "_X" (list '(0 . "LWPOLYLINE") (cons 8 *DP-CL*) '(-3 ("DPPIPE")))))
    (repeat (setq i (sslength ss))
      (setq e (ssname ss (setq i (1- i))))
      (if (and (not found) (not (equal e self)))
        (progn
          (setq cp (vlax-curve-getClosestPointTo e pt))
          (if (and (< (distance cp pt) 1.0)
                   (> (distance pt (vlax-curve-getStartPoint e)) 1.0)
                   (> (distance pt (vlax-curve-getEndPoint e)) 1.0))
            (setq found e))))))
  found)

;; 三通處理：在主管兩側加接頭，回傳支管側距離（不是三通則回傳 nil）
;;   bdir = 支管從交點往外的方向
(defun DP:tee (pt self bsize bdir / main mx msd mjt wh tv ang lay ds)
  (if (setq main (DP:findmain pt self))
    (progn
      (setq mx  (DP:xd main)
            msd (assoc (car mx) *DP-SYS*)
            mjt (nth 5 msd))
      (if (and mjt (setq wh (DP:jsize mjt (cadr mx) (caddr mx))))
        (progn
          (setq pt  (vlax-curve-getClosestPointTo main (list (car pt) (cadr pt) 0.0))
                tv  (DP:unit (vlax-curve-getFirstDeriv main (vlax-curve-getParamAtPoint main pt)))
                ang (angle '(0 0 0) tv)
                lay (DP:jlayer msd)
                ds  (if (= mjt "RING")
                      (DP:ringtee tv (DP:unit bdir) (caddr mx) bsize (cadr mx))
                      (DP:grvtee (caddr mx) bsize)))
          (if ds
            (progn
              ;; 雙斜梯 / 雙順水梯：主管接頭第一支支管已經加過
              (if (not (DP:otherbranch pt self main))
                (progn
                  (DP:layer lay (caddr msd) T)
                  (DP:collar (polar pt ang (car ds)) ang wh mjt lay)
                  (DP:collar (polar pt (+ ang pi) (cadr ds)) ang wh mjt lay)))
              (caddr ds))))))))

;; 沿中心線放接頭
(defun DP:joints (ent od size sysdat stee etee / jt wh lay step endon vs n i
                                               v0 v1 p0 p1 len ang s0 s1 f0 f1 d)
  (setq jt (nth 5 sysdat) wh (DP:jsize jt od size))
  (if wh
    (progn
      (setq lay (DP:jlayer sysdat) step (DP:step jt) endon (DP:endon jt)
            vs (DP:verts ent) n (length vs) i 0)
      (DP:layer lay (caddr sysdat) T)
      (while (< i (1- n))
        (setq v0 (nth i vs) v1 (nth (1+ i) vs))
        (if (equal (cadr v0) 0.0 1e-9)
          (progn
            (setq p0 (car v0) p1 (car v1) len (distance p0 p1) ang (angle p0 p1))
            ;; 起點
            (cond ((= i 0) (if stee (setq s0 stee f0 T) (setq s0 0.0 f0 endon)))
                  ((not (equal (cadr (nth (1- i) vs)) 0.0 1e-9)) (setq s0 0.0 f0 T))
                  (T (setq s0 (DP:allow jt od size
                                (DP:defl (angle (car (nth (1- i) vs)) p0) ang))
                           f0 T)))
            ;; 終點
            (cond ((= i (- n 2)) (if etee (setq s1 etee f1 T) (setq s1 0.0 f1 endon)))
                  ((not (equal (cadr v1) 0.0 1e-9)) (setq s1 0.0 f1 T))
                  (T (setq s1 (DP:allow jt od size
                                (DP:defl ang (angle p1 (car (nth (+ i 2) vs)))))
                           f1 T)))
            (if (> len (+ s0 s1 (cadr wh)))
              (progn
                (if f0 (DP:collar (polar p0 ang s0) ang wh jt lay))
                (if f1 (DP:collar (polar p0 ang (- len s1)) ang wh jt lay))
                (if (> step 0)
                  (progn
                    (setq d (+ s0 step))
                    (while (< d (- len s1 (cadr wh)))
                      (DP:collar (polar p0 ang d) ang wh jt lay)
                      (setq d (+ d step))))))
              (if (and f0 f1) (DP:collar (polar p0 ang (/ len 2.0)) ang wh jt lay)))))
        (setq i (1+ i))))
    (if (= jt "GROOVE") (princ "\n50A 以下視為牙接，不加機接。"))))

;; ================= DP 主程式 =================
(defun c:DP ( / *error* oldlay oldecho oldrad sys sysdat size od lastent ent obj d r stee etee)
  (defun *error* (msg)
    (if oldlay  (setvar "CLAYER" oldlay))
    (if oldrad  (setvar "FILLETRAD" oldrad))
    (if oldecho (setvar "CMDECHO" oldecho))
    (command-s "_.UNDO" "_End")
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*"))
      (princ (strcat "\n錯誤：" msg)))
    (princ))
  (setq oldlay (getvar "CLAYER") oldecho (getvar "CMDECHO") oldrad (getvar "FILLETRAD"))
  (setvar "CMDECHO" 0)
  (command "_.UNDO" "_Begin")

  ;; 系統
  (if (not *DP-last-sys*) (setq *DP-last-sys* "W"))
  (initget "W H D V F R")
  (setq sys (getkword (strcat "\n系統 [給水(W)/熱水(H)/排水(D)/通氣(V)/消防(F)/冷媒(R)] <"
                              *DP-last-sys* ">: ")))
  (if (not sys) (setq sys *DP-last-sys*))
  (setq *DP-last-sys* sys sysdat (assoc sys *DP-SYS*))

  ;; 管徑
  (if (not *DP-last-size*) (setq *DP-last-size* 100))
  (if (= (nth 4 sysdat) "CI")
    (princ "\n鑄鐵管徑：40(1½\") 50(2\") 80(3\") 100(4\") 125(5\") 150(6\") 200(8\") 250 300 375"))
  (initget 6)
  (setq size (getint (strcat "\n管徑 A <" (itoa *DP-last-size*) ">: ")))
  (if (not size) (setq size *DP-last-size*))
  (if (not (setq od (DP:od sysdat size)))
    (progn (initget 7)
           (setq od (getdist (strcat "\n表中沒有 " (itoa size) "A，請輸入外徑 (mm)：")))))
  (setq *DP-last-size* size)

  ;; 圖層
  (DP:layer *DP-CL* 8 nil)
  (DP:layer (cadr sysdat) (caddr sysdat) T)

  ;; 畫中心線
  (setvar "CLAYER" *DP-CL*)
  (setvar "PLINEWID" 0)
  (setq lastent (entlast))
  (princ (strcat "\n畫 " (nth 3 sysdat) " " (itoa size) "A 路徑（外徑 " (rtos od 2 2)
                 "），支管請從主管中心線開始畫"
                 (if (= (nth 5 sysdat) "RING") "，排水主管請順水流方向畫" "")
                 "，Enter 結束："))
  (setvar "CMDECHO" 1)
  (command "_.PLINE")
  (while (> (getvar "CMDACTIVE") 0) (command pause))
  (setvar "CMDECHO" 0)
  (setvar "CLAYER" oldlay)
  (setq ent (entlast))

  (if (and ent (not (equal ent lastent))
           (= (cdr (assoc 0 (entget ent))) "LWPOLYLINE"))
    (progn
      ;; 彎頭圓弧（有接頭的系統用型錄 D/CE，不做圓弧）
      (if (and (> *DP-elbow* 0) (not (nth 5 sysdat)))
        (progn (setvar "FILLETRAD" (* *DP-elbow* od))
               (command "_.FILLET" "_P" ent)
               (setvar "FILLETRAD" oldrad)))
      ;; 記錄系統、外徑、管徑
      (regapp "DPPIPE")
      (entmod (append (entget ent)
                      (list (list -3 (list "DPPIPE" (cons 1000 sys)
                                           (cons 1040 od) (cons 1070 size))))))
      ;; 偏移兩側管線
      (setq obj (vlax-ename->vla-object ent) d (/ od 2.0))
      (foreach s (list d (- d))
        (setq r (vl-catch-all-apply 'vla-Offset (list obj s)))
        (if (not (vl-catch-all-error-p r))
          (foreach o (vlax-safearray->list (vlax-variant-value r))
            (vla-put-Layer o (cadr sysdat)))))
      ;; 三通判斷 + 接頭
      (if (nth 5 sysdat)
        (progn
          (setq stee (DP:tee (vlax-curve-getStartPoint ent) ent size
                             (vlax-curve-getFirstDeriv ent (vlax-curve-getStartParam ent)))
                etee (DP:tee (vlax-curve-getEndPoint ent) ent size
                             (mapcar '- (vlax-curve-getFirstDeriv ent (vlax-curve-getEndParam ent)))))
          (if (or stee etee) (princ "\n偵測到三通，已在主管加接頭。"))
          (DP:joints ent od size sysdat stee etee)))
      (princ (strcat "\n完成：" (nth 3 sysdat) " " (itoa size) "A")))
    (princ "\n沒有畫出路徑，已取消。"))

  (command "_.UNDO" "_End")
  (setvar "CMDECHO" oldecho)
  (princ))

;; ================= DPR 彎頭半徑 =================
(defun c:DPR ( / r)
  (initget 4)
  (setq r (getreal (strcat "\n彎頭半徑 = 外徑 × 倍數（0 = 直角；排水、消防不適用）<"
                           (rtos *DP-elbow* 2 1) ">: ")))
  (if r (setq *DP-elbow* r))
  (princ))

;; ================= DPJ 手動加接頭 =================
(defun c:DPJ ( / sel ent mx sysdat jt wh pt d1)
  (while (setq sel (entsel "\n點管的【中心線】上要加接頭的位置（Enter 結束）："))
    (setq ent (car sel))
    (if (not (setq mx (DP:xd ent)))
      (princ "\n這條不是 DP 畫的中心線，請點中心線。")
      (progn
        (setq sysdat (assoc (car mx) *DP-SYS*)
              jt     (nth 5 sysdat)
              wh     (if jt (DP:jsize jt (cadr mx) (caddr mx))))
        (if (not wh)
          (princ "\n這支管沒有接頭（無接頭系統或 50A 以下牙接）。")
          (progn
            (setq pt (vlax-curve-getClosestPointTo ent (trans (cadr sel) 1 0))
                  d1 (vlax-curve-getFirstDeriv ent (vlax-curve-getParamAtPoint ent pt)))
            (DP:layer (DP:jlayer sysdat) (caddr sysdat) T)
            (DP:collar pt (angle '(0 0 0) d1) wh jt (DP:jlayer sysdat)))))))
  (princ))

;; ================= DPJS 接頭設定 =================
(defun DP:real (msg def / v)
  (initget 4)
  (setq v (getreal (strcat msg " <" (rtos def 2 2) ">: ")))
  (if v v def))
(defun DP:yn (msg def / k)
  (initget "Y N")
  (setq k (getkword (strcat msg " [是(Y)/否(N)] <" (if def "Y" "N") ">: ")))
  (cond ((= k "Y") T) ((= k "N") nil) (T def)))

(defun c:DPJS ( / k x)
  (initget "D F")
  (setq k (getkword "\n設定哪一種接頭 [排水壓環(D)/消防機接(F)] <D>: "))
  (if (= k "F")
    (progn
      (initget "X Y")
      (setq x (getkword (strcat "\n平面圖接頭寬度用 [接頭本體X(X)/含螺栓Y(Y)] <"
                                (nth 1 *DP-GRV*) ">: ")))
      (setq *DP-GRV*
        (list (DP:real "\n每支管長 mm（0 = 不加中間接頭）" (nth 0 *DP-GRV*))
              (if x x (nth 1 *DP-GRV*))
              (DP:yn "\n管端加接頭" (nth 2 *DP-GRV*)))))
    (setq *DP-RING*
      (list (DP:real "\n壓環每側外凸 mm" (nth 0 *DP-RING*))
            (DP:real "\n每支管長 mm（0 = 不加中間壓環）" (nth 1 *DP-RING*))
            (DP:real "\n型錄沒有的轉角/三通距離 = 外徑 ×" (nth 2 *DP-RING*))
            (DP:yn   "\n管端加壓環" (nth 3 *DP-RING*)))))
  (princ "\n設定完成（關閉 AutoCAD 後回到預設，要永久修改請改程式上方數值）。")
  (princ))

(princ "\n已載入：DP 畫管 / DPR 彎頭 / DPJ 加接頭 / DPJS 接頭設定")
(princ "\n  排水：ACENT 鑄鐵管 + 壓環　消防：金日 K01 機接")
(princ)
