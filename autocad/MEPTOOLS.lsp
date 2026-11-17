;;=========================================================
;; MEPTOOLS.lsp  住宅機電複線圖工具
;;
;;  DP     畫複線管（排水 ACENT 壓環、消防金日 K01 機接）
;;  DPR    彎頭半徑
;;  DPJ    手動加接頭
;;  DPJS   接頭設定
;;  DPL    補標註（點中心線）
;;  DPLS   標註設定（開關、比例、字高）
;;  DPX    交叉自動斷線
;;  DPXS   斷線設定
;;  OUTSRC 另存外包用檔案（刪除中心線）
;;=========================================================

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
;; 銅管（冷媒）：輸入代號 → 外徑
;;   6=1/4"  10=3/8"  13=1/2"  16=5/8"  19=3/4"  22=7/8"  28=1-1/8"  35=1-3/8"  41=1-5/8"
(setq *DP-OD-CU*
  '((6 . 6.35) (10 . 9.52) (13 . 12.7) (16 . 15.88) (19 . 19.05)
    (22 . 22.22) (28 . 28.58) (35 . 34.92) (41 . 41.28)))
(setq *DP-INCH-CU*
  '((6 . "1/4\"") (10 . "3/8\"") (13 . "1/2\"") (16 . "5/8\"") (19 . "3/4\"")
    (22 . "7/8\"") (28 . "1-1/8\"") (35 . "1-3/8\"") (41 . "1-5/8\"")))

;; 不鏽鋼管（冷熱水）
;;   1" 以下：壓接管 JIS G3448（13Su / 20Su / 25Su）
;;   1" 以上：機接用不鏽鋼管，外徑同鋼管
(setq *DP-OD-SUS*
  '((13 . 15.88) (20 . 22.22) (25 . 28.58)
    (32 . 42.7) (40 . 48.6) (50 . 60.5) (65 . 76.3) (80 . 89.1)
    (100 . 114.3) (125 . 139.8) (150 . 165.2)))
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
;; 排水、汙水、雨水、通氣都是 CIP 鑄鐵管
(setq *DP-SYS*
  '(("W" "P-給水-管" 5  "給水" "SUS" "GROOVE")   ; 1" 以下壓接（不畫接頭），以上機接
    ("H" "P-熱水-管" 6  "熱水" "SUS" "GROOVE")
    ("D" "P-排水-管" 34 "排水" "CI"  "RING")
    ("S" "P-汙水-管" 32 "汙水" "CI"  "RING")
    ("Y" "P-雨水-管" 150 "雨水" "CI" "RING")   ; 雨水若用 PVC，改成 "PVC" nil
    ("V" "P-通氣-管" 3  "通氣" "CI"  "RING")
    ("F" "P-消防-管" 1  "消防" "STL" "GROOVE")
    ("R" "P-冷媒-管" 4  "冷媒" "CU"  nil)))

;; ================= 接頭設定 =================
;; 排水壓環：(每側外凸mm  管長mm  型錄沒有時的轉角/三通距離=外徑×  管端加)
(setq *DP-RING* '(10.0 3000.0 1.0 T))
;; 消防機接：(管長mm  平面寬度用"X"或"Y"  管端加)
(setq *DP-GRV*  '(6000.0 "X" T))

(setq *DP-CL* "P-中心線")
(if (not *DP-elbow*) (setq *DP-elbow* 0))

;; ================= 保溫 =================
;; (系統代號 . 保溫厚度mm)
(setq *DP-INS* '(("R" . 10.0) ("H" . 10.0)))

;; ================= 標註設定 =================
(if (not *DP-LBL*)   (setq *DP-LBL* "Y"))     ; 畫管時自動標註 Y/N
(if (not *DP-SCALE*) (setq *DP-SCALE* 50.0))  ; 出圖比例 1/50
(if (not *DP-TXH*)   (setq *DP-TXH* 2.5))     ; 出圖後字高 mm
(if (not *DP-SLOPE*) (setq *DP-SLOPE* 100))   ; 排水坡度預設 1/100
(setq *DP-PFX-D* "BOP")  ; 所有系統的高程前綴（管底）

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
                         ((= (nth 4 sysdat) "SUS") *DP-OD-SUS*)
                         ((= (nth 4 sysdat) "CU")  *DP-OD-CU*)
                         (T *DP-OD-PVC*)))))
(defun DP:jlayer (sysdat) (vl-string-subst "-接頭" "-管" (cadr sysdat)))
(defun DP:ks (size) (assoc size *DP-KS*))
(defun DP:step  (jt) (if (= jt "RING") (nth 1 *DP-RING*) (nth 0 *DP-GRV*)))
(defun DP:endon (jt) (if (= jt "RING") (nth 3 *DP-RING*) (nth 2 *DP-GRV*)))

;; 讀中心線上記錄的 (系統 外徑 管徑 高程 坡度)；舊管沒有高程、坡度
(defun DP:xd (ent / xd)
  (if (setq xd (cdr (assoc -3 (entget ent '("DPPIPE")))))
    (mapcar 'cdr (cdr (car xd)))))

;; 寫入中心線資料
(defun DP:setxd (ent sys od size el sl)
  (regapp "DPPIPE")
  (entmod (append (entget ent)
                  (list (list -3 (append (list "DPPIPE" (cons 1000 sys)
                                               (cons 1040 od) (cons 1070 size))
                                         (if el (list (cons 1040 el)))
                                         (if (and el sl) (list (cons 1071 sl)))))))))

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
    (if (= jt "GROOVE") (princ (strcat "\n" (DP:sizestr size) " 型錄沒有機接尺寸（壓接或牙接），不加接頭。")))))

;; ================= DP 主程式 =================
;; ================= 標註 =================
(defun DP:p3 (p) (list (car p) (cadr p) 0.0))
;; 管徑顯示成英吋：50 → 2"
(setq *DP-INCH*
  '((13 . "1/2\"") (15 . "1/2\"") (20 . "3/4\"") (25 . "1\"") (32 . "1-1/4\"")
    (40 . "1-1/2\"") (50 . "2\"") (65 . "2-1/2\"") (80 . "3\"") (100 . "4\"")
    (125 . "5\"") (150 . "6\"") (200 . "8\"") (250 . "10\"") (300 . "12\"")
    (375 . "15\"")))
(defun DP:sizestr (size)
  (cond ((cdr (assoc size *DP-INCH*))) (T (strcat (itoa size) "A"))))

;; 有坡度的系統（排水、汙水、雨水）
(defun DP:sloped (sys) (member sys '("D" "S" "Y")))
(defun DP:pfx (sys) *DP-PFX-D*)
;; 標註用管徑：冷媒用銅管英吋表
(defun DP:sizestr2 (size sys)
  (if (= sys "R")
    (cond ((cdr (assoc size *DP-INCH-CU*))) (T (DP:sizestr size)))
    (DP:sizestr size)))

(defun DP:elstr (v) (strcat (if (minusp v) "-" "+") (rtos (abs v) 2 0)))

;; 讓文字不會倒著讀：回傳 (旋轉角 是否翻轉)
(defun DP:readable (a)
  (setq a (rem (+ a (* 4 pi)) (* 2 pi)))
  (if (and (> a (+ (/ pi 2.0) 1e-6)) (<= a (+ (* 1.5 pi) 1e-6)))
    (list (+ a pi) T)
    (list a nil)))

;; 寫文字：v = 垂直對齊（1 = 底部置中，2 = 正中）
(defun DP:text (pt rot str h lay v)
  (entmake (list '(0 . "TEXT") (cons 8 lay) (cons 7 (getvar "TEXTSTYLE"))
                 (cons 10 (DP:p3 pt)) (cons 11 (DP:p3 pt)) (cons 40 h)
                 (cons 1 str) (cons 50 rot) '(72 . 1) (cons 73 v))))

;; 問高程（每個系統記住上次的值）
(defun DP:getel (sys / pfx def v)
  (setq pfx (DP:pfx sys)
        def (cdr (assoc sys *DP-EL*)))
  (if def
    (setq v (getreal (strcat "\n" pfx " 高程 mm（離地，排水為起點）<" (rtos def 2 0) ">: ")))
    (progn (initget 1)
           (setq v (getreal (strcat "\n" pfx " 高程 mm（離地，排水為起點）: ")))))
  (if (not v) (setq v def))
  (setq *DP-EL* (cons (cons sys v) (vl-remove-if '(lambda (x) (= (car x) sys)) *DP-EL*)))
  v)

(defun DP:getslope ( / v)
  (initget 6)
  (setq v (getint (strcat "\n坡度 1/ <" (itoa *DP-SLOPE*) ">: ")))
  (if v (setq *DP-SLOPE* v))
  *DP-SLOPE*)

;; 標註一支管
;;   標在最長直管段中間：2"汙水管 BOP+2400
;;   排水類另外標：管下方「i=1/100 →」，終點高程（依坡度算）
(defun DP:label (ent / mx sysdat od el sl lay h vs i v0 v1 len blen best
                       ang rr rot flip mid txt tl d pt a)
  (setq mx (DP:xd ent) sysdat (assoc (car mx) *DP-SYS*)
        od (+ (nth 1 mx) (* 2.0 (cond ((cdr (assoc (car mx) *DP-INS*))) (T 0.0))))  ; 含保溫，文字才不會壓到
        el (nth 3 mx) sl (nth 4 mx)
        lay (vl-string-subst "-標註" "-管" (cadr sysdat))
        h (* *DP-TXH* *DP-SCALE*))
  (DP:layer lay (caddr sysdat) T)
  ;; 找最長的直管段
  (setq vs (DP:verts ent) i 0 blen 0.0)
  (while (< i (1- (length vs)))
    (setq v0 (nth i vs) v1 (nth (1+ i) vs))
    (if (and (equal (cadr v0) 0.0 1e-9)
             (> (setq len (distance (car v0) (car v1))) blen))
      (setq blen len best (list (car v0) (car v1))))
    (setq i (1+ i)))
  (if best
    (progn
      (setq ang  (angle (car best) (cadr best))
            rr   (DP:readable ang) rot (car rr) flip (cadr rr)
            mid  (polar (car best) ang (/ blen 2.0))
            txt  (strcat (DP:sizestr2 (nth 2 mx) (car mx)) (nth 3 sysdat) "管 "
                         (DP:pfx (car mx)) (DP:elstr el)))
      ;; 管線上方：2"汙水管 BOP+2400
      (DP:text (polar mid (+ rot (/ pi 2.0)) (+ (/ od 2.0) (* h 0.5))) rot txt h lay 1)
      ;; 排水類：管線下方標坡度和流向，終點標高程（依坡度算）
      (if sl
        (progn
          (DP:text (polar mid (- rot (/ pi 2.0)) (+ (/ od 2.0) h)) rot
                   (strcat "i=1/" (itoa sl) " " (if flip "←" "→")) h lay 2)
          (setq tl (vlax-curve-getDistAtParam ent (vlax-curve-getEndParam ent))
                d  (min (* tl 0.15) (* h 6.0))
                pt (vlax-curve-getPointAtDist ent (- tl d))
                a  (angle '(0 0 0)
                     (vlax-curve-getFirstDeriv ent (vlax-curve-getParamAtPoint ent pt)))
                rr (DP:readable a))
          (DP:text (polar pt (- (car rr) (/ pi 2.0)) (+ (/ od 2.0) h))
                   (car rr) (strcat (DP:pfx (car mx)) (DP:elstr (- el (/ tl sl)))) h lay 2))))))

(defun c:DP ( / *error* oldlay oldecho oldrad sys sysdat size od lastent ent obj d r stee etee el sl ins)
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
  (initget "W H D S Y V F R")
  (setq sys (getkword (strcat "\n系統 [給水(W)/熱水(H)/排水(D)/汙水(S)/雨水(Y)/通氣(V)/消防(F)/冷媒(R)] <"
                              *DP-last-sys* ">: ")))
  (if (not sys) (setq sys *DP-last-sys*))
  (setq *DP-last-sys* sys sysdat (assoc sys *DP-SYS*))

  ;; 管徑
  (if (not *DP-last-size*) (setq *DP-last-size* 100))
  (if (= (nth 4 sysdat) "CI")
    (princ "\n鑄鐵管徑：40(1½\") 50(2\") 80(3\") 100(4\") 125(5\") 150(6\") 200(8\") 250 300 375"))
  (if (= (nth 4 sysdat) "CU")
    (princ "\n銅管代號：6(1/4\") 10(3/8\") 13(1/2\") 16(5/8\") 19(3/4\") 22(7/8\") 28(1-1/8\") 35(1-3/8\") 41(1-5/8\")"))
  (initget 6)
  (setq size (getint (strcat "\n管徑 A <" (itoa *DP-last-size*) ">: ")))
  (if (not size) (setq size *DP-last-size*))
  (if (not (setq od (DP:od sysdat size)))
    (progn (initget 7)
           (setq od (getdist (strcat "\n表中沒有 " (itoa size) "A，請輸入外徑 (mm)：")))))
  (setq *DP-last-size* size)

  ;; 高程、坡度（自動標註開啟時才問）
  (if (= *DP-LBL* "Y")
    (progn
      (setq el (DP:getel sys))
      (if (DP:sloped sys) (setq sl (DP:getslope)))))

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
      ;; 記錄系統、外徑、管徑、高程、坡度
      (DP:setxd ent sys od size el sl)
      ;; 偏移兩側管線
      (setq obj (vlax-ename->vla-object ent) d (/ od 2.0))
      (foreach s (list d (- d))
        (setq r (vl-catch-all-apply 'vla-Offset (list obj s)))
        (if (not (vl-catch-all-error-p r))
          (foreach o (vlax-safearray->list (vlax-variant-value r))
            (vla-put-Layer o (cadr sysdat)))))
      ;; 保溫外緣
      (if (setq ins (cdr (assoc sys *DP-INS*)))
        (progn
          (DP:layer (vl-string-subst "-保溫" "-管" (cadr sysdat)) (caddr sysdat) T)
          (foreach s (list (+ d ins) (- (+ d ins)))
            (setq r (vl-catch-all-apply 'vla-Offset (list obj s)))
            (if (not (vl-catch-all-error-p r))
              (foreach o (vlax-safearray->list (vlax-variant-value r))
                (vla-put-Layer o (vl-string-subst "-保溫" "-管" (cadr sysdat))))))))
      ;; 三通判斷 + 接頭
      (if (nth 5 sysdat)
        (progn
          (setq stee (DP:tee (vlax-curve-getStartPoint ent) ent size
                             (vlax-curve-getFirstDeriv ent (vlax-curve-getStartParam ent)))
                etee (DP:tee (vlax-curve-getEndPoint ent) ent size
                             (mapcar '- (vlax-curve-getFirstDeriv ent (vlax-curve-getEndParam ent)))))
          (if (or stee etee) (princ "\n偵測到三通，已在主管加接頭。"))
          (DP:joints ent od size sysdat stee etee)))
      ;; 標註
      (if el (DP:label ent))
      (princ (strcat "\n完成：" (nth 3 sysdat) " " (itoa size) "A")))
    (princ "\n沒有畫出路徑，已取消。"))

  (command "_.UNDO" "_End")
  (setvar "CMDECHO" oldecho)
  (princ))

;; ================= DPL 補標註（舊管或改過的管） =================
(defun c:DPL ( / sel ent mx el sl)
  (while (setq sel (entsel "\n點管的【中心線】加標註（Enter 結束）："))
    (setq ent (car sel))
    (if (not (setq mx (DP:xd ent)))
      (princ "\n這條不是 DP 畫的中心線，請點中心線。")
      (progn
        (setq el (nth 3 mx) sl (nth 4 mx))
        (if (not el)
          (progn
            (setq el (DP:getel (car mx)))
            (if (DP:sloped (car mx)) (setq sl (DP:getslope)))
            (DP:setxd ent (nth 0 mx) (nth 1 mx) (nth 2 mx) el sl)))
        (DP:label ent)
        (princ "\n已標註。"))))
  (princ))

;; ================= DPLS 標註設定 =================
(defun c:DPLS ( / k)
  (initget "Y N")
  (setq k (getkword (strcat "\n畫管時自動標註 [是(Y)/否(N)] <" *DP-LBL* ">: ")))
  (if k (setq *DP-LBL* k))
  (setq *DP-SCALE* (DP:real "\n出圖比例 1/" *DP-SCALE*)
        *DP-TXH*   (DP:real "\n出圖字高 mm" *DP-TXH*))
  (princ (strcat "\n圖面字高 = " (rtos (* *DP-SCALE* *DP-TXH*) 2 0)))
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
          (princ "\n這支管沒有接頭（無接頭系統，或型錄沒有這個管徑的機接）。")
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

;;#########################################################
;; 第二部分：DPX 交叉斷線
;;#########################################################
;;=========================================================
;; DPX  ：交叉自動斷線（上層管連續，下層管在交叉處斷開）
;; DPXS ：設定處理方式（斷開 / 虛線）與斷線間隙
;;=========================================================

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

;;#########################################################
;; 第三部分：OUTSRC 另存外包用檔案
;;#########################################################
;;=========================================================
;; OUTSRC ：另存「-外包用」檔案，並刪除中心線圖層
;;          目前開著的工作檔不受影響
;;=========================================================

(defun c:OUTSRC ( / lay src dst ver dbx lst cnt lyr)
  (setq lay *DP-CL*)               ; 中心線圖層（在檔案上方 *DP-CL* 修改）

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

(princ "\n已載入 MEPTOOLS：DP / DPR / DPJ / DPJS / DPL / DPLS / DPX / DPXS / OUTSRC")
(princ)
