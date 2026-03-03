(setq package-check-signature nil)
;;(defun my/set-font ()
;;  (interactive)
;;  (set-face-attribute 'default nil
;;                      :font "Sarasa Fixed SC"
;;                      :height 120)
;;  (setq-default line-spacing 0))
;;(add-hook 'after-init-hook 'my/set-font)

(setq inhibit-compacting-font-caches t)
(add-hook 'after-init-hook
          (lambda ()
            (setq-default line-height nil)
            (set-face-attribute 'default nil :font "Sarasa Fixed SC" :height 120)
            ;; 固定行高为字体高度，不随内容变化
            (setq x-stretch-cursor t)))

;;(setq debug-on-error t)
;;(setq debug-on-error nil)


;; need install rime-dev fcitx...
(use-package rime
  :ensure t
  :custom
  (default-input-method "rime")
  (rime-show-candidate 'minibuffer)
  :bind
  )




;;
;;------------------------------------------------------------
(setq make-backup-files nil)
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(require 'init-package)
(require 'init-company)
(require 'init-ui)
(require 'init-ivy)
(require 'init-html)
(require 'init-keymap)
(require 'init-nav)
(require 'init-tool)
(require 'init-org)
(require 'init-local)
(require 'init-gpt)
(require 'init-claude)
(require 'init-python)
(require 'init-rgrep)
(require 'init-c)
(when
  (string-equal system-type "windows-nt")
  (require 'init-cygwin)
  )

;;(add-to-list 'load-path "~/.emacs.d/custom")

;;(use-package zenburn-theme
;;  :ensure t
;;  :config
;;  (load-theme 'zenburn t))

(use-package all-the-icons
  :ensure t
  :if (display-graphic-p)
  :config
  ;; 确保字体已安装
  (unless (find-font (font-spec :name "all-the-icons"))
    (all-the-icons-install-fonts t))
  
  ;; 用于 treemacs
  (use-package treemacs-all-the-icons
    :ensure t
    :after (treemacs all-the-icons)
    :config
    (treemacs-load-theme "all-the-icons")))

(load-theme 'tango)

(add-hook 'kill-emacs-hook
          (lambda ()
            ;; 1. 先关输入法
            (ignore-errors (deactivate-input-method))
            ;; 2. 再显式 finalize，让 rime 自己清理
            (ignore-errors (rime-lib-finalize))
            ;; 3. 把所有 rime 相关 timer 清掉
            (ignore-errors
              (dolist (timer timer-list)
                (when (string-match-p "rime"
                        (format "%s" (timer--function timer)))
                  (cancel-timer timer)))))
          -101)
;;(add-hook 'kill-emacs-query-functions
;;          (lambda ()
;;            (when current-input-method
;;              (deactivate-input-method))
;;            t)
;;          nil t)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(company-show-quick-access t nil nil "Customized with use-package company")
 '(dired-dwim-target t)
 '(elpy-modules nil)
 '(elpy-rpc-python-command "python3")
 '(package-selected-packages
   '(ace-jump-mode anzu auto-complete auto-complete-c-headers bazel
		   claude-code clean-aindent-mode command-log-mode
		   company company-anaconda company-lsp company-web
		   company-web-html counsel counsel-projectile dash
		   dtrt-indent ecb electric-spacing emmet-mode
		   expand-region f flycheck fullframe function-args
		   gnu-elpa-keyring-update google-this gptel helm
		   helm-company helm-gtags hungry-delete hydra iedit
		   inheritenv ivy ivy-dired-history jedi lsp-ui magit
		   modus-themes multiple-cursors no-littering
		   nyan-mode org-bullets ox-pandoc popup projectile
		   pyim python-mode rainbow-delimiters rime
		   smartparens smex swiper tango
		   treemacs-all-the-icons undo-tree virtualenv
		   virtualenvwrapper visual-fill-column vterm vue-mode
		   w3m web-mode ws-butler yasnippet zenburn-theme
		   zygospore))
 '(package-vc-selected-packages
   '((claude-code :url "https://github.com/stevemolitor/claude-code.el")))
 '(python-shell-completion-native-enable nil)
 '(warning-suppress-log-types '((comp) (comp)))
 '(warning-suppress-types '((comp))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(company-tooltip ((t nil)))
 '(company-tooltip-selection ((t (:extend t :background "tomato"))))
 '(org-level-1 ((t (:weight bold :height 1.2)))))

(put 'upcase-region 'disabled nil)
(put 'downcase-region 'disabled nil)



