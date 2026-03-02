(defun my/set-font ()
  (interactive)
  (set-face-attribute 'default nil
                      :font "UbuntuMono"
                      :height 120)
  (dolist (charset '(kana han cjk-misc bopomofo))
    (set-fontset-font t charset
                      (font-spec :family "WenQuanYi Micro Hei Mono"
                                 :size 10.5)))
  (set-fontset-font t 'emoji
                    (font-spec :family "Noto Color Emoji" :size 12)))

(defun my/sync-cjk-font-scale ()
  (let* ((base-height 120)  ;; 与 :height 保持一致
         (scale (expt text-scale-mode-step text-scale-mode-amount))
         (new-size (/ (* base-height scale) 10.0)))
    (dolist (charset '(kana han cjk-misc bopomofo))
      (set-fontset-font t charset
                        (font-spec :family "WenQuanYi Micro Hei Mono"
                                   :size new-size)))
    (set-fontset-font t 'emoji
                      (font-spec :family "Noto Color Emoji"
                                 :size new-size))))
;; (defun my/set-font ()
;;   (interactive)
;;   (set-face-attribute 'default nil
;; 		    ;;:font "Sarasa Fixed SC"
;; 		    :font "UbuntuMono"
;; 		    :height 120)
  
;;   (dolist (charset '(kana han cjk-misc bopomofo))
;;       (set-fontset-font t charset
;; 		    (font-spec
;; 		     ;;:family "Noto Sans CJK SC"
;; 		     ;;:family "UbuntuMono"
;; 		     ;;:family "Sarasa Fixed SC"
;; 		     :family "WenQuanYi Micro Hei Mono"
;; 		     :size 12
;; 		     )
;; 		    )
  
;;       )
;;   (set-fontset-font t 'emoji
;;                   (font-spec :family "Noto Color Emoji" :size 12))
;;   )

;;(when (not (eq system-type 'windows-nt))
;;  (when (display-graphic-p)  ; 仅对图形界面生效
;;    (set-language-environment "UTF-8")
;;    (set-default-coding-systems 'utf-8)
    ;; 启用XIM输入协议，适配fcitx/ibus
    ;; (setq default-input-method "xim")
    ;;(toggle-input-method nil))  ; 初始化输入方法状态
  ;; 强制设置中文环境变量，解决图形界面继承不到的问题 
  ;; (global-unset-key (kbd "C-SPC"))
;;  (setenv "LC_CTYPE" "zh_CN.UTF-8")
;;  (setenv "XMODIFIERS" "@im=xim")
  ;;

(add-hook 'after-init-hook 'my/set-font)
(add-hook 'text-scale-mode-hook #'my/sync-cjk-font-scale)

  ;;(add-hook 'window-setup-hook 'my/set-font)
  (when (daemonp)
    (add-hook 'server-after-make-frame-hook 'my/set-font)
    )
