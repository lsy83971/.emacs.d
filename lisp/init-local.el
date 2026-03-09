(require 'expand-region)

(setq er/try-expand-list (remove 'er/mark-next-accessor er/try-expand-list))
(use-package anzu)
(fullframe list-packages quit-window)

(provide 'init-local)
