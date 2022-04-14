(use-package company
  :after lsp-mode
  :bind (:map company-active-map
              ("<tab>" . company-complete-selection)
              ("M-." . company-filter-candidates)
              ("M-," . company-abort)	      
	      )
        (:map lsp-mode-map
         ("<tab>" . company-indent-or-complete-common))
  :custom
  (company-minimum-prefix-length 1)
  (company-idle-delay 0.0)
  :hook ((lsp-mode . company-mode)
	 (emacs-lisp-mode . company-mode)
	 (python-mode . company-mode)
	 )
  )


(use-package company-box
  :hook (company-mode . company-box-mode))


(provide 'init-company)


