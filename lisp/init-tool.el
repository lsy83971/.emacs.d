(use-package hungry-delete
  :config
  (global-hungry-delete-mode)
  )

(use-package expand-region
  :bind (("C-=" . er/expand-region))
  )

(use-package smartparens
  :config
  (require 'smartparens-config)
  (show-smartparens-global-mode +1)
  (smartparens-global-mode 1)
  )

(use-package recentf
  :config
  (setq-default
   recentf-max-saved-items 50
   recentf-exclude '("/tmp/" "/ssh:"))
  (recentf-mode)
  )
;;(use-package electric-spacing)

(use-package undo-tree
  :config
  (global-undo-tree-mode)
  :bind
  (("C-x u" . undo-tree-visualize))
  )


(use-package magit)
(use-package fullframe)
(use-package lsp-mode)

(provide 'init-tool)


