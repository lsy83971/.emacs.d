(require 'subr-x)
;;(global-hungry-delete-mode nil)
(defun lsy-python-shell-insert-string (s)
  (let* ((process (python-shell-get-process-or-error)))
    (with-current-buffer (process-buffer process)
      (save-excursion
        (goto-char (process-mark process))
        ;;(insert-before-markers "\n... ")
	(insert-before-markers s)
	))

    )
  )

(defun lsy-python-eval-line ()
  (interactive)
  (let* (
	 (window (selected-window))
	 )
    (elpy-shell--ensure-shell-running)
    ;; TODO
    ;; NOT UPDATE completion-at-point-function
    (defun company--capf-data-real ()
      (cl-letf* (((default-value 'completion-at-point-functions)
		  ;; Ignore tags-completion-at-point-function because it subverts
		  ;; company-etags in the default value of company-backends, where
		  ;; the latter comes later.
		  (remove 'tags-completion-at-point-function
			  (default-value 'completion-at-point-functions)))
		 (completion-at-point-functions (company--capf-workaround))
		 (data (run-hook-wrapped 'completion-at-point-functionsa
					 ;; Ignore misbehaving functions.
					 #'completion--capf-wrapper 'optimist)))
	(when (and (consp (cdr data)) (integer-or-marker-p (nth 1 data))) data)))
    (if(use-region-p)
	(let* ((p1 (region-beginning))
	       (p2 (region-end))
	       (p3 (line-beginning-position))
	       (p4 (line-end-position))
	       (tmp-string (buffer-substring p1 p2))
	       (tmp-string (string-trim  tmp-string))
	       ;;(tmp-string (string-replace "\\" "\\\\" tmp-string))
	       )
	  (if (and (<= p2 p4) (>= p1 p3))
	      (progn
		(lsy-python-shell-insert-string tmp-string)
		(python-shell-send-string tmp-string)
		)
	    (elpy-shell-send-region-or-buffer)
	    ))
      (let* ((p1 (line-beginning-position))
	     (p2 (line-end-position))
	     (tmp-string (buffer-substring p1 p2))
	     ;;(tmp-string (string-replace "\\" "\\\\" tmp-string))
	     (tmp-string (string-trim  tmp-string))
	     )
	(progn
	  (lsy-python-shell-insert-string tmp-string)
	  (python-shell-send-string tmp-string)
	  )
	))

    (select-window window)
    )
  )


(use-package electric-spacing)
(use-package elpy)
;;(company--capf-data-real)
;;(company--capf-data)
(use-package python-mode
  :hook
  (
   (python-mode
    .
    (lambda ()
      (hs-minor-mode t)
      (electric-spacing-mode)
      (setq-local electric-spacing-operators
		  '(?= ?< ?> ?% ?+ ?- ?* ?/ ?& ?| ?: ?? ?, ?~ ?. ?^ ?\; ?!))
      (elpy-enable)
      (setq-local company-backends (cons 'elpy-company-backend company-backends))
      (company-mode 1)
      ))
   )
  
  :ensure t
  :custom(
	  (python-shell-prompt-regexp "In \\[[0-9]+\\]: ")
	  (python-shell-prompt-output-regexp "Out\\[[0-9]+\\]: ")
	  (python-shell-interpreter "python3")
	  )
  :bind
  (:map python-mode-map
	("C-r" . lsy-python-eval-line)
	("M-," . xref-pop-marker-stack)
	("C-<up>" . python-nav-backward-defun)
	("C-<down>" . python-nav-forward-defun)
	("C-<down>" . python-nav-forward-defun)
	("C-<tab>" . hs-toggle-hiding)			
	)
  :config
  (setq read-process-output-max (* 1024 1024))
  (setq gc-cons-threshold (eval-when-compile (* 1024 1024 1024)))
  (if (string-equal system-type "windows-nt")
      (setq python-shell-interpreter "ipython")
    (setq python-shell-interpreter "python3")
    )
  )

(provide 'init-python)


