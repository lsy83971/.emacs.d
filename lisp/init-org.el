
(use-package org
  :config
  (add-hook 'org-mode-hook #'org-bars-mode)  
  (add-hook 'org-mode-hook
	    (progn
	      (require 'org-bars)	    
	      (lambda ()
		(message "test")
		(local-set-key (kbd "S-<left>" ) 'windmove-left)
		(local-set-key (kbd "S-<right>" ) 'windmove-right)
		(local-set-key (kbd "S-<up>" ) 'windmove-up)
		(local-set-key (kbd "S-<down>" ) 'windmove-down)
		))
	    )
  )

(org-babel-do-load-languages
 'org-babel-load-languages
 '((emacs-lisp . t)
   (python . t)))



(provide 'init-org)
