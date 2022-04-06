(require 'f)

;; lsy-frp find record path
(setq lsy-frp (f-join (f-full (getenv "HOME")) ".tmp_lsy_find_path"))
(defun lsy-find-append-mark (dir)
  (interactive "Dinput dir to record:")
  (f-append ((f-full concat dir) "\n") 'utf-8
   lsy-frp)
  )

(defun lsy-find-total-path ()
  (interactive)
  (set 'lsy-tmp-d (split-string (f-read-text lsy-frp 'utf-8) "\n"))
  )

(defun lsy-find-is-record (dir)
  (interactive "Dfind directory in record:")
  (let
      ((fd (f-full dir))
       (fr nil))
    (dolist (l1 lsy-tmp-d)
      (if (equal fd (f-full l1))
	    (setq fr t)
	))
    fr
    ))

(defun lsy-find-record-dir ()
  (interactive)
  (f-traverse-upwards
   (lambda (path)
     (lsy-find-is-record path))
   (buffer-name))
  )

(defun lsy-find (tmp1)
  (interactive "sexp:")
  (funcall 'rgrep tmp "*.*" (lsy-find-record-dir))
  )

(global-set-key (kbd "C-c C-f") 'lsy-find)
(provide 'init-rgrep)


  
