;;------------------------------------------------------------
;; (set-face-attribute
;;  'default nil :font "UbuntuMono 14")

;; ;; Chinese Font 配置中文字体
;; (dolist (charset '(kana han symbol cjk-misc bopomofo))
;;   (set-fontset-font (frame-parameter nil 'font)
;;                     charset
;;                     (font-spec :family "Microsoft YaHei" :size 13)))
;;------------------------------------------------------------

(require 'cl)
(setq lsy-pkgs '(
                 company
                 hungry-delete
                 swiper
                 counsel
                 dash
                 smartparens
                 expand-region
                 ;;iedit
                 electric-spacing
                 elpy
                 yasnippet
                 auto-complete
                 ecb
                 jedi
                 cedet
                 nyan-mode
                 multiple-cursors
                 ;;auto-complete-config
                 ;;auto-complete-c-headers
                 ;;google-c-style
                 ))




(defun lsy-installed-pkgs()
  (loop for pkg in lsy-pkgs
        when (not (package-installed-p pkg)) do (return nil)
        finally (return t)))

(unless (lsy-installed-pkgs)
  (message "%s" "Refreshing pkg database...")
  (package-refresh-contents)
  (dolist (pkg lsy-pkgs)
    (when (not (package-installed-p pkg))
      (package-install pkg))))


(require 'expand-region)
(global-set-key (kbd "C-=") 'er/expand-region)


;;-------------------
;;elpa
(require 'package)


(let ((local-package-el (locate-library "package")))
  (when (string-match-p (concat "^" (regexp-quote user-emacs-directory))
                        local-package-el)
    (warn "Please remove the local package.el, which is no longer supported (%s)"
          local-package-el)))


;;; Install into separate package dirs for each Emacs version, to prevent bytecode incompatibility
(let ((versioned-package-dir
       (expand-file-name (format "elpa-%s.%s" emacs-major-version emacs-minor-version)
                         user-emacs-directory)))
  (setq package-user-dir versioned-package-dir))


;;; Standard package repositories

;; We include the org repository for completeness, but don't normally
;; use it.

;; NOTE: In case of MELPA problems, the official mirror URL is
;; https://www.mirrorservice.org/sites/stable.melpa.org/packages/


;;; On-demand installation of packages

(defun require-package (package &optional min-version no-refresh)
  "Install given PACKAGE, optionally requiring MIN-VERSION.
If NO-REFRESH is non-nil, the available package lists will not be
re-downloaded in order to locate PACKAGE."
  (if (package-installed-p package min-version)
      t
    (if (or (assoc package package-archive-contents) no-refresh)
        (if (boundp 'package-selected-packages)
            ;; Record this as a package the user installed explicitly
            (package-install package nil)
          (package-install package))
      (progn
        (package-refresh-contents)
        (require-package package min-version t)))))


(defun maybe-require-package (package &optional min-version no-refresh)
  "Try to install PACKAGE, and return non-nil if successful.
In the event of failure, return nil and print a warning message.
Optionally require MIN-VERSION.  If NO-REFRESH is non-nil, the
available package lists will not be re-downloaded in order to
locate PACKAGE."
  (condition-case err
      (require-package package min-version no-refresh)
    (error
     (message "Couldn't install optional package `%s': %S" package err)
     nil)))

;;; Fire up package.el

(setq package-enable-at-startup nil)
(package-initialize)


(require-package 'fullframe)
(fullframe list-packages quit-window)

(require-package 'cl-lib)
(require 'cl-lib)

(defun sanityinc/set-tabulated-list-column-width (col-name width)
  "Set any column with name COL-NAME to the given WIDTH."
  (when (> width (length col-name))
    (cl-loop for column across tabulated-list-format
             when (string= col-name (car column))
             do (setf (elt column 1) width))))

(defun sanityinc/maybe-widen-package-menu-columns ()
  "Widen some columns of the package menu table to avoid truncation."
  (when (boundp 'tabulated-list-format)
    (sanityinc/set-tabulated-list-column-width "Version" 13)
    (let ((longest-archive-name (apply 'max (mapcar 'length (mapcar 'car package-archives)))))
      (sanityinc/set-tabulated-list-column-width "Archive" longest-archive-name))))

(add-hook 'package-menu-mode-hook 'sanityinc/maybe-widen-package-menu-columns)


(defalias 'after-load 'with-eval-after-load)

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
;; (global-set-key (kbd "C-c C-r") 'ivy-resume)
(global-set-key (kbd "M-x") 'counsel-M-x)
;; (global-set-key (kbd "C-x C-f") 'counsel-find-file)
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
;;(setq-default cursor-type 'bar)
(setq inhibit-startup-message t)
(fset 'yes-or-no-p 'y-or-n-p)
;;(global-linum-mode t)
;;(dark)
(nyan-mode)
;;(global-flycheck-mode -1)

;;------------------------------------------------------------------------------
;; R-mode
;;------------------------------------------------------------------------------

;; (with-eval-after-load 'ess-mode
;;   (define-key ess-mode-map (kbd "C-r")
;;     'ess-eval-region-or-function-or-paragraph))
;; (add-hook 'ess-mode-hook
;;           (lambda ()
;;             (ess-set-style 'C++ 'quiet)
;;             (setq comment-column 4)
;;             ess-indent-level 2
;;             (local-set-key (kbd ",") '(lambda() (interactive) (insert " , ")))
;;             (local-set-key (kbd "~") '(lambda() (interactive) (insert " ~ ")))
;;             (local-set-key (kbd "M-p") 'scroll-down-command)
;;             (local-set-key (kbd "M-n") 'scroll-up-command)
;;             ess-continued-statement-offset 2
;;             ess-brace-offset 0
;;             ess-arg-function-offset 4
;;             ess-expression-offset 2
;;             ess-
;;             else-offset 0
;;             ess-close-brace-offset 0
;;             ))
;; (add-hook 'ess-mode-hook 'hungry-delete-mode)
;; (add-hook 'ess-mode-hook 'turn-on-orgstruct)
;; (add-hook 'ess-mode-hook 'turn-on-orgstruct++)
;; (setq orgstruct-heading-prefi
;;       x-regexp "##*")

;; -----------------------------------------------------------------
;; ecb-mode
;; -----------------------------------------------------------------

;; (require 'semantic)
;; (require 'cedet)
;; (require 'ecb)
;; (setq stack-trace-on-error nil) ;;don’t popup Backtrace window
;; (setq ecb-tip-of-the-day nil)
;; (setq ecb-layout-name  "left11")
;; (setq ecb-options-version "2.40")
;; (add-hook  'ecb-activate-hook (lambda () (semantic-mode)))



;;-----------------------------------------------------------------
;;  smartparens-mode
;;-----------------------------------------------------------------
(require 'smartparens-config)
(show-smartparens-global-mode +1)
(smartparens-global-mode 1)

;; when you press RET, the curly braces automatically
;; add another newline
(sp-with-modes '(c-mode c++-mode)
               (sp-local-pair "{" nil :post-handlers '(("||\n[i]" "RET")))
               (sp-local-pair "/*" "*/" :post-handlers '((" | " "SPC")
                                                         ("* ||\n[i]" "RET"))))

(global-set-key (kbd "C->") 'mc/mark-next-like-this)
(global-set-key (kbd "C-<") 'mc/mark-previous-like-this)
(global-set-key (kbd "C-c C-<") 'mc/mark-all-like-this)

(defun lsy:copy-file-name()
  "put current file name in the killing ring"
  (interactive)
  (kill-new (buffer-file-name))
  )

;;(global-set-key (kbd "C-c C-<") 'mc/mark-all-like-this)
(global-set-key (kbd "<f7>" ) 'lsy:copy-file-name)
(global-set-key (kbd "C-4" ) 'ace-jump-mode)



(provide 'init-local)
