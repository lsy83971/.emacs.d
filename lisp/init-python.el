(require 'subr-x)

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
  (elpy-shell--ensure-shell-running)
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
      )))


(use-package electric-spacing)
(use-package elpy)
;;(company--capf-data-real)
;;(company--capf-data)
(use-package python-mode
  :hook
  (python-mode . (lambda ()
		   (electric-spacing-mode)
		   ;;(company-mode t)		   
		   (setq-local electric-spacing-operators
			       '(?= ?< ?> ?% ?+ ?- ?* ?/ ?& ?| ?: ?? ?, ?~ ?. ?^ ?\; ?!))
		   (elpy-enable)
		   (add-to-list 'company-backends 'elpy-company-backend)
		   )
	       
	       
	       )
  :ensure t
  :custom(
	  ;;(python-shell-interpreter "C:/Users/48944/AppData/Local/Programs/Python/Python39/python.exe")
	  

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
	)
  :config
  (setq read-process-output-max (* 1024 1024))
  (setq gc-cons-threshold (eval-when-compile (* 1024 1024 1024)))
  
  
  (if (string-equal system-type "windows-nt")
      (setq python-shell-interpreter "ipython")
    (setq python-shell-interpreter "python3")
    )
  )


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (defun my:hide-or-show ()
;;   (interactive)
;;   (if (hs-already-hidden-p) (hs-show-block) (hs-hide-block))
;;   )


;; (add-hook
;;  'python-mode-hook
;;  (lambda ()

;;    (add-to-list 'process-coding-system-alist '("python" . (utf-8 . utf-8)))
;;    (add-to-list 'process-coding-system-alist '("elpy" . (utf-8 . utf-8)))
;;    (add-to-list 'process-coding-system-alist '("flake8" . (utf-8 . utf-8)))
;;    (setenv "PYTHONIOENCODING" "utf-8")
;;    ;;(remove-hook 'elpy-modules 'elpy-module-flymake)
;;    (hs-minor-mode)
;; ;;   (require 'jedi)
;; ;;   (jedi:setup)
;; ;;   (setq jedi:complete-on-dot t)
;;    (setq python-shell-interpreter "C:/Users/48944/AppData/Local/Programs/Python/Python39/pythonw.exe"
;;          python-shell-interpreter-args "-i"
;;          python-shell-prompt-regexp "In \\[[0-9]+\\]: "
;;          python-shell-prompt-output-regexp "Out\\[[0-9]+\\]: ")

;;    (elpy-enable)   
;;    ;;(setq elpy-rpc-python-command "C:/Users/48944/AppData/Local/Programs/Python/Python39/pythonw.exe")   
   
;; ;;   (setq jedi:server-args
;; ;;         '(
;; ;;           "--sys-path" "/usr/local/lib/python3.6/dist-packages"
;; ;;           ;;"--sys-path" "/usr/lib/python3/dist-packages"
;; ;;           ;;"--sys-path" "/home/lsy/Project/model_vision"
;; ;;           )
;; ;;	 )
;;    ;;   (setq elpy-rpc-backend "jedi")

;;    (setq python-indent-offset 4)
;;    (electric-spacing-mode 1)
;;    (defvar electric-spacing-operators '(?= ?< ?> ?% ?+ ?- ?* ?/ ?& ?| ?: ?? ?, ?~ ?. ?^ ?\; ?!))
;;    ;; need to change electric-spacing.el delete ?/(
;;    (company-mode)
;;    ;;(require 'auto-complete-config)
;;    ;;(ac-config-default)
;;    (local-set-key (kbd "C-r") 'my:python-eval-line)
;;    (local-set-key (kbd "<f2>") 'my:hide-or-show)
;;    (local-set-key (kbd "M-.") 'jedi:goto-definition)
;;    (local-set-key (kbd "M-,") 'jedi:goto-definition-pop-marker)
;;     ))


(provide 'init-python)
