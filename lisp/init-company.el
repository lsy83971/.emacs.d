(use-package company
  :bind (:map company-active-map
              ("<tab>" . company-complete-selection)
              ("M-." . company-filter-candidates)
              ("M-," . company-abort)	      
	      )
  :custom
  (company-minimum-prefix-length 1)
  (company-idle-delay 0.1)
  (company-tooltip-limit 15)
  (company-show-numbers t)
  (company-tooltip-align-annotations t)
  (company-require-match nil)
  (company-selection-wrap-around t)
  (company-dabbrev-ignore-case t)
  (company-dabbrev-downcase nil)
  
  :hook (
	 (emacs-lisp-mode . company-mode)
	 (python-mode . company-mode)
	 )
  )


(use-package company-box
  :hook (company-mode . company-box-mode))


(provide 'init-company)


