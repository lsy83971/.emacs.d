(setq package-check-signature nil)
;; macOS: Command ↔ Option 互换
(when (eq system-type 'darwin)
  (defun my/swap-command-option ()
    "Swap Command and Option keys on macOS."
    (interactive)
    (setq mac-command-modifier 'meta)
    (setq mac-option-modifier 'super)
    (message "Command=Meta, Option=Super"))
  (my/swap-command-option))
(setq inhibit-compacting-font-caches t)
(defun my/set-frame-font-setting (&optional frame)
   (setq-default line-height nil)
   (set-face-attribute 'default nil :font "Sarasa Fixed SC" :height 120)
   ;; 固定行高为字体高度，不随内容变化
   (setq x-stretch-cursor t)
 )
(add-hook 'server-after-make-frame-hook 'my/set-frame-font-setting)
(add-hook 'after-init-hook 'my/set-frame-font-setting)

;;(setq debug-on-error t)
;;(setq debug-on-error nil)
(defvar kinsoku-limit nil)

;; need install rime-dev fcitx...
(unless (eq system-type 'darwin)
  (use-package popup :ensure t)
  (use-package rime
    :ensure t
    :custom
    (default-input-method "rime")
    (rime-show-candidate 'popup)
    :bind
    ))

;;(setq rime-show-candidate 'minibuffer)


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
(require 'init-minimax)
(require 'window-layout)

;; ansi-term char mode 下直接使用 Emacs 复制粘贴
(with-eval-after-load 'term
  (define-key term-raw-map (kbd "C-y") 'term-paste)
  (define-key term-raw-map (kbd "M-w") 'kill-ring-save))
(require 'init-python)
(require 'init-rgrep)
(require 'init-c)
(when
  (string-equal system-type "windows-nt")
  (require 'init-cygwin)
  )

;; 启动后空闲 3 秒，后台异步 pull 最新配置
;; (run-with-idle-timer 3 nil
;;   (lambda ()
;;     (let ((default-directory user-emacs-directory))
;;       (start-process "emacs-config-git-pull" nil "git" "pull" "--rebase"))))

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

;; 以后更新词库，只需
;; cd /tmp/rime-ice && git pull
;; cp *.yaml /root/.emacs.d/rime/
;; cp -r cn_dicts en_dicts opencc lua /root/.emacs.d/rime/
;; # 然后 M-x rime-deploy                                                                                                

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
   '(avy anzu bazel bind-key
		   chatgpt-shell claude-code command-log-mode
		   company-anaconda company-box company-web
		   dash-functional doom-modeline electric-spacing elpy
		   emmet-mode epc expand-region flycheck fullframe
		   git-commit gnu-elpa-keyring-update google-this
		   gptel helpful hungry-delete ivy-dired-history
		   lsp-ui magit modus-themes multiple-cursors
		   no-littering nyan-mode org-bullets ox-pandoc
		   pkg-info projectile pyim python-environment
		   python-mode rainbow-delimiters rime smartparens
		   smex treemacs-all-the-icons undo-tree virtualenv
		   virtualenvwrapper visual-fill-column vterm vue-mode
		   w3m which-key xterm-color zenburn-theme zygospore))
 '(package-vc-selected-packages 'nil)
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



