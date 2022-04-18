(use-package ivy
  :diminish
  :bind (("C-s" . swiper)
	 ("C-c r" . counsel-recentf)
         :map ivy-minibuffer-map
         ("TAB" . ivy-alt-done)
         ("C-l" . ivy-alt-done)
         ("C-n" . ivy-next-line)
         ("C-p" . ivy-previous-line)
         :map ivy-switch-buffer-map
         ("C-p" . ivy-previous-line)
         ("C-l" . ivy-done)
         ("C-d" . ivy-switch-buffer-kill)
         :map ivy-reverse-i-search-map
         ("C-k" . ivy-previous-line)
         ("C-d" . ivy-reverse-i-search-kill)
	 )
  :config
  (ivy-mode 1)
  (setq ivy-use-selectable-prompt t)
  )





;; (use-package ivy-rich
;;   :init
;;   (ivy-rich-mode 1))

(use-package counsel
  :bind (("C-M-j" . 'counsel-switch-buffer)
         :map minibuffer-local-map
         ("C-r" . 'counsel-minibuffer-history))
  :custom
  (counsel-linux-app-format-function #'counsel-linux-app-format-function-name-only)
  :config
  (counsel-mode 1))


(use-package helpful
  :custom
  (counsel-describe-function-function #'helpful-callable)
  (counsel-describe-variable-function #'helpful-variable)
  :bind
  ([remap describe-function] . counsel-describe-function)
  ([remap describe-command] . helpful-command)
  ([remap describe-variable] . counsel-describe-variable)
  ([remap describe-key] . helpful-key))



;; (global-set-key (kbd "C-s") 'swiper)
;; (global-set-key (kbd "M-x") 'counsel-M-x)
;; (global-set-key (kbd "C-x C-f") 'counsel-find-file)

;; (global-set-key (kbd "C-x b") 'counsel-switch-buffer)


;; (global-set-key (kbd "<f5>") 'comment-or-uncomment-region)
;; (global-set-key (kbd "<f6>") 'indent-region)
;; (global-set-key (kbd "C-x <return> -") 'insert-split-line)
;; (global-set-key (kbd "C-SPC") 'nil)

(provide 'init-ivy)
