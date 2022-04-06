(require 'org-bars)
(add-hook 'org-mode-hook #'org-bars-mode)
(add-hook 'org-mode-hook (lambda ()
(local-set-key (kbd "S-<left>" ) 'windmove-left)
(local-set-key (kbd "S-<right>" ) 'windmove-right)
(local-set-key (kbd "S-<up>" ) 'windmove-up)
(local-set-key (kbd "S-<down>" ) 'windmove-down)
))


(provide 'init-org)
