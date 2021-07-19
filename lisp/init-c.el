;;-----------------------------------------------------------------
;;  C/C++ mode
;;-----------------------------------------------------------------


;; (require 'yasnippet)
;; (yas-global-mode 1)
(defun my:hide-or-show ()
  (interactive)
  (if (hs-already-hidden-p) (hs-show-block) (hs-hide-block))
  )




(defun my:c-init()
  (require 'auto-complete)
  (require 'auto-complete-config)
  (ac-config-default)
  (require 'auto-complete-c-headers)
  (add-to-list 'ac-sources 'ac-source-c-headers)
  (add-to-list 'achead:include-directories '"/usr/lib/gcc/x86_64-linux-gnu/5/include-fixed")
  (add-to-list 'achead:include-directories '"/usr/lib/gcc/x86_64-linux-gnu/5/include")
  (add-to-list 'achead:include-directories '"/usr/include/c++/5")
  (hs-minor-mode)
  (local-set-key (kbd "<f2>") 'my:hide-or-show)
  )

(add-hook 'c++-mode-hook 'my:c-init)
(add-hook 'c-mode-hook 'my:c-init)

;; /usr/include/c++/5
;; /usr/include/x86_64-linux-gnu/c++/5
;; /usr/include/c++/5/backward
;; /usr/lib/gcc/x86_64-linux-gnu/5/include
;; /usr/local/include
;; /usr/lib/gcc/x86_64-linux-gnu/5/include-fixed
;; /usr/include/x86_64-linux-gnu
;; /usr/include

;; (defun my:add-semantic-to-autocomplete()
;;   (semantic-mode 1)
;;   (add-to-list 'ac-sources 'ac-sources-semantic)
;;   )

;; (add-hook 'c-mode-common-hook 'my:add-semantic-to-autocomplete)
;; (add-hook 'c++-mode-common-hook 'my:add-semantic-to-autocomplete)
;; (global-ede-mode 1)
;; (ede-cpp-root-project "my project" :file "~/testC/a.cpp"
;;                       :include-path '("~/testC/"))
;; (global-semantic-idle-scheduler-mode 1)


(defun my:electric-spacing-mode()
  (electric-spacing-mode 1))

(add-hook 'c++-mode-hook 'my:electric-spacing-mode)
(add-hook 'c-mode-hook 'my:electric-spacing-mode)

(provide 'init-c)
