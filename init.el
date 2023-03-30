;;------------------------------------------------------------
;;(set-face-attribute
;; 'default nil :family "source Code Pro" :height 120 :weight 'normal)

;;(set-face-attribute
;; 'default nil :family "ubuntu mono" :height 110 :weight 'normal)
(global-unset-key (kbd "C-SPC"))
(set-face-attribute
 'default nil :family "UbuntuMono" :height 120 :weight 'normal)

;; Chinese Font 配置中文字体
;;(dolist (charset '(kana han symbol cjk-misc bopomofo))
;;  (set-fontset-font (frame-parameter nil 'font)
;;                    charset
;;                    (font-spec :family "Microsoft YaHei" :size 13)))
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
(when
  (string-equal system-type "windows-nt")
  (require 'init-cygwin)
  )

;;(add-to-list 'load-path "~/.emacs.d/custom")
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(company-show-quick-access t nil nil "Customized with use-package company")
 '(custom-enabled-themes '(deeper-blue))
 '(dired-dwim-target t)
 '(elpy-modules nil)
 '(elpy-rpc-python-command "python3")
 '(package-selected-packages
   '(google-this popup vue-mode company-web company-web-html emmet-mode no-littering visual-fill-column org-bullets hydra command-log-mode python-mode f magit nyan-mode electric-spacing ace-jump-mode multiple-cursors fullframe smex ivy-dired-history ivy company-anaconda virtualenvwrapper virtualenv auto-complete-c-headers jedi ecb web-mode expand-region smartparens dash counsel swiper hungry-delete helm-company auto-complete function-args zygospore helm-gtags helm yasnippet ws-butler use-package undo-tree iedit dtrt-indent counsel-projectile company clean-aindent-mode anzu))
 '(python-shell-completion-native-enable nil))
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
