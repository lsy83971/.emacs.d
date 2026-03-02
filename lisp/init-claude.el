;; 1. 添加 MELPA（vterm 需要）
(use-package inheritenv
  :ensure t)
;;(use-package eat :ensure t)
(use-package vterm :ensure t)
(add-to-list 'load-path "~/.emacs.d/claude-code-stevemolitor")
(require 'claude-code)
(define-key global-map (kbd "C-c c") 'claude-code-command-map)

;; (use-package claude-code
;;   :ensure nil
;;   :vc (:url "https://github.com/stevemolitor/claude-code.el" :rev :newest)
;;   :config
;;   (define-key global-map (kbd "C-c c") claude-code-command-map))

(use-package claude-code
  :ensure nil
  :vc (:url "https://github.com/stevemolitor/claude-code.el" :rev :newest)
  :bind-keymap
  ("C-c c" . claude-code-command-map)
  :config
  ;; 文件改动后自动同步 buffer（Claude 改完文件 Emacs 能立刻看到）
  (global-auto-revert-mode 1)
  (setq auto-revert-use-notify nil)  ; 如果自动同步不稳定加这行
  (setq claude-code-terminal-backend 'vterm)

  ;; Claude 窗口固定在右侧
  (add-to-list 'display-buffer-alist
               '("^\\*claude"
                 (display-buffer-in-side-window)
                 (side . right)
                 (window-width . 120))))

(require 'project)
(add-to-list 'project-find-functions
             (lambda (dir)
               (when (locate-dominating-file dir ".project")
                 (cons 'transient dir))))

;; 修复：切换 vterm-copy-mode 时阻止 Claude CLI 收到 resize 信号
(define-advice display-buffer (:around (orig-fn buffer &rest args) claude-code-preserve-window)
  "当 Claude buffer 已经在某个窗口显示时，不重新 display，保持窗口大小不变。"
  (if (and (claude-code--buffer-p buffer)
           (get-buffer-window buffer))
      ;; 已经可见，直接返回现有窗口，不做任何操作
      (get-buffer-window buffer)
    ;; 否则正常 display
    (apply orig-fn buffer args)))

;;(advice-add 'claude-code-toggle-read-only-mode :override #'claude-code-toggle-read-only-mode-fixed)

;;;; Copy/Paste 快捷鍵（vterm backend 專用）
;;
;;   M-w  → 正常模式：進入 copy 模式（cursor 停在 terminal cursor 位置）；Copy 模式：複製選取區並退出
;;   C-y  → 貼上 kill-ring 頂端內容到 Claude 輸入區
;;
;; 鍵盤攔截分兩層：
;;   正常模式：vterm 用 vterm--self-insert / vterm--self-insert-meta 攔截所有按鍵
;;             → advice :before-until 在 Claude buffer 中攔截 M-w / C-y
;;   Copy 模式：vterm--self-insert* 不觸發，走正常 keymap 查找
;;             → 但使用者的自訂 binding（如 lsy-kill）可能在 minor-mode-map-alist，
;;               優先於 local keymap（步驟 4 > 步驟 5）
;;             → 用 minor-mode-overriding-map-alist（步驟 3）覆蓋之

(defun claude-code-smart-copy ()
  "M-w：未在 copy 模式時進入；已在 copy 模式時複製選取區並退出。"
  (interactive)
  (if (bound-and-true-p vterm-copy-mode)
      (progn
        (when (use-region-p)
          (kill-ring-save (region-beginning) (region-end))
          (message "已複製到 kill-ring"))
        (vterm-copy-mode -1)
        (setq-local cursor-type nil))
    (claude-code--term-read-only-mode claude-code-terminal-backend)
    (message "Copy 模式：C-SPC 設標記，移動選取，再按 M-w 複製並退出")))

(defun claude-code-paste ()
  "C-y：將 kill-ring 頂端內容貼到 Claude vterm 的輸入區。"
  (interactive)
  (when (bound-and-true-p vterm-copy-mode)
    (vterm-copy-mode -1)
    (setq-local cursor-type nil))
  (if kill-ring
      (vterm-send-string (substring-no-properties (current-kill 0)) t)
    (message "Kill ring 為空")))

;; 層一：正常模式攔截
;; vterm--self-insert-meta 處理 meta 鍵（M-w），vterm--self-insert 處理控制鍵（C-y）
(defun claude-code--intercept-vterm-meta (&rest _)
  "攔截 Claude buffer 正常模式下的 M-w。"
  (when (claude-code--buffer-p (current-buffer))
    (cond
     ((eq last-command-event ?\M-w)
      (call-interactively #'claude-code-smart-copy) t)
     ((eq last-command-event ?\C-y)
      (call-interactively #'claude-code-paste) t))))

(defun claude-code--intercept-vterm-insert (&rest _)
  "攔截 Claude buffer 正常模式下的 C-y。"
  (when (and (claude-code--buffer-p (current-buffer))
             (eq last-command-event ?\C-y))
    (call-interactively #'claude-code-paste) t))

(advice-add 'vterm--self-insert-meta :before-until #'claude-code--intercept-vterm-meta)
(advice-add 'vterm--self-insert      :before-until #'claude-code--intercept-vterm-insert)

;; 層二：Copy 模式攔截
;; minor-mode-overriding-map-alist（步驟 3）> minor-mode-map-alist lsy-kill（步驟 4）
(defvar-local claude-code--copy-paste-active nil
  "Non-nil in Claude buffers to activate the copy/paste overriding keymap.")

(defun claude-code--setup-copy-paste-keys ()
  "設置 copy 模式下的 M-w / C-y，覆蓋 minor-mode-map-alist 裡的自訂 binding。"
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "M-w") #'claude-code-smart-copy)
    (define-key map (kbd "C-y") #'claude-code-paste)
    (setq-local claude-code--copy-paste-active t)
    (setq-local minor-mode-overriding-map-alist
                (cons (cons 'claude-code--copy-paste-active map)
                      minor-mode-overriding-map-alist))))

(add-hook 'claude-code-start-hook #'claude-code--setup-copy-paste-keys)

(provide 'init-claude)
