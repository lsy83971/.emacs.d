;;; init-dirvish.el --- dirvish 配置  -*- lexical-binding: t; -*-

(use-package dirvish
  :ensure t
  :init
  (dirvish-override-dired-mode)
  :custom
  (dirvish-reuse-session t)
  (dired-kill-when-opening-new-dired-buffer t)
  :config
  ;; extensions 目录需要手动加入 load-path
  (let ((ext-dir (expand-file-name "extensions"
                                    (file-name-directory (locate-library "dirvish")))))
    (when (file-directory-p ext-dir)
      (add-to-list 'load-path ext-dir)))
  (require 'dirvish-subtree)
  :bind
  (:map dirvish-mode-map
   ("TAB" . dirvish-subtree-toggle)
   ("q"   . dirvish-quit)))

(provide 'init-dirvish)
;;; init-dirvish.el ends here
