(global-set-key (kbd "C-1") 'set-mark-command)
(global-set-key (kbd "C-t") 'anzu-query-replace)
(global-set-key (kbd "C-j") 'mc/edit-lines)
;; lisp-interaction-mode-map 中 C-j 绑定了 eval-print-last-sexp，覆盖 global-set-key
(with-eval-after-load 'elisp-mode
  (define-key lisp-interaction-mode-map (kbd "C-j") 'mc/edit-lines))
(global-set-key (kbd "C-3") 'toggle-input-method)

;; backward-delete-word 统一在 init-nav.el 中定义

(provide 'init-keymap)
