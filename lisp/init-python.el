
;;(elpy-enable)
;;(elpy-disable)
;;(elpy-shell-send-region-or-buffer)
;;(elpy-shell-send-region-or-buffer)
;;------------------------------------------------------------
;; python
;;------------------------------------------------------------
;;(defun setpy3 ()
;;；；  (interactive)
;;；；  (setq python-shell-interpreter "C:/Users/48944/AppData/Local/Programs/Python/Python39/pythonw.exe")
;;；；         python-shell-prompt-regexp "In \\[[0-9]+\\]: "
;;；；         python-shell-prompt-output-regexp "Out\\[[0-9]+\\]: ")
;;；；  
;;；；  )



; (defun lsy-python-eval-line ()
;;     (interactive)
;;     (if(use-region-p)
;;         (elpy-shell-send-region-or-buffer)
;;       (let (p1 p2)
;;         (setq p1 (line-beginning-position))
;;         (setq p2 (line-end-position))
;;         (goto-char p1)
;;         (push-mark p2)
;;         (setq mark-active t)
;;         (elpy-shell-send-region-or-buffer)
;;         (goto-char p2)
;;         (setq mark-active nil)
;;         )))

;; if it was an expression, it has been removed; now evaluate it

(defun lsy-python-eval-line ()
  (interactive)
  (setq w (selected-window) p (point))
  (run-python)
  (end-of-buffer)  
  (setq ws (selected-window) ps (point))  
  (select-window w)
  (goto-char p)
  (let (p1 p2)
    (if (use-region-p)
 	(setq p1 (region-beginning) p2 (region-end))
      (setq p1 (line-beginning-position) p2 (line-end-position))
      )
    (setq tmp-string (buffer-substring p1 p2))
    ;;(message tmp-string)    
    (setq tmp-body
	  (concat
	   "# -*- coding: utf-8 -*-\n"
	   "import sys, codecs, os, ast;\n"
	   "print('\\\n')\n"
	   "print('input:')\n"	   
	   "__code='''\n"
	   tmp-string
	   "'''\n"
	   "print('''"
	   tmp-string
	   "''')\n"
	   "__block = ast.parse(__code, '''tmp''', mode='exec');\n"
	   "__last = __block.body[-1];\n" ;; the last statement
	   "__isexpr = isinstance(__last,ast.Expr);\n" ;; is it an expression?
	   "_ = __block.body.pop() if __isexpr else None;\n" ;; if so, remove it
	   "exec(compile(__block, '''tmp''', mode='exec'));\n" ;; execute everything else
	   "output=eval(compile(ast.Expression(__last.value), '''tmp''', mode='eval')) if __isexpr else None\n"
	   "print('''output:\\\n''')\n"
	   "_=print(output) if __isexpr else None\n"
	   )
	  )
    ;;(message tmp-body)
    (python-shell-send-string tmp-body)
    )
  (select-window w)
  (setq mark-active nil)
  )

(use-package electric-spacing)

(use-package python-mode
  :after lsp-mode
  :hook
  (python-mode . (lambda ()
                   (lsp-deferred)
		   (electric-spacing-mode)
		   (setq-local electric-spacing-operators '(?= ?< ?> ?% ?+ ?- ?* ?/ ?& ?| ?: ?? ?, ?~ ?. ?^ ?\; ?!))		   
		   )
	       
	       )
  :ensure t
  :custom(
	  ;;(python-shell-interpreter "C:/Users/48944/AppData/Local/Programs/Python/Python39/python.exe")
	  

	  (python-shell-prompt-regexp "In \\[[0-9]+\\]: ")
	  (python-shell-prompt-output-regexp "Out\\[[0-9]+\\]: ")
	  )
  :bind
  (:map python-mode-map
	("C-r" . lsy-python-eval-line)
	("M-." . lsp-find-definition)
	("M-," . xref-pop-marker-stack)
	)
  :config
  (setq read-process-output-max (* 1024 1024))
  (setq gc-cons-threshold (eval-when-compile (* 1024 1024 1024)))
  (if (string-equal system-type "windows-nt")
      (setq python-shell-interpreter "ipython")
    (setq python-shell-interpreter "python3")
    )
  )



(use-package company
  :after lsp-mode
  :hook (lsp-mode . company-mode)
  :bind (:map company-active-map
         ("<tab>" . company-complete-selection))
        (:map lsp-mode-map
         ("<tab>" . company-indent-or-complete-common))
  :custom
  (company-minimum-prefix-length 1)
  (company-idle-delay 0.0))

(use-package company-box
  :hook (company-mode . company-box-mode))

(defun baal-setup-lsp-company ()
  (setq-local company-backends
	      '(company-capf
		company-dabbrev
		company-dabbrev-code
		;;company-files
		)))
(add-hook 'lsp-completion-mode-hook #'baal-setup-lsp-company)				        ;;

;; 												        ;;

(setq company-idle-delay 0.35 ;; How long to wait before popping up				        ;;
      company-minimum-prefix-length 2 ;; Show the menu after one key press			        ;;
      company-tooltip-limit 15 ;; Limit on how many options to display			        ;;
      company-show-numbers t   ;; Show numbers behind options				        ;;
      company-tooltip-align-annotations t ;; Align annotations to the right			        ;;
      company-require-match nil           ;; Allow free typing				        ;;
      company-selection-wrap-around t ;; Wrap around to beginning when you hit bottom of suggestions ;;
      company-dabbrev-ignore-case t ;; Don't ignore case when completing			        ;;
      company-dabbrev-downcase t ;; Don't automatically downcase completions			        ;;
      )											        ;;
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

;; (add-hook
;;  'python-mode-hook


(provide 'init-python)

