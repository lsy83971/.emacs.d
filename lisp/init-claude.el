;;; -*- lexical-binding: t; -*-
;; 1. 添加 MELPA（vterm 需要）
(use-package inheritenv
  :ensure t)
;;(use-package eat :ensure t)
(use-package vterm :ensure t)
(add-to-list 'load-path "~/.emacs.d/claude-code-stevemolitor")
(require 'claude-code)
(define-key global-map (kbd "C-c c") 'claude-code-command-map)

(use-package claude-code
  :ensure nil
  :vc (:url "https://github.com/stevemolitor/claude-code.el" :rev :newest)
  :bind-keymap
  ("C-c c" . claude-code-command-map)
  :config
  ;; 文件改动后自动同步 buffer
  (global-auto-revert-mode 1)
  (setq auto-revert-use-notify nil)
  (setq claude-code-terminal-backend 'vterm)

  ;; Claude 窗口佔據當前窗口（不創建額外窗口）
  (setq claude-code-display-window-fn
        (lambda (buffer)
          (display-buffer buffer '(display-buffer-same-window))))

  ;; 👇 啟動時移除 side window 屬性
  (add-hook 'claude-code-start-hook
            (lambda ()
              (when (derived-mode-p 'vterm-mode)
                (set-window-parameter nil 'window-side nil)
                (set-window-parameter nil 'window-slot nil))))

  ;; 標記 Claude buffer 是否正在初始化（需在 advice 之前定義）
  (defvar claude-code--initializing nil
    "標記 Claude buffer 是否正在初始化。")

  ;; 攔截 pop-to-buffer 對 Claude buffer 的調用，一律改用 switch-to-buffer（佔據當前窗口）
  ;; 同時設置 initializing 標記，防止 vterm 內部的 delete-window 關閉該窗口
  (define-advice pop-to-buffer (:around (orig-fn buffer &rest args) claude-code-same-window)
    "所有 Claude buffer 一律在當前窗口顯示，不創建額外窗口。"
    (let* ((buf-name (if (bufferp buffer)
                         (buffer-name buffer)
                       (if (stringp buffer) buffer nil)))
           (is-claude (and buf-name (string-match-p "^\\*claude:" buf-name))))
      (if is-claude
          (progn
            ;; 設置初始化標記，讓 delete-window advice 攔截後續的刪除
            (setq claude-code--initializing t)
            (run-with-timer 0.5 nil (lambda () (setq claude-code--initializing nil)))
            (switch-to-buffer buffer))
        (apply orig-fn buffer args))))

  ;; 阻止 delete-window 刪除 Claude buffer 的窗口（僅在初始化階段）

  (define-advice delete-window (:around (orig-fn &optional window) claude-code-preserve-window)
    "在 Claude 初始化階段阻止刪除 Claude buffer 的窗口。"
    (let* ((win (or window (selected-window)))
           (buf (window-buffer win))
           (buf-name (buffer-name buf)))
        (if (and claude-code--initializing
               buf-name
               (string-match-p "^\\*claude:" buf-name))
          nil  ;; 阻止刪除
        (funcall orig-fn window))))

  ;; 👇 spinner 字符修正（確保這個 hook 存在）
  )

(require 'project)
(add-to-list 'project-find-functions
             (lambda (dir)
               (when (locate-dominating-file dir ".project")
                 (cons 'transient dir))))

;; 修复：切换 vterm-copy-mode 时阻止 Claude CLI 收到 resize 信号
;; 注释掉这个 advice，因为它会干扰 display-buffer-same-window 的行为
;; (define-advice display-buffer (:around (orig-fn buffer &rest args) claude-code-preserve-window)
;;   "当 Claude buffer 已经在某个窗口显示时，不重新 display，保持窗口大小不变。"
;;   (if (and (claude-code--buffer-p buffer)
;;            (get-buffer-window buffer))
;;       ;; 已经可见，直接返回现有窗口，不做任何操作
;;       (get-buffer-window buffer)
;;     ;; 否则正常 display
;;     (apply orig-fn buffer args)))

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


;;;; ============================================================
;;;; Claude 獨立輸入框（Input Buffer）
;;;; ============================================================
;;
;;   C-c c i  → 開啟輸入框（顯示在 Claude 視窗下方，跳至該視窗）
;;   C-RET    → 發送輸入框全部內容至 Claude 並清空
;;   C-up     → 調出上一筆發送記錄
;;   C-down   → 調出下一筆記錄（回到底端時還原編輯中的內容）
;;   RET      → 插入換行（支援多行輸入）
;;
;; 每個 Claude buffer 對應獨立的輸入框，歷史記錄 buffer-local。
;; 輸入框是普通 Emacs buffer，自動補全等功能均可正常使用。
;; Claude 啟動時自動在 Claude 視窗下方彈出輸入框。

(defcustom claude-code-input-window-height 6
  "輸入框視窗高度（行數）。"
  :type 'integer
  :group 'claude-code)

(defvar-local claude-code-input--history '()
  "已發送記錄，最新在最前（去重）。")

(defvar-local claude-code-input--history-index -1
  "歷史導航位置。-1 表示正在編輯新內容，非負整數表示正在查看歷史。")

(defvar-local claude-code-input--saved-input ""
  "進入歷史導航前暫存的當前編輯內容，回到 -1 時還原。")

(defvar-local claude-code-input--target nil
  "此輸入框對應的 Claude buffer 名稱（string）。")

(defun claude-code-input-send ()
  "將輸入框全部內容發送至 Claude 並清空輸入框。"
  (interactive)
  (let ((content (string-trim
                  (buffer-substring-no-properties (point-min) (point-max)))))
    (when (string-empty-p content)
      (user-error "輸入框為空"))
    ;; 加入歷史（去重後置頂）
    (setq claude-code-input--history
          (cons content (delete content claude-code-input--history))
          claude-code-input--history-index -1
          claude-code-input--saved-input "")
    ;; 送出至對應的 Claude vterm
    (let ((claude-buf (and claude-code-input--target
                           (get-buffer claude-code-input--target))))
      (unless (buffer-live-p claude-buf)
        (setq claude-buf (claude-code--get-or-prompt-for-buffer)))
      (if (not (buffer-live-p claude-buf))
          (user-error "找不到 Claude buffer，請先啟動 Claude")
        (with-current-buffer claude-buf
          (when (bound-and-true-p vterm-copy-mode)
            (vterm-copy-mode -1)
            (setq-local cursor-type nil))
          (vterm-send-string content t)
          (vterm-send-return))))
    (erase-buffer)
    (message "已發送至 Claude")))

(defun claude-code-input-history-prev ()
  "調出上一筆（更舊的）歷史記錄。"
  (interactive)
  (unless claude-code-input--history
    (user-error "尚無發送記錄"))
  ;; 首次進入歷史時暫存目前編輯內容
  (when (= claude-code-input--history-index -1)
    (setq claude-code-input--saved-input
          (buffer-substring-no-properties (point-min) (point-max))))
  (if (< (1+ claude-code-input--history-index)
         (length claude-code-input--history))
      (progn
        (setq claude-code-input--history-index
              (1+ claude-code-input--history-index))
        (erase-buffer)
        (insert (nth claude-code-input--history-index claude-code-input--history))
        (goto-char (point-max)))
    (message "已是最舊記錄")))

(defun claude-code-input-history-next ()
  "調出下一筆（更新的）歷史記錄；回到底端時還原編輯中的內容。"
  (interactive)
  (cond
   ((> claude-code-input--history-index 0)
    (setq claude-code-input--history-index
          (1- claude-code-input--history-index))
    (erase-buffer)
    (insert (nth claude-code-input--history-index claude-code-input--history))
    (goto-char (point-max)))
   ((= claude-code-input--history-index 0)
    (setq claude-code-input--history-index -1)
    (erase-buffer)
    (insert claude-code-input--saved-input)
    (goto-char (point-max)))
   (t
    (message "已是最新"))))

(defvar claude-code-input-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-<return>") #'claude-code-input-send)
    (define-key map (kbd "C-r") 
      (lambda () (interactive)
        (when-let ((claude-buf (and claude-code-input--target 
                                    (get-buffer claude-code-input--target))))
          (with-current-buffer claude-buf (vterm-send-return)))))    
    (define-key map (kbd "C-<up>")     #'claude-code-input-history-prev)
    (define-key map (kbd "C-<down>")   #'claude-code-input-history-next)
    map)
  "claude-code-input-mode 按鍵表。")

(define-minor-mode claude-code-input-mode
  "Claude Code 獨立輸入模式。
C-RET 發送，C-up/C-down 瀏覽歷史，RET 換行（支援多行）。"
  :lighter " CI"
  :keymap claude-code-input-mode-map
  (if claude-code-input-mode
      (setq-local header-line-format
                  (list " Claude 輸入 → "
                        '(:eval (or claude-code-input--target "?"))
                        "    C-RET 發送  C-↑ 上一筆  C-↓ 下一筆"))
    (setq-local header-line-format nil)))

(defun claude-code-open-input ()
  "開啟對應當前 Claude instance 的獨立輸入框。
若視窗已存在則直接跳至該視窗。"
  (interactive)
  (let* ((claude-buf  (claude-code--get-or-prompt-for-buffer))
         (input-name  (format "*claude-input%s*"
                              (if claude-buf
                                  (concat ":" (buffer-name claude-buf))
                                "")))
         (input-buf   (get-buffer-create input-name))
         (is-new      (not (buffer-local-value 'claude-code-input-mode input-buf))))
    (with-current-buffer input-buf
      (when is-new
        (claude-code-input-mode 1))
      ;; 更新目標（Claude buffer 可能重啟過）
      (setq-local claude-code-input--target
                  (and claude-buf (buffer-name claude-buf))))
    (if-let ((win (get-buffer-window input-buf)))
        (select-window win)
      (let* ((claude-win (and claude-buf (get-buffer-window claude-buf t)))
             (win (if claude-win
                      (with-selected-window claude-win
                        (display-buffer input-buf
                                        `((display-buffer-reuse-window display-buffer-below-selected)
                                          (window-height . ,claude-code-input-window-height))))
                    (display-buffer input-buf
                                    `((display-buffer-pop-up-window)
                                      (window-height . ,claude-code-input-window-height))))))
        (when win (select-window win))))))

(defun claude-code--auto-open-input ()
  "Claude 啟動時自動在其下方開啟輸入框。"
  (let ((claude-buf (current-buffer)))
    (run-with-timer
     0.3 nil
     (lambda ()
       (when (buffer-live-p claude-buf)
         (let* ((input-name (format "*claude-input:%s*" (buffer-name claude-buf)))
                (input-buf  (get-buffer-create input-name)))
           (with-current-buffer input-buf
             (unless claude-code-input-mode
               (claude-code-input-mode 1))
             (setq-local claude-code-input--target (buffer-name claude-buf)))
           
           (unless (get-buffer-window input-buf t)
             (let ((claude-win (get-buffer-window claude-buf t)))
               (if claude-win
                   (with-selected-window claude-win
                     (display-buffer input-buf
                                     `(display-buffer-below-selected
                                       (window-height . ,claude-code-input-window-height)
                                       (preserve-size . (nil . t)))))  ;; 👈 這裡加了兩個右括號
                 (display-buffer input-buf
                                 `(display-buffer-pop-up-window
                                   (window-height . ,claude-code-input-window-height))))))))))))
(add-hook 'claude-code-start-hook #'claude-code--auto-open-input)

(with-eval-after-load 'claude-code
  (define-key claude-code-command-map (kbd "i") #'claude-code-open-input))

;; ✢ (U+2722) 不在 Sarasa Fixed SC 中，fallback 為 Droid Sans Fallback（行高差 ~11%）
;; 在 Claude buffer 裡用 buffer-display-table 將其替換顯示為 ✽ (U+273D，Sarasa 有）
(defun claude-code--fix-spinner-char ()
  "在 Claude buffer 中將所有特殊 spinner 字符替換為普通星號。
處理的字符：✢ (U+2722), ✻ (U+273B), ✽ (U+273D)"
  (let ((buf (current-buffer)))
    (run-with-timer
     0.5 nil
     `(lambda ()
        (when (buffer-live-p ,buf)
          (with-current-buffer ,buf
            (let ((table (or buffer-display-table (make-display-table))))
              ;; 處理所有三個 spinner 字符
              (aset table ?✢ (vector ?*))  ;; 四瓣淚滴星 → *
              (aset table ?✻ (vector ?*))  ;; 淚滴星 → *
              (aset table ?✽ (vector ?*))  ;; 粗淚滴星 → *
              (setq buffer-display-table table)
              ;; 同時直接替換 buffer 內容
              (save-excursion
                (goto-char (point-min))
                (while (re-search-forward "[✢✻✽]" nil t)
                  (replace-match "*" nil nil))))))))))
(add-hook 'claude-code-start-hook #'claude-code--fix-spinner-char)
(provide 'init-claude)
