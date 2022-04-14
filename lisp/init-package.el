(require 'package)


(require 'package)
(setq package-archives '(("gnu"   . "http://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
                         ("melpa" . "http://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")
			 ("org" . "https://orgmode.org/elpa/")
			 ))
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))
  ;; Initialize use-package on non-Linux platforms
(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)



(use-package cl-lib)







(provide 'init-package)
