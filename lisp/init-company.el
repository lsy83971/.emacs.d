(global-company-mode)

(define-key company-active-map (kbd "M-.") 'company-filter-candidates)
(define-key company-active-map (kbd "M-,") 'company-abort)

(provide 'init-company)
