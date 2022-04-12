;;------------------------------------------------------------
;; (set-face-attribute
;;  'default nil :font "UbuntuMono 14")

;; ;; Chinese Font 配置中文字体
;; (dolist (charset '(kana han symbol cjk-misc bopomofo))
;;   (set-fontset-font (frame-parameter nil 'font)
;;                     charset
;;                     (font-spec :family "Microsoft YaHei" :size 13)))
;;------------------------------------------------------------

(use-package cl-lib)
(use-package company)
(use-package hungry-delete)
(use-package swiper)
(use-package counsel)
(use-package dash)
(use-package smartparens)
(use-package expand-region)
(use-package electric-spacing)
(use-package elpy)
(use-package yasnippet)
(use-package auto-complete)
;;(use-package ecb)
(use-package jedi)
(use-package cedet)
(use-package nyan-mode)
(use-package multiple-cursors)
(use-package ace-jump-mode)
(use-package undo-tree)
(use-package magit)
(use-package fullframe)
(use-package lsp-mode)

(use-package python-mode
  :ensure t
  :hook (python-mode . lsp-deferred)
  :custom
  (python-shell-interpreter "pythonw")
  )

(require 'expand-region)
(global-set-key (kbd "C-=") 'er/expand-region)

(fullframe list-packages quit-window)


;;(defun sanityinc/set-tabulated-list-column-width (col-name width)
;;  "Set any column with name COL-NAME to the given WIDTH."
;;  (when (> width (length col-name))
;;    (cl-loop for column across tabulated-list-format
;;             when (string= col-name (car column))
;;             do (setf (elt column 1) width))))
;;
;;(defun sanityinc/maybe-widen-package-menu-columns ()
;;  "Widen some columns of the package menu table to avoid truncation."
;;  (when (boundp 'tabulated-list-format)
;;    (sanityinc/set-tabulated-list-column-width "Version" 13)
;;    (let ((longest-archive-name (apply 'max (mapcar 'length (mapcar 'car package-archives)))))
;;      (sanityinc/set-tabulated-list-column-width "Archive" longest-archive-name))))

;;(add-hook 'package-menu-mode-hook 'sanityinc/maybe-widen-package-menu-columns)
;;(defalias 'after-load 'with-eval-after-load)
;; (provide 'init-elpa)



;;-----------------------------------------------------------------
;;  recentf-mode
;;-----------------------------------------------------------------
(add-hook 'after-init-hook 'recentf-mode)
(setq-default
 recentf-max-saved-items 50
 recentf-exclude '("/tmp/" "/ssh:"))


;;----------------------------------------------------------------------------
;; key-mapping
;;----------------------------------------------------------------------------

(global-set-key (kbd "C-s") 'swiper)
(global-set-key (kbd "M-x") 'counsel-M-x)
(global-set-key (kbd "C-x C-f") 'counsel-find-file)
(global-set-key (kbd "C-c r") 'counsel-recentf)
(global-set-key (kbd "C-x b") 'counsel-switch-buffer)
(global-set-key (kbd "C-1") 'set-mark-command)
(global-set-key (kbd "<f4>") 'switch-window)
(global-set-key (kbd "<f5>") 'comment-or-uncomment-region)
(global-set-key (kbd "<f6>") 'indent-region)
(global-set-key (kbd "C-x <return> -") 'insert-split-line)
(global-set-key [(f8)] 'loop-alpha)
(global-set-key (kbd "C-SPC") 'nil)


(defun insert-split-line ()
  (interactive)
  (save-restriction
    (narrow-to-region (line-beginning-position) (line-end-position))
    (goto-char (point-min))
    (setq a (re-search-forward "[^ ]" nil t))
    (if (null a)
        (progn
          (goto-char (point-min))
          (delete-char (- (point-max) (point-min)))
          (insert "-----------------------------------------------------------------"))
      (progn
        (goto-char (point-min))
        (insert "-----------------------------------------------------------------\n")))))


(setq alpha-list '((95 65) (85 55) (75 45) (45 35) (100 100)))
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

;;----------------------------------------------------------------------------
;; UI settings
;;----------------------------------------------------------------------------
(tool-bar-mode -1)
(scroll-bar-mode -1)
(menu-bar-mode -1)
(setq inhibit-splash-screen t)
(setq inhibit-startup-message t)
(fset 'yes-or-no-p 'y-or-n-p)
(nyan-mode)
;;(global-flycheck-mode -1)

;;-----------------------------------------------------------------
;;  smartparens-mode
;;-----------------------------------------------------------------
(require 'smartparens-config)
(show-smartparens-global-mode +1)
(smartparens-global-mode 1)

;; when you press RET, the curly braces automatically
;; add another newline


(global-set-key (kbd "C->") 'mc/mark-next-like-this)
(global-set-key (kbd "C-<") 'mc/mark-previous-like-this)
(global-set-key (kbd "C-c C-<") 'mc/mark-all-like-this)

(defun lsy:copy-file-name()
  "put current file name in the killing ring"
  (interactive)
  (kill-new (buffer-file-name))
  )

(defun lsy-kill ()
  (interactive)
  (if (region-active-p)
      (call-interactively #'kill-ring-save) ;; then
      (kill-ring-save (line-beginning-position) (line-end-position))
      ))

(defun lsy-kill-region ()
  (interactive)
  (if (region-active-p)
      (call-interactively #'kill-region) ;; then
      (kill-region (line-beginning-position) (line-end-position))
      ))


(defun lsy-yank ()
  (interactive)
  (if (region-active-p)
      (progn
	(delete-region (region-beginning) (region-end))
	(call-interactively #'yank)	
       )
      (call-interactively #'yank) ;; then
    ))

(global-undo-tree-mode)

(global-set-key (kbd "<f7>" ) 'lsy:copy-file-name)
(global-set-key (kbd "C-4" ) 'ace-jump-mode)

(global-set-key (kbd "S-<left>" ) 'windmove-left)
(global-set-key (kbd "S-<right>" ) 'windmove-right)
(global-set-key (kbd "S-<up>" ) 'windmove-up)
(global-set-key (kbd "S-<down>" ) 'windmove-down)

(global-set-key (kbd "M-w" ) 'lsy-kill)
(global-set-key (kbd "C-w" ) 'lsy-kill-region)
(global-set-key (kbd "C-y" ) 'lsy-yank)
;;(global-set-key (kbd "C-x u") 'undo-tree-visualize)



(provide 'init-local)
