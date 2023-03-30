(require 'expand-region)


(setq er/try-expand-list (remove 'er/mark-next-accessor er/try-expand-list))
(use-package anzu)
(fullframe list-packages quit-window)

(setq alpha-list '((95 65) (85 55) (75 45) (45 35) (100 100)))
(defun loop-alpha ()
  (interactive)
  (let ((h (car alpha-list)))
    ((lambda (a ab)
       (set-frame-parameter (selected-frame) 'alpha (list a ab))
       (add-to-list 'default-frame-alist (cons 'alpha (list a ab)))
       ) (car h) (car (cdr h)))
    (setq alpha-list (cdr (append alpha-list (list h))))
    )
  )


;; (require 'popup)
;; (require 'pyim)
;; (require 'pyim-basedict)
;; (setq pyim-page-tooltip 'popup)
;; (pyim-basedict-enable)
;; ;;(setq default-input-method "pyim")
;; (global-set-key (kbd "C-\\") 'toggle-input-method)
;; (pyim-default-scheme 'quanpin)


(provide 'init-local)

