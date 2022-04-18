(use-package company-web)  
(use-package vue-mode)
(use-package emmet-mode
  :config
  (add-hook 'emmet-mode-hook
	    (lambda ()
	      (setq emmet-indent-after-insert nil)
	      (setq emmet-indentation 2)
	      (setq emmet-move-cursor-between-quotes t)
	      (setq emmet-self-closing-tag-style " /")
	      )
	    )
  (add-hook 'mhtml-mode-hook (lambda ()
                              (set (make-local-variable 'company-backends) '(company-web-html))
                              (company-mode t)))  
  )
  (add-hook 'sgml-mode-hook 'emmet-mode)
  (add-hook 'html-mode-hook 'emmet-mode)
  (add-hook 'mhtml-mode-hook 'emmet-mode)
  (add-hook 'css-mode-hook 'emmet-mode)



    

(provide 'init-html)
