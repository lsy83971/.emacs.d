;;------------------------------------------------------------
(set-face-attribute
 'default nil :family "source Code Pro" :height 100 :weight 'semi-bold)

;; Chinese Font 配置中文字体
;;(dolist (charset '(kana han symbol cjk-misc bopomofo))
;;  (set-fontset-font (frame-parameter nil 'font)
;;                    charset
;;                    (font-spec :family "Microsoft YaHei" :size 13)))

;;------------------------------------------------------------
(require 'package)
(setq package-archives '(("gnu"   . "http://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
                         ("melpa" . "http://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))


(defun require-package (package &optional min-version no-refresh)
  "Install given PACKAGE, optionally requiring MIN-VERSION.
If NO-REFRESH is non-nil, the available package lists will not be
re-downloaded in order to locate PACKAGE."
  (if (package-installed-p package min-version)
      t
    (if (or (assoc package package-archive-contents) no-refresh)
        (package-install package)
      (progn
        (package-refresh-contents)
        (require-package package min-version t)))))

(package-initialize)
(setq make-backup-files nil)
(when (not package-archive-contents)
    (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

(add-to-list 'load-path "~/.emacs.d/custom")


(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ansi-color-names-vector
   ["#2e3436" "#a40000" "#4e9a06" "#c4a000" "#204a87" "#5c3566" "#729fcf" "#eeeeec"])
 '(custom-enabled-themes '(deeper-blue))
 '(package-selected-packages
   '(f magit nyan-mode electric-spacing ace-jump-mode multiple-cursors fullframe smex ivy-dired-history ivy company-anaconda virtualenvwrapper virtualenv auto-complete-c-headers jedi ecb elpy web-mode expand-region smartparens dash counsel swiper hungry-delete helm-company auto-complete function-args zygospore helm-gtags helm yasnippet ws-butler volatile-highlights use-package undo-tree iedit dtrt-indent counsel-projectile company clean-aindent-mode anzu)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(org-level-1 ((t (:weight bold :height 1.2)))))

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(when
  (string-equal system-type "windows-nt")
  (require 'init-cygwin)
)
(require 'init-company)
;;(require 'init-smex)
;;(require 'init-exec)
;;(require 'init-c)

;;(require 'init-sessions)
(require 'init-local)
(require 'init-python)
(require 'init-org)
(require 'init-rgrep)
