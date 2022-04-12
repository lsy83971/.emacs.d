;;------------------------------------------------------------
;; python
;;------------------------------------------------------------

(defun setpy3 ()
  (interactive)
  (setq python-shell-interpreter "C:/Users/48944/AppData/Local/Programs/Python/Python39/pythonw.exe"))


;; (defun my:python-eval-line ()
;;     (interactive)
;;     (if (use-region-p)
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

