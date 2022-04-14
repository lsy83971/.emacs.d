(use-package ace-jump-mode)
(global-set-key (kbd "C-4" ) 'ace-jump-mode)

(use-package multiple-cursors
  :bind
  (("C->" . mc/mark-next-like-this)
   ("C-<" . mc/mark-previous-like-this)
   ("C-c C-<" . mc/mark-all-like-this)
   )
  )



(defun lsy:copy-file-name()
  "put current file name in the killing ring"
  (interactive)
  (kill-new (buffer-file-name))
  )

(defun lsy-kill ()
  (interactive)
  (if (region-active-p)
      (call-interactively #'kill-ring-save) ;; then
      (kill-ring-save (line-beginning-position) (line-end-position))
      ))

(defun lsy-kill-region ()
  (interactive)
  (if (region-active-p)
      (call-interactively #'kill-region) ;; then
      (kill-region (line-beginning-position) (line-end-position))
      ))


(defun lsy-yank ()
  (interactive)
  (if (region-active-p)
      (progn
	(delete-region (region-beginning) (region-end))
	(call-interactively #'yank)	
       )
      (call-interactively #'yank) ;; then
      ))

(defun insert-split-line ()
  (interactive)
  (save-restriction
    (narrow-to-region (line-beginning-position) (line-end-position))
    (goto-char (point-min))
    (setq a (re-search-forward "[^ ]" nil t))
    (if (null a)
        (progn
          (goto-char (point-min))
          (delete-char (- (point-max) (point-min)))
          (insert "-----------------------------------------------------------------"))
      (progn
        (goto-char (point-min))
        (insert "-----------------------------------------------------------------\n")))))



(global-set-key (kbd "<f7>" ) 'lsy:copy-file-name)
(global-set-key (kbd "M-w" ) 'lsy-kill)
(global-set-key (kbd "C-w" ) 'lsy-kill-region)
(global-set-key (kbd "C-y" ) 'lsy-yank)




(global-set-key (kbd "S-<left>" ) 'windmove-left)
(global-set-key (kbd "S-<right>" ) 'windmove-right)
(global-set-key (kbd "S-<up>" ) 'windmove-up)
(global-set-key (kbd "S-<down>" ) 'windmove-down)



(provide 'init-nav)
