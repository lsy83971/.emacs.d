;;-----------------------------------------------------------------
;;  C/C++ mode
;;-----------------------------------------------------------------


;; (require 'yasnippet)
;; (yas-global-mode 1)
(defun my:hide-or-show ()
  (interactive)
  (if (hs-already-hidden-p) (hs-show-block) (hs-hide-block))
  )

(defun my/setup-cpp-includes ()
  "设置 C++ 包含路径"
  (let ((project-root (or (locate-dominating-file default-directory ".git")
                          default-directory)))
    (setq-local lsp-clients-clangd-args
                (append lsp-clients-clangd-args
                        (list (concat "--include-directory=" project-root "include")
                              (concat "--include-directory=" project-root "src")
                              (concat "--include-directory=" project-root "third_party")
                              (concat "--include-directory=" project-root "external")
                              "--query-driver=/usr/bin/g++"
                              "--query-driver=/usr/bin/gcc-12")))))

(use-package cc-mode
  :config
  ;; 设置 C++ 风格
  (add-hook 'c++-mode-hook
            (lambda ()
              (setq c-default-style "linux")
              (setq c-basic-offset 4)
              (setq tab-width 4)
              (setq indent-tabs-mode nil)
              (c-set-offset 'innamespace 0)
              (c-set-offset 'arglist-intro '+)
              
              ;; 启用现代 C++ 语法高亮
              (font-lock-add-keywords nil
                '(("\\<\\(nullptr\\|override\\|final\\|constexpr\\|noexcept\\)\\>" 
                   . font-lock-keyword-face))))))

(use-package xref
  :config
  (global-set-key (kbd "M-.") 'xref-find-definitions)
  (global-set-key (kbd "M-,") 'xref-pop-marker-stack)
  (global-set-key (kbd "M-?") 'xref-find-references))

(defun my:c-init()
  ;; 5. LSP 模式支持
  (use-package lsp-mode
    :init
    (setq lsp-keymap-prefix "C-c l")
    :hook
    (c++-mode . lsp-deferred)
    :config
    ;; Clangd 配置
    (setq lsp-clients-clangd-args
          '("--background-index"
            "--clang-tidy"
            "--header-insertion=never"
            "--completion-style=detailed"
            "--pch-storage=memory"
            "--cross-file-rename"
            "--function-arg-placeholders=0"))
    (setq lsp-formatting-indent-options
          '((c . ((indent-width . 4)
                  (use-tabs . nil)))
            (cpp . ((indent-width . 4)
                    (use-tabs . nil)))
            (objc . ((indent-width . 4)
                   (use-tabs . nil)))))    
    (setq lsp-enable-snippet nil)     ; 关闭代码片段（可选）
    (setq lsp-auto-guess-root t) ; 自动识别项目根目录（关键！）
    ;; 性能优化
    (setq lsp-idle-delay 0.5
          lsp-log-io nil
          lsp-enable-symbol-highlighting nil
          lsp-enable-on-type-formatting nil)
    
    ;; 快捷键
    (define-key lsp-mode-map (kbd "C-c l r") 'lsp-rename)
    (define-key lsp-mode-map (kbd "C-c l f") 'lsp-format-buffer)
    (define-key lsp-mode-map (kbd "C-c l i") 'lsp-organize-imports))
  (use-package projectile
    :ensure t
    :config
    (projectile-mode +1)
    (setq projectile-project-search-path
          '(("/mnt/lishiyu/cpp_online/test/" . 2)    ;; 深度2层
	    )))
  ;; 6. LSP UI 增强
  ;; (use-package lsp-ui
  ;;   :config
  ;;   (setq lsp-ui-doc-enable nil
  ;;         lsp-ui-doc-header nil
  ;;         lsp-ui-doc-include-signature nil
  ;;         lsp-ui-doc-border (face-foreground 'default)
  ;;         lsp-ui-sideline-enable nil
  ;;         lsp-ui-sideline-show-code-actions nil
  ;;         lsp-ui-sideline-show-diagnostics nil
  ;;         lsp-ui-sideline-show-hover nil)
  ;;   
    ;; 调整显示延迟
    ;; (setq lsp-ui-doc-delay 1.0)
    
    ;; 快捷键
  ;;  (define-key lsp-ui-mode-map [remap xref-find-definitions] 'lsp-ui-peek-find-definitions)
  ;;  (define-key lsp-ui-mode-map [remap xref-find-references] 'lsp-ui-peek-find-references))


  ;; (let ((project-root (or (locate-dominating-file default-directory ".git")
  ;;                         default-directory)))
  ;;   (setq-local lsp-clients-clangd-args
  ;;               (append lsp-clients-clangd-args
  ;;                       (list (concat "--include-directory=" project-root "include")
  ;;                             (concat "--include-directory=" project-root "src")
  ;;                             (concat "--include-directory=" project-root "third_party")
  ;;                             (concat "--include-directory=" project-root "external")
  ;;                             "--query-driver=/usr/bin/g++"
  ;;                             "--query-driver=/usr/bin/gcc-12"))))  
  ;; 7. Company 补全
  (use-package company
    :config
    (global-company-mode)
    (setq company-idle-delay 0.3
          company-minimum-prefix-length 2
          company-selection-wrap-around t
          company-show-numbers t
          company-tooltip-limit 10
          company-dabbrev-downcase nil))

  ;; 8. Flycheck 语法检查
  ;; (use-package flycheck
  ;;   :config
  ;;   (global-flycheck-mode)
  ;;   (setq flycheck-check-syntax-automatically '(save mode-enabled))
  ;;   (setq flycheck-clang-language-standard "c++17"))
)

(add-hook 'c++-mode-hook 'my:c-init)
(add-hook 'c-mode-hook 'my:c-init)

;; (add-hook 'c++-mode-hook #'my/setup-cpp-includes)
;; (add-hook 'c-mode-hook #'my/setup-cpp-includes)
;; /usr/include/c++/5
;; /usr/include/x86_64-linux-gnu/c++/5
;; /usr/include/c++/5/backward
;; /usr/lib/gcc/x86_64-linux-gnu/5/include
;; /usr/local/include
;; /usr/lib/gcc/x86_64-linux-gnu/5/include-fixed
;; /usr/include/x86_64-linux-gnu
;; /usr/include

(defun my:electric-spacing-mode()
  (electric-spacing-mode 1))

(add-hook 'c++-mode-hook 'my:electric-spacing-mode)
(add-hook 'c-mode-hook 'my:electric-spacing-mode)

(provide 'init-c)
