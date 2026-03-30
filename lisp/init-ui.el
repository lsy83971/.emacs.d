(use-package no-littering)
;; no-littering doesn't set this by default so we must place
;; auto save files in the same path as it uses for sessions
(setq auto-save-file-name-transforms
      `((".*" ,(no-littering-expand-var-file-name "auto-save/") t)))

(setq inhibit-startup-message t)

(scroll-bar-mode -1)        ; Disable visible scrollbar
(tool-bar-mode -1)          ; Disable the toolbar
(tooltip-mode -1)           ; Disable tooltips
(set-fringe-mode 10)        ; Give some breathing room
(menu-bar-mode -1)            ; Disable the menu bar

(setq visible-bell t)

(column-number-mode)
(global-display-line-numbers-mode t)

;; Set frame transparency
;; Make frame transparency overridable
(defvar efs/default-font-size 180)
(defvar efs/default-variable-font-size 180)
(defvar efs/frame-transparency '(90 . 90))

(set-frame-parameter (selected-frame) 'alpha efs/frame-transparency)
(add-to-list 'default-frame-alist `(alpha . ,efs/frame-transparency))
(set-frame-parameter (selected-frame) 'fullscreen 'maximized)
(add-to-list 'default-frame-alist '(fullscreen . maximized))

(setq alpha-list `((90 90) (80 55) (70 45) (45 35) (100 100)))
(defun loop-alpha ()
  (interactive)
  (let ((h (car alpha-list)))
    ((lambda (a ab)
       (set-frame-parameter (selected-frame) 'alpha (list a ab))
       (add-to-list 'default-frame-alist (cons 'alpha (list a ab)))
       ) (car h) (car (cdr h)))
    (setq alpha-list (cdr (append alpha-list (list h))))
    )
  )
(global-set-key [(f8)] 'loop-alpha)


;; Disable line numbers for some modes
(dolist (mode '(org-mode-hook
                term-mode-hook
                shell-mode-hook
                treemacs-mode-hook
                eshell-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 0))))

(setq inhibit-splash-screen t)
(setq inhibit-startup-message t)
(fset 'yes-or-no-p 'y-or-n-p)

;; Better UI configuration

;; ── 主题 (modus-vivendi + tokyo night 背景) ──────
(use-package modus-themes
  :ensure t
  :config
  (setq modus-themes-bold-constructs t
        modus-themes-italic-constructs t)
  (setq modus-themes-common-palette-overrides
        '((border-mode-line-active unspecified)
          (border-mode-line-inactive unspecified)))
  (load-theme 'modus-vivendi t)
  (set-face-attribute 'default nil :background "#1a1b26")
  ;; vterm 终端颜色适配深色背景
  (with-eval-after-load 'vterm
    (set-face-attribute 'vterm-color-black nil :foreground "#a9b1d6" :background "#414868")
    (set-face-attribute 'vterm-color-bright-black nil :foreground "#a9b1d6" :background "#414868")
    (set-face-attribute 'vterm-color-inverse-video nil :background "#1a1b26"))
  ;; modeline 配色
  (set-face-attribute 'mode-line nil :background "#4e6cc0" :foreground "#e0e6ff")
  (set-face-attribute 'mode-line-active nil :background "#4e6cc0" :foreground "#e0e6ff")
  (set-face-attribute 'mode-line-inactive nil :background "#333d5c" :foreground "#a9b1d6"))

;; ── Modeline ─────────────────────────────────────
(use-package nerd-icons :ensure t)
(use-package doom-modeline
  :ensure t
  :init (doom-modeline-mode 1)
  :custom
  (doom-modeline-height 25)
  (doom-modeline-bar-width 4)
  (doom-modeline-icon t)
  (doom-modeline-major-mode-icon t)
  (doom-modeline-major-mode-color-icon t)
  (doom-modeline-buffer-file-name-style 'truncate-upto-project)
  (doom-modeline-minor-modes nil)
  (doom-modeline-enable-word-count nil)
  (doom-modeline-buffer-encoding nil)
  (doom-modeline-checker-simple-format t)
  (doom-modeline-vcs-max-length 20)
  (doom-modeline-env-version nil)
  (doom-modeline-github nil)
  (doom-modeline-mu4e nil)
  (doom-modeline-irc nil)
  (doom-modeline-persp-name nil))

;; ── 括号彩虹（所有编程模式） ─────────────────────
(use-package rainbow-delimiters
  :ensure t
  :hook (prog-mode . rainbow-delimiters-mode))

;; ── 变动区域闪烁提示 ────────────────────────────
(use-package goggles
  :ensure t
  :hook ((prog-mode text-mode) . goggles-mode)
  :config
  (setq goggles-pulse t))

;; ── TODO/FIXME/HACK 高亮 ────────────────────────
(use-package hl-todo
  :ensure t
  :hook (prog-mode . hl-todo-mode))

;; ── 光标跳转脉冲（内置） ────────────────────────
(setq pulse-delay 0.04)
(setq pulse-iterations 10)
(dolist (hook '(imenu-after-jump-hook))
  (add-hook hook #'pulse-line))
(advice-add 'recenter-top-bottom :after
            (lambda (&rest _) (pulse-momentary-highlight-one-line)))


(use-package which-key
  :init (which-key-mode)
  :diminish which-key-mode
  :config
  (setq which-key-idle-delay 1))


(use-package hydra
  ;; C-c c 已被 claude-code-command-map 占用
  ;; :bind (("C-c c" . hydra-text-scale/body))
  :config
  (defhydra hydra-text-scale (:timeout 4)
  "scale text"
  ("k" text-scale-increase "in")
  ("j" text-scale-decrease "out")
  ("f" nil "finished" :exit t))
  )



;; (rune/leader-keys
;;   "ts" '(hydra-text-scale/body :which-key "scale text"))



(provide 'init-ui)
