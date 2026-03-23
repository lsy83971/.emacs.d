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
  ;;:vc (:url "https://github.com/stevemolitor/claude-code.el" :rev :newest)
  :bind-keymap
  ("C-c c" . claude-code-command-map)
  :config
  ;; 文件改动后自动同步 buffer
  (global-auto-revert-mode 1)
  (setq auto-revert-use-notify nil)
  (setq claude-code-terminal-backend 'vterm)

  ;; 把当前 Emacs 的 server-name 传给 Claude Code，
  ;; 让 MCP server 知道该连哪个 daemon
  (add-hook 'claude-code-process-environment-functions
            (lambda (_buffer-name _dir)
              (unless (bound-and-true-p server-process)
                (server-start))
              (list (format "EMACS_SOCKET_NAME=%s" server-name))))

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
    "所有 Claude buffer 一律在當前窗口顯示，不創建額外窗口。
批量靜默創建（`claude-group--pending-suppress' 非 nil）時走原始
`pop-to-buffer'，避免搶佔當前窗口。"
    (let* ((buf-name (if (bufferp buffer)
                         (buffer-name buffer)
                       (if (stringp buffer) buffer nil)))
           (is-claude (and buf-name (string-match-p "^\\*claude:" buf-name))))
      (if (not is-claude)
          (apply orig-fn buffer args)
        (if (bound-and-true-p claude-group--pending-suppress)
            ;; 靜默模式：走原始 pop-to-buffer，讓 vterm 量窗口寬度，
            ;; 之後 delete-window 會關掉臨時窗口
            (progn
              (setq claude-code--initializing nil)
              (apply orig-fn buffer args))
          ;; 正常模式：佔據當前窗口
          (setq claude-code--initializing t)
          (run-with-timer 0.5 nil (lambda () (setq claude-code--initializing nil)))
          (switch-to-buffer buffer)))))

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
      (let ((win-start (window-start))
            (saved-point (point)))
        (when (use-region-p)
          (let* ((raw (buffer-substring (region-beginning) (region-end)))
                 (cleaned (vterm--filter-buffer-substring raw)))
            (kill-new cleaned)
            (deactivate-mark))
          (message "已複製到 kill-ring"))
        (vterm-copy-mode -1)
        (setq-local cursor-type nil)
        ;; vterm--exit-copy-mode 会调 vterm-reset-cursor-point 把 point 跳到末尾
        ;; 必须同时恢复 point 和 window-start，否则 redisplay 会跟随 point 滚动
        (goto-char (min saved-point (point-max)))
        (set-window-start nil (min win-start (point-max)) t))
    ;; 保存當前視野位置，進入 copy 模式後恢復
    (let ((win-start (window-start))
          (win-point (window-point)))
      (claude-code--term-read-only-mode claude-code-terminal-backend)
      (set-window-start nil win-start t)
      (goto-char (max win-point win-start)))
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

(defun claude-code--input-buffer-name (claude-buf)
  "根据 CLAUDE-BUF 生成对应的 input buffer 名称。
格式：*input:<角色名>*，无角色名时用 buffer 名。"
  (let ((cid (and claude-buf (claude-code--get-character-id claude-buf))))
    (format "*input:%s*" (or cid (if claude-buf (buffer-name claude-buf) "?")))))

(defun claude-code-open-input ()
  "開啟對應當前 Claude instance 的獨立輸入框。
若視窗已存在則直接跳至該視窗。"
  (interactive)
  (let* ((claude-buf  (claude-code--get-or-prompt-for-buffer))
         (input-name  (claude-code--input-buffer-name claude-buf))
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
  "Claude 啟動時自動在其下方開啟輸入框。

若 Claude buffer 有 buffer-local 變量 `claude-group--no-display' 為非 nil，
只創建 input buffer 但不彈出窗口。"
  (let* ((claude-buf (current-buffer))
         (suppress (and (local-variable-p 'claude-group--no-display claude-buf)
                        (buffer-local-value 'claude-group--no-display claude-buf))))
    (run-with-timer
     0.3 nil
     (lambda ()
       (when (buffer-live-p claude-buf)
         (let* ((input-name (claude-code--input-buffer-name claude-buf))
                (input-buf  (get-buffer-create input-name)))
           (with-current-buffer input-buf
             (unless claude-code-input-mode
               (claude-code-input-mode 1))
             (setq-local claude-code-input--target (buffer-name claude-buf)))
           ;; suppress 时只创建 buffer，不弹窗
           (unless (or suppress (get-buffer-window input-buf t))
             (let ((claude-win (get-buffer-window claude-buf t)))
               (if claude-win
                   (with-selected-window claude-win
                     (display-buffer input-buf
                                     `(display-buffer-below-selected
                                       (window-height . ,claude-code-input-window-height)
                                       (preserve-size . (nil . t)))))
                 (display-buffer input-buf
                                 `(display-buffer-pop-up-window
                                   (window-height . ,claude-code-input-window-height))))))))))))
(add-hook 'claude-code-start-hook #'claude-code--auto-open-input)

(defun claude-code--auto-kill-input ()
  "Claude buffer 关闭时自动关闭对应的 input buffer。"
  (let ((input-buf (get-buffer (claude-code--input-buffer-name (current-buffer)))))
    (when (buffer-live-p input-buf)
      (let ((win (get-buffer-window input-buf t)))
        (when win (delete-window win)))
      (kill-buffer input-buf))))

(add-hook 'claude-code-start-hook
          (lambda ()
            (add-hook 'kill-buffer-hook #'claude-code--auto-kill-input nil t)))

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
(require 'claude-code-manager)
(with-eval-after-load 'claude-code
  (define-key claude-code-command-map (kbd "L") #'claude-code-manager))

;;;; ============================================================
;;;; Claude 实例间通信（Inter-Instance Communication）
;;;; ============================================================
;;
;;   允许 Claude Code 实例 A 通过 emacsclient 向实例 B 发送消息。
;;
;;   用法（在 Claude Code 的 shell 中）：
;;
;;   # 列出所有可用的 Claude 实例
;;   emacsclient --eval '(claude-code-ipc-list)'
;;
;;   # 向指定实例发送消息
;;   emacsclient --eval '(claude-code-ipc-send "*claude:~/.emacs.d*" "请帮我检查 init.el")'
;;
;;   # 通过关键词模糊匹配实例名发送消息
;;   emacsclient --eval '(claude-code-ipc-send "emacs" "请帮我检查 init.el")'

(defun claude-code-ipc-list ()
  "返回所有 Claude Code 实例的 alist：((buffer-name . 角色名) ...)。
角色名即 instance name。可通过 emacsclient --eval 调用。"
  (mapcar (lambda (b)
            (cons (buffer-name b)
                  (claude-code--get-character-id b)))
          (claude-code--find-all-claude-buffers)))

(defun claude-code-ipc--find-buffer (target)
  "根据 TARGET 查找 Claude buffer。
TARGET 可以是精确 buffer 名、角色名（instance name）、或模糊关键词。"
  (or (get-buffer target)
      ;; 角色名（instance name）精确匹配
      (let ((bufs (claude-code--find-all-claude-buffers)))
        (cl-find-if (lambda (b)
                      (let ((cid (claude-code--get-character-id b)))
                        (and cid (string= cid target))))
                    bufs))
      ;; 模糊 buffer 名子串匹配
      (let ((bufs (claude-code--find-all-claude-buffers)))
        (cl-find-if (lambda (b)
                      (string-match-p (regexp-quote target) (buffer-name b)))
                    bufs))))

(defun claude-code-ipc-send (target message)
  "向 TARGET 指定的 Claude 实例发送 MESSAGE。
TARGET 可以是精确 buffer 名（如 \"*claude:~/.emacs.d*\"），
也可以是模糊关键词（如 \"emacs\"）。
返回发送结果描述字符串。

用法示例：
  emacsclient --eval \\='(claude-code-ipc-send \"emacs\" \"你好\")\\='"
  (let ((buf (claude-code-ipc--find-buffer target)))
    (cond
     ((not buf)
      (format "ERROR: 找不到匹配 \"%s\" 的 Claude 实例。可用实例: %s"
              target (claude-code-ipc-list)))
     ((not (buffer-live-p buf))
      (format "ERROR: buffer \"%s\" 已失效" target))
     (t
      (with-current-buffer buf
        (when (bound-and-true-p vterm-copy-mode)
          (vterm-copy-mode -1)
          (setq-local cursor-type nil))
        (vterm-send-string message t)
        (let ((b buf))
          (run-with-timer 0.1 nil
                          (lambda ()
                            (when (buffer-live-p b)
                              (with-current-buffer b
                                (vterm-send-return)))))))
      (format "OK: 已发送至 %s" (buffer-name buf))))))

;;;; ============================================================
;;;; Character ID 系统（复用 instance name）
;;;; ============================================================
;;
;;   每个 Claude 实例启动时必须输入角色名，作为 instance name。
;;   Buffer 格式：*claude:~/dir:角色名*
;;   角色名 = instance name = character_id，三者合一。

;; 强制每次启动都提示输入 instance name（角色名）
(defun claude-code--force-prompt-instance-name (orig-fn dir existing-instance-names &optional _force-prompt)
  "始终强制提示输入 instance name。"
  (funcall orig-fn dir existing-instance-names t))

(advice-add 'claude-code--prompt-for-instance-name :around
            #'claude-code--force-prompt-instance-name)

(defun claude-code--get-character-id (buf)
  "获取 BUF 的角色名（即 instance name）。"
  (claude-code--extract-instance-name-from-buffer-name (buffer-name buf)))

(defun claude-code-rename-character-id ()
  "修改当前或选定 Claude 实例的角色名（instance name）。"
  (interactive)
  (let* ((buf (if (claude-code--buffer-p (current-buffer))
                  (current-buffer)
                (claude-code--get-or-prompt-for-buffer)))
         (old-name (buffer-name buf))
         (old-id (claude-code--get-character-id buf))
         (dir (claude-code--extract-directory-from-buffer-name old-name))
         (new-id (read-string "新角色名: " old-id))
         (new-name (if (string-empty-p new-id)
                       (format "*claude:%s*" dir)
                     (format "*claude:%s:%s*" dir new-id)))
         (old-input-name (claude-code--input-buffer-name buf))
         (input-buf (get-buffer old-input-name)))
    (unless (string= old-name new-name)
      (with-current-buffer buf
        (rename-buffer new-name t))
      ;; 同步更新 input buffer
      (when (buffer-live-p input-buf)
        (let ((new-input-name (claude-code--input-buffer-name buf)))
          (with-current-buffer input-buf
            (setq-local claude-code-input--target (buffer-name buf))
            (rename-buffer new-input-name t)))))))

(with-eval-after-load 'claude-code
  (define-key claude-code-command-map (kbd "r") #'claude-code-rename-character-id))

;;;; ============================================================
;;;; Heartbeat Timer（防空闲提醒）
;;;; ============================================================
;;
;;   监控 Claude buffer，若检测到空闲则自动发送提醒。
;;   M-x claude-code-toggle-heartbeat  或  C-c c h  启停。

(defcustom claude-code-heartbeat-interval 120
  "Heartbeat 默认间隔（秒）。
`C-u C-c c h' 可临时指定间隔，否则使用此值。"
  :type 'integer
  :group 'claude-code)

(defvar claude-code--heartbeat-timers nil
  "Heartbeat timer alist: ((buffer . timer) ...)。")

(defvar-local claude-code--heartbeat-last-size nil
  "上次 tick 时 buffer 的 point-max 值。")

(defvar-local claude-code--heartbeat-idle-count 0
  "连续未变化的 tick 次数。需连续 2 次无变化才判定空闲。")

(defvar-local claude-code--heartbeat-interval-secs nil
  "当前 buffer 的 heartbeat 间隔（秒），用于 modeline 显示。")

(defun claude-code--heartbeat-tick (buf)
  "Heartbeat tick：检查 BUF 是否空闲，空闲则发送提醒。
用 buffer size (point-max) 判断变化——vterm 有内容输出时 point-max 必然变化，
而光标闪烁、spinner 不影响 point-max。连续 2 次 tick 无变化才判定空闲。"
  (condition-case err
      (if (not (buffer-live-p buf))
          (claude-code--heartbeat-stop buf)
        (with-current-buffer buf
          (let* ((cur-size (point-max))
                 (last-size (or claude-code--heartbeat-last-size 0))
                 (changed (/= cur-size last-size)))
            (setq claude-code--heartbeat-last-size cur-size)
            (if changed
                (setq claude-code--heartbeat-idle-count 0)
              (setq claude-code--heartbeat-idle-count
                    (1+ claude-code--heartbeat-idle-count))
              (when (>= claude-code--heartbeat-idle-count 2)
                (ignore-errors
                  (append-to-file
                   (format "[%s] >>> 触发提醒(idle=%d): %s\n"
                           (format-time-string "%H:%M:%S")
                           claude-code--heartbeat-idle-count
                           (buffer-name buf))
                   nil "/tmp/heartbeat-debug.log"))
                (condition-case send-err
                    (progn
                      (claude-code-ipc-send
                       (buffer-name buf)
                       "[系统提醒] 请继续推进工作。")
                      (message "[heartbeat] 已提醒: %s" (buffer-name buf)))
                  (error
                   (ignore-errors
                     (append-to-file
                      (format "[%s] !!! 提醒失败: %s\n"
                              (format-time-string "%H:%M:%S")
                              (error-message-string send-err))
                      nil "/tmp/heartbeat-debug.log"))))
                (setq claude-code--heartbeat-idle-count 0))))))
    (error
     (ignore-errors
       (append-to-file
        (format "[%s] !!! tick 异常: %s\n"
                (format-time-string "%H:%M:%S")
                (error-message-string err))
        nil "/tmp/heartbeat-debug.log")))))

(defun claude-code--heartbeat-stop (buf)
  "停止 BUF 的 heartbeat timer 并从 alist 中移除，清理 modeline。"
  (let ((entry (assq buf claude-code--heartbeat-timers)))
    (when entry
      (cancel-timer (cdr entry))
      (setq claude-code--heartbeat-timers
            (delq entry claude-code--heartbeat-timers))
      (when (buffer-live-p buf)
        (with-current-buffer buf
          (setq claude-code--heartbeat-interval-secs nil))
        ;; 同步清理 input buffer 的 modeline
        (let ((input-buf (get-buffer (claude-code--input-buffer-name buf))))
          (when (buffer-live-p input-buf)
            (with-current-buffer input-buf
              (setq claude-code--heartbeat-interval-secs nil))))))))

(defun claude-code--heartbeat-modeline ()
  "返回 heartbeat modeline 标识字符串。"
  (if claude-code--heartbeat-interval-secs
      (propertize (format "♥%dm " (/ claude-code--heartbeat-interval-secs 60))
                  'face '(:foreground "#e74c3c"))
    ""))

(defun claude-code--heartbeat-get-claude-buffer ()
  "获取当前关联的 Claude buffer。
支持在 Claude buffer 或其 input buffer 中调用。"
  (cond
   ((claude-code--buffer-p (current-buffer))
    (current-buffer))
   ((bound-and-true-p claude-code-input--target)
    (get-buffer claude-code-input--target))
   (t nil)))

(defun claude-code-toggle-heartbeat ()
  "切换当前 Claude buffer 的 heartbeat 监控。
在 Claude buffer 或其 input buffer 中执行。
启用时提示输入间隔分钟数（默认 2）。"
  (interactive)
  (let ((buf (claude-code--heartbeat-get-claude-buffer)))
    (unless buf
      (user-error "请在 Claude buffer 或其 input buffer 中执行"))
    (let ((entry (assq buf claude-code--heartbeat-timers)))
      (if entry
          ;; 已监控 → 停止
          (progn
            (claude-code--heartbeat-stop buf)
            (force-mode-line-update t)
            (message "[heartbeat] 已停用: %s" (buffer-name buf)))
        ;; 未监控 → 启动
        (let* ((seconds (* (read-number "间隔(分钟): " 2) 60))
               (timer (run-with-timer seconds seconds
                                      #'claude-code--heartbeat-tick buf)))
          (with-current-buffer buf
            (setq claude-code--heartbeat-last-size (point-max))
            (setq claude-code--heartbeat-idle-count 0)
            (setq claude-code--heartbeat-interval-secs seconds))
          ;; 同步设置 input buffer
          (let ((input-buf (get-buffer (claude-code--input-buffer-name buf))))
            (when (buffer-live-p input-buf)
              (with-current-buffer input-buf
                (setq claude-code--heartbeat-interval-secs seconds))))
          (push (cons buf timer) claude-code--heartbeat-timers)
          ;; 确保 modeline 标识存在
          (claude-code--heartbeat-ensure-modeline buf)
          (let ((input-buf2 (get-buffer (claude-code--input-buffer-name buf))))
            (claude-code--heartbeat-ensure-modeline input-buf2))
          (force-mode-line-update t)
          (message "[heartbeat] 已启用: %s (每%d分钟)"
                   (buffer-name buf) (/ seconds 60)))))))

;; modeline 标识：在 toggle 时直接注入到对应 buffer 的 mode-line-format 最前面
(defun claude-code--heartbeat-ensure-modeline (buf)
  "确保 BUF 的 modeline 最前面有 heartbeat 标识。"
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (let ((indicator '(:eval (claude-code--heartbeat-modeline))))
        (unless (member indicator mode-line-format)
          (setq mode-line-format (cons indicator mode-line-format)))))))

;; buffer 关闭时自动清理 heartbeat timer
(add-hook 'claude-code-start-hook
          (lambda ()
            (add-hook 'kill-buffer-hook
                      (lambda ()
                        (claude-code--heartbeat-stop (current-buffer)))
                      nil t)))

(with-eval-after-load 'claude-code
  (define-key claude-code-command-map (kbd "h") #'claude-code-toggle-heartbeat))

(require 'claude-code-logger)
(require 'init-claude-group)

(provide 'init-claude)
