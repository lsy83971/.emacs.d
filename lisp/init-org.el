
(use-package org
  :config
  (add-hook 'org-mode-hook
	    (lambda ()
	      (local-set-key (kbd "S-<left>" ) 'windmove-left)
	      (local-set-key (kbd "S-<right>" ) 'windmove-right)
	      (local-set-key (kbd "S-<up>" ) 'windmove-up)
	      (local-set-key (kbd "S-<down>" ) 'windmove-down)
	      )
	    (require 'org-bars)
	    (add-hook 'org-mode-hook #'org-bars-mode)
	    )
  )

(org-babel-do-load-languages
 'org-babel-load-languages
 '((emacs-lisp . t)
   (python . t)
   (ledger . t)))



(provide 'init-org)
