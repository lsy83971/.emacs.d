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
   (when (display-graphic-p (or frame (selected-frame)))
     (let ((f (or frame (selected-frame))))
       (with-selected-frame f
         (setq-default line-height nil)
         (set-face-attribute 'default nil :family "Sarasa Fixed SC" :height 105 :background "#1a1b26")
         (dolist (charset '(han cjk-misc bopomofo kana hangul symbol))
           (set-fontset-font t charset (font-spec :family "Sarasa Fixed SC") nil 'prepend))
         (setq x-stretch-cursor t)))))
(add-hook 'server-after-make-frame-hook 'my/set-frame-font-setting)

;;(setq debug-on-error t)
;;(setq debug-on-error nil)
(defvar kinsoku-limit nil)

;;
;;------------------------------------------------------------
(setq make-backup-files nil)
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(require 'init-package)

;; need install rime-dev fcitx...
(unless (eq system-type 'darwin)
  (use-package popup :ensure t)
  (use-package rime
    :ensure t
    :custom
    (default-input-method "rime")
    (rime-show-candidate 'popup)
    :config
    (setq rime-title "中")
    (register-input-method "rime" "euc-cn" 'rime-activate rime-title)
    ;; popup 在窗口底部空间不足时向上弹出
    (defun my/rime-popup-auto-direction (orig-fn content)
      (let* ((lines (if (string-blank-p content) 0
                     (1+ (cl-count ?\n content))))
             (remaining (- (window-body-height)
                           (- (line-number-at-pos (point))
                              (line-number-at-pos (window-start)))))
             (rime-popup-properties
              (if (< remaining (+ lines 2))
                  (append (list :point (save-excursion
                                         (forward-line (- (1+ lines)))
                                         (point)))
                          rime-popup-properties)
                rime-popup-properties)))
        (funcall orig-fn content)))
    (advice-add 'rime--popup-display-content :around #'my/rime-popup-auto-direction)))
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
(require 'init-dirvish)
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
   '(anzu avy bazel bind-key chatgpt-shell claude-code command-log-mode
	  company-anaconda company-box company-web dash-functional
	  dashboard dired-subtree dirvish doom-modeline
	  electric-spacing elpy emmet-mode epc expand-region flycheck
	  fullframe git-commit gnu-elpa-keyring-update google-this
	  gptel helpful hungry-delete ivy-dired-history lsp-ui magit
	  modus-themes multiple-cursors no-littering nyan-mode
	  org-bullets ox-pandoc pkg-info projectile pyim
	  python-environment python-mode rainbow-delimiters rime
	  smartparens smex treemacs-all-the-icons undo-tree virtualenv
	  virtualenvwrapper visual-fill-column vterm vue-mode w3m
	  which-key xterm-color zenburn-theme zygospore))
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

;; undo-tree: 集中存放历史文件，不污染项目目录
(setq undo-tree-history-directory-alist '(("." . "~/.emacs.d/undo-tree-history/")))

;; 字体设置放在最末尾，确保不被 load-theme 等覆盖
(my/set-frame-font-setting)

