;;-----------------------------------------------------------------
;;  C/C++ mode
;;-----------------------------------------------------------------

(defun my:hide-or-show ()
  (interactive)
  (if (hs-already-hidden-p) (hs-show-block) (hs-hide-block)))

(use-package cc-mode
  :config
  (add-hook 'c++-mode-hook
            (lambda ()
              (setq c-default-style "linux")
              (setq c-basic-offset 4)
              (setq tab-width 4)
              (setq indent-tabs-mode nil)
              (c-set-offset 'innamespace 0)
              (c-set-offset 'arglist-intro '+)
              ;; 现代 C++ 语法高亮
              (font-lock-add-keywords nil
                '(("\\<\\(nullptr\\|override\\|final\\|constexpr\\|noexcept\\)\\>"
                   . font-lock-keyword-face))))))

(use-package xref
  :config
  (global-set-key (kbd "M-.") 'xref-find-definitions)
  (global-set-key (kbd "M-,") 'xref-pop-marker-stack)
  (global-set-key (kbd "M-?") 'xref-find-references))

;; LSP 模式支持
(use-package lsp-mode
  :init
  (setq lsp-keymap-prefix "C-c l")
  :hook
  ((c++-mode . lsp-deferred)
   (c-mode . lsp-deferred))
  :config
  ;; Clangd 配置
  (setq lsp-clients-clangd-args
        '("--background-index"
          "--clang-tidy"
          "--header-insertion=never"
          "--completion-style=detailed"
          "--pch-storage=memory"
          "--function-arg-placeholders=0"))
  (setq lsp-enable-snippet nil)
  (setq lsp-auto-guess-root t)
  ;; 性能优化
  (setq lsp-idle-delay 0.5
        lsp-log-io nil
        lsp-enable-symbol-highlighting nil
        lsp-enable-on-type-formatting nil)
  ;; 快捷键
  (define-key lsp-mode-map (kbd "C-c l r") 'lsp-rename)
  (define-key lsp-mode-map (kbd "C-c l f") 'lsp-format-buffer)
  (define-key lsp-mode-map (kbd "C-c l i") 'lsp-organize-imports))

;; C/C++ 模式的 company 补全设置（company 本身由 init-company.el 配置）
(defun my/c-company-setup ()
  "设置 C/C++ 模式的 company backends。"
  (setq-local company-backends '(company-capf
                                 company-dabbrev-code
                                 company-files))
  (company-mode 1))

(add-hook 'c++-mode-hook #'my/c-company-setup)
(add-hook 'c-mode-hook #'my/c-company-setup)

(use-package projectile
  :ensure t
  :config
  (projectile-mode +1)
  (setq projectile-project-search-path
        '(("/mnt/lishiyu/cpp_online/test/" . 2))))

(use-package electric-spacing)

(defun my:electric-spacing-mode ()
  (electric-spacing-mode 1))

(add-hook 'c++-mode-hook 'my:electric-spacing-mode)
(add-hook 'c-mode-hook 'my:electric-spacing-mode)

(provide 'init-c)
