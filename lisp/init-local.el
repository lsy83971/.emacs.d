;;------------------------------------------------------------
;; (set-face-attribute
;;  'default nil :font "UbuntuMono 14")

;; ;; Chinese Font 配置中文字体
;; (dolist (charset '(kana han symbol cjk-misc bopomofo))
;;   (set-fontset-font (frame-parameter nil 'font)
;;                     charset
;;                     (font-spec :family "Microsoft YaHei" :size 13)))
;;------------------------------------------------------------
;;(use-package yasnippet)



;;(use-package swiper)
;;(use-package counsel)
;;(use-package dash)

(use-package python-mode
  :ensure t
  :hook (python-mode . lsp-deferred)
  :custom
  (python-shell-interpreter "pythonw")
  )

(require 'expand-region)


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



;;(setq which-key-idle-delay 0.1
;;      which-key-idle-secondary-delay 0.1)

;;----------------------------------------------------------------------------
;; key-mapping
;;----------------------------------------------------------------------------






;;----------------------------------------------------------------------------
;; UI settings
;;----------------------------------------------------------------------------
;;(global-flycheck-mode -1)

;;-----------------------------------------------------------------
;;  smartparens-mode
;;-----------------------------------------------------------------
;; when you press RET, the curly braces automatically
;; add another newline






(provide 'init-local)
