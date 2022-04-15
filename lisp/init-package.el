(require 'package)
(package-initialize)
;;(setq package-archives '(("gnu"   . "http://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
;;                         ;;("melpa" . "http://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")
;;			 ("melpa" . "https://melpa.org/packages/")
;;			 ("org" . "https://orgmode.org/elpa/")
;;			 ))

(setq package-archives '(("gnu"   . "http://mirrors.cloud.tencent.com/elpa/gnu/")
                         ("melpa" . "http://mirrors.cloud.tencent.com/elpa/melpa/")
			 ;;("melpa" . "https://melpa.org/packages/")
			 ;;("org" . "https://orgmode.org/elpa/")
			 ))
(package-refresh-contents)
(unless package-archive-contents
  (package-refresh-contents))
  ;; Initialize use-package on non-Linux platforms
(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)



(use-package cl-lib)







(provide 'init-package)
