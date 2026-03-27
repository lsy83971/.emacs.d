;;; -*- lexical-binding: t; -*-
(use-package inheritenv
  :ensure t)
(use-package vterm
  :ensure t
  :config
  ;; 终端里显示行号没意义，且 vterm--get-margin-width 估算不准
  ;; 导致 PTY 宽度和 libvterm 渲染宽度不同步 → 乱码
  (add-hook 'vterm-mode-hook (lambda () (display-line-numbers-mode -1))))
(add-to-list 'load-path "~/.emacs.d/claude-code-stevemolitor")
(require 'claude-code)

(defun claude-code--ensure-server ()
  "确保 Emacs server 已启动，返回当前 server-name。
避免默认名 \"server\" 与其他 Emacs 实例冲突，改为 \"server-<pid>\"。"
  (unless (bound-and-true-p server-process)
    (when (string= server-name "server")
      (setq server-name (format "server-%d" (emacs-pid))))
    (server-start))
  server-name)

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
              (list (format "EMACS_SOCKET_NAME=%s" (claude-code--ensure-server))
                    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50")))

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
      (if (not is-claude)
          (apply orig-fn buffer args)
        (setq claude-code--initializing t)
        (run-with-timer 0.5 nil (lambda () (setq claude-code--initializing nil)))
        (switch-to-buffer buffer))))

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

  ;; ── 修复 PTY 与 libvterm 宽度不同步 ──
  ;; vterm 内部用 window-body-width 设 PTY，再减 margin 设 libvterm，
  ;; 二者不一致导致 Claude 按 PTY 宽度渲染的内容在 libvterm 处被截断换行 → 乱码。
  ;; 修法：在 vterm 设完 libvterm 后，把 PTY 也同步成 libvterm 的宽度。
  (defun claude-code--sync-pty-to-vterm (process windows)
    "在 vterm 更新 libvterm 宽度后，同步 PTY 内核宽度到相同值。"
    (when-let* ((buf (and (processp process)
                          (process-live-p process)
                          (process-buffer process)))
                (_ (buffer-live-p buf))
                (_ (claude-code--buffer-p buf))
                (win (car windows)))
      (with-current-buffer buf
        (with-selected-window win
          (let* ((mc (window-max-chars-per-line))
                 (margin (vterm--get-margin-width))
                 (correct-width (max (- mc margin) vterm-min-window-width))
                 (h (window-body-height win)))
            (set-process-window-size process h correct-width))))))
  (advice-add 'vterm--window-adjust-process-window-size
              :after #'claude-code--sync-pty-to-vterm)
  )

(require 'project)
(add-to-list 'project-find-functions
             (lambda (dir)
               (when (locate-dominating-file dir ".project")
                 (cons 'transient dir))))

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

(defun claude-code--exit-copy-mode ()
  "若当前 buffer 处于 vterm-copy-mode，退出之。"
  (when (bound-and-true-p vterm-copy-mode)
    (vterm-copy-mode -1)
    (setq-local cursor-type nil)))

(defun claude-code-paste ()
  "C-y：將 kill-ring 頂端內容貼到 Claude vterm 的輸入區。"
  (interactive)
  (claude-code--exit-copy-mode)
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
          (claude-code--exit-copy-mode)
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
格式：*claude-input:CLAUDE-BUF-NAME*。"
  (let ((cid (and claude-buf (claude-code--get-character-id claude-buf))))
    (format "*input:%s*" (or cid (if claude-buf (buffer-name claude-buf) "?")))))

(defun claude-code--get-or-create-input-buf (claude-buf)
  "为 CLAUDE-BUF 获取或创建 input buffer，确保 mode 和 target 已设置。"
  (let ((input-buf (get-buffer-create (claude-code--input-buffer-name claude-buf))))
    (with-current-buffer input-buf
      (unless claude-code-input-mode
        (claude-code-input-mode 1))
      (setq-local claude-code-input--target
                  (and claude-buf (buffer-name claude-buf))))
    input-buf))

(defun claude-code--display-input-below (claude-buf input-buf)
  "在 CLAUDE-BUF 的窗口下方显示 INPUT-BUF。已可见则不重复显示。"
  (unless (get-buffer-window input-buf t)
    (let ((claude-win (get-buffer-window claude-buf t)))
      (if claude-win
          (with-selected-window claude-win
            (display-buffer input-buf
                            `(display-buffer-below-selected
                              (window-height . ,claude-code-input-window-height)
                              (preserve-size . (nil . t)))))
        (display-buffer input-buf
                        `(display-buffer-pop-up-window
                          (window-height . ,claude-code-input-window-height)))))))

(defun claude-code-open-input ()
  "開啟對應當前 Claude instance 的獨立輸入框。
若視窗已存在則直接跳至該視窗。"
  (interactive)
  (let* ((claude-buf (claude-code--get-or-prompt-for-buffer))
         (input-buf  (claude-code--get-or-create-input-buf claude-buf)))
    (if-let ((win (get-buffer-window input-buf)))
        (select-window win)
      (when-let ((win (claude-code--display-input-below claude-buf input-buf)))
        (select-window win)))))

(defun claude-code--auto-open-input ()
  "Claude 啟動時自動在其下方開啟輸入框。
若 buffer 有 `claude-group--no-display' 標記，只創建 buffer 不彈窗。"
  (let ((claude-buf (current-buffer)))
    (run-with-timer
     0.3 nil
     (lambda ()
       (when (buffer-live-p claude-buf)
         (let ((input-buf (claude-code--get-or-create-input-buf claude-buf))
               (suppress (ignore-errors (buffer-local-value 'claude-group--no-display claude-buf))))
           (unless suppress
             (claude-code--display-input-below claude-buf input-buf))))))))
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
;;;; k8s topic（buffer-local，供 MCP server 查询）
;;;; ============================================================

(defvar-local claude-code--k8s-topic nil
  "当前 Claude buffer 所属的 k8s topic（buffer-local）。
由 `claude-group--start-instance' 在 buffer 创建时设置，
k8s MCP server 通过 emacsclient 查询此值。")

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
        ;; 用 process-send-string 直接发送，避免 vterm-send-string 的 accept-process-output 阻塞。
        ;; 回车不能和消息合并发送——Claude CLI 需要先处理完消息字节才能识别 \C-m 为提交触发器。
        ;; 用递归 timer 每 20ms 轮询 point-max，检测到 CLI echo 输出后（buffer 有变化）再发回车，
        ;; 避免固定延迟，超时 2s 强制提交。
        (let* ((proc vterm--process)
               (old-max (point-max))
               (deadline (time-add (current-time) 2.0))
               (check-fn nil))
          (setq check-fn
                (lambda ()
                  (if (not (buffer-live-p buf))
                      nil
                    (with-current-buffer buf
                      (if (or (> (point-max) old-max)
                              (time-less-p deadline (current-time)))
                          (process-send-string proc "\C-m")
                        (run-with-timer 0.02 nil check-fn))))))
          (process-send-string proc message)
          (run-with-timer 0.02 nil check-fn))
        (format "OK: 已发送至 %s" (buffer-name buf)))))))


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

(defvar-local claude-code--heartbeat-pending nil
  "非 nil 表示已发送提醒但尚未被消费（buffer 无变化），阻止重复发送。")

(defvar-local claude-code--heartbeat-interval-secs nil
  "当前 buffer 的 heartbeat 间隔（秒），用于 modeline 显示。")

(defun claude-code--heartbeat-tick (buf)
  "Heartbeat tick：检查 BUF 是否空闲，空闲则发送提醒。
用 buffer size (point-max) 判断变化——vterm 有内容输出时 point-max 必然变化，
而光标闪烁、spinner 不影响 point-max。连续 2 次 tick 无变化才判定空闲。"
  (if (not (buffer-live-p buf))
      (claude-code--heartbeat-stop buf)
    (with-current-buffer buf
      (let* ((cur-size (point-max))
             (last-size (or claude-code--heartbeat-last-size 0))
             (changed (/= cur-size last-size)))
        (setq claude-code--heartbeat-last-size cur-size)
        (if changed
            (progn
              (setq claude-code--heartbeat-idle-count 0)
              (setq claude-code--heartbeat-pending nil))
          (setq claude-code--heartbeat-idle-count
                (1+ claude-code--heartbeat-idle-count))
          (when (and (>= claude-code--heartbeat-idle-count 2)
                     (not claude-code--heartbeat-pending))
            (condition-case nil
                (progn
                  (claude-code-ipc-send
                   (buffer-name buf)
                   "[系统提醒] 请继续推进工作。")
                  (setq claude-code--heartbeat-pending t)
                  (message "[heartbeat] 已提醒: %s" (buffer-name buf)))
              (error
               (message "[heartbeat] 提醒失败: %s" (buffer-name buf))))
            (setq claude-code--heartbeat-idle-count 0)))))))

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
      (propertize (format "♥%ds " claude-code--heartbeat-interval-secs)
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
        (let* ((seconds (read-number "间隔(秒): " 120))
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
          (message "[heartbeat] 已启用: %s (每%ds)"
                   (buffer-name buf) seconds))))))

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

;;;; ============================================================
;;;; 刷新 session（删除 topic 文件以生成新 session-id）
;;;; ============================================================

(defun claude-code-refresh-session ()
  "刷新当前 Claude 实例的 session。
删除对应的 topic 文件，下次 resume 会生成新 session-id。"
  (interactive)
  (let* ((buf (current-buffer))
         (buf-name (buffer-name buf)))
    (if (not (claude-code--buffer-p buf))
        (message "当前 buffer 不是 Claude 实例")
      (let* ((topic-name (read-string "输入 topic 名（留空则取消）: "))
             (project-dir (buffer-local-value 'default-directory buf)))
        (if (string-empty-p topic-name)
            (message "已取消")
          (if (y-or-n-p (format "删除 topic '%s' 的 session 文件吗？下次 resume 会创建新 session。" topic-name))
              (let ((topic-file (expand-file-name
                                 (concat topic-name ".json")
                                 (expand-file-name
                                  (replace-regexp-in-string "/" "-" (directory-file-name project-dir))
                                  "~/.claude/topics/"))))
                (if (file-exists-p topic-file)
                    (progn
                      (delete-file topic-file)
                      (message "已删除 session 文件: %s" topic-file))
                  (message "未找到 session 文件: %s" topic-file)))
            (message "已取消"))))))))

(with-eval-after-load 'claude-code
  (define-key claude-code-command-map (kbd "R") #'claude-code-refresh-session))

(require 'claude-code-logger)
(require 'init-claude-group)

(provide 'init-claude)
