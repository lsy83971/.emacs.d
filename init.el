;;------------------------------------------------------------

(when (display-graphic-p)  ; 仅对图形界面生效
  (set-language-environment "UTF-8")
  (set-default-coding-systems 'utf-8)
  ;; 启用XIM输入协议，适配fcitx/ibus
  (setq default-input-method "xim")
  (toggle-input-method nil))  ; 初始化输入方法状态
;; 强制设置中文环境变量，解决图形界面继承不到的问题 
;; (global-unset-key (kbd "C-SPC"))
(setenv "LC_CTYPE" "zh_CN.UTF-8")
(setenv "XMODIFIERS" "@im=xim")
;;


(defun my/set-font ()
  (interactive)
  (set-face-attribute 'default nil
		    ;;:font "Sarasa Fixed SC"
		    :font "UbuntuMono"
		    :height 120)
  
  (dolist (charset '(kana han cjk-misc bopomofo))
      (set-fontset-font t charset
		    (font-spec
		     ;;:family "Noto Sans CJK SC"
		     ;;:family "UbuntuMono"
		     ;;:family "Sarasa Fixed SC"
		     :family "WenQuanYi Micro Hei Mono"
		     :size 12
		     )
		    )
  
      )
  (set-fontset-font t 'emoji
                  (font-spec :family "Noto Color Emoji" :size 12))
  )

(add-hook 'after-init-hook 'my/set-font)
;;(add-hook 'window-setup-hook 'my/set-font)
(when (daemonp)
  (add-hook 'server-after-make-frame-hook 'my/set-font))


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
   '(bazel treemacs-all-the-icons rime tango zenburn-theme modus-themes company-lsp lsp-ui flycheck projectile ox-pandoc w3m pyim rainbow-delimiters google-this popup vue-mode company-web company-web-html emmet-mode no-littering visual-fill-column org-bullets hydra command-log-mode python-mode f magit nyan-mode electric-spacing ace-jump-mode multiple-cursors fullframe smex ivy-dired-history ivy company-anaconda virtualenvwrapper virtualenv auto-complete-c-headers jedi ecb web-mode expand-region smartparens dash counsel swiper hungry-delete helm-company auto-complete function-args zygospore helm-gtags helm yasnippet ws-butler use-package undo-tree iedit dtrt-indent counsel-projectile company clean-aindent-mode anzu))
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



