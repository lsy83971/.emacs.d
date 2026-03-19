;;; init-claude-group.el --- 从 org 文件批量创建 Claude 角色实例  -*- lexical-binding: t; -*-
;;
;; 用法：M-x claude-group-start-from-org  或  C-c c g
;;
;; org 文件格式：
;;   * 角色名
;;   提示词内容...
;;
;;   * 另一个角色名
;;   提示词内容...
;;
;; 每个一级标题对应一个 Claude 实例，标题作为 character_id（实例名），
;; 标题下方全部内容通过 --append-system-prompt 传给 Claude CLI，
;; 同时告知实例自己的 character_id。
;;
;; 高级格式（可选 :PROPERTIES:）：
;;   * 角色名
;;   :PROPERTIES:
;;   :MCP_CONFIG: /path/to/mcp.json
;;   :MODEL: sonnet
;;   :ALLOWED_TOOLS: Bash,Read,Edit
;;   :END:
;;   提示词内容...

;;; ============================================================
;;; 解析 org 文件
;;; ============================================================

(defun claude-group--parse-org (file)
  "从 FILE 解析 org 文件，返回角色定义列表。

每个元素是 plist：(:name role-name :prompt text :props ((key . val) ...))。
一级标题为角色名，标题后的 :PROPERTIES: ... :END: 块提取为属性，
其余内容为提示词。"
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let (roles current-name current-props current-lines in-properties)
      (while (not (eobp))
        (let ((line (buffer-substring-no-properties
                     (line-beginning-position) (line-end-position))))
          (cond
           ;; 新的一级标题
           ((string-match "^\\* \\(.+\\)$" line)
            (when current-name
              (push (list :name current-name
                          :prompt (string-trim
                                   (mapconcat #'identity (nreverse current-lines) "\n"))
                          :props (nreverse current-props))
                    roles))
            (setq current-name (string-trim (match-string 1 line))
                  current-props nil
                  current-lines nil
                  in-properties nil))
           ;; :PROPERTIES: 块开始
           ((and current-name (string-match-p "^\\s-*:PROPERTIES:\\s-*$" line))
            (setq in-properties t))
           ;; :END: 块结束
           ((and in-properties (string-match-p "^\\s-*:END:\\s-*$" line))
            (setq in-properties nil))
           ;; :PROPERTIES: 内的属性行
           ((and in-properties
                 (string-match "^\\s-*:\\([^:]+\\):\\s-*\\(.*\\)$" line))
            (push (cons (upcase (string-trim (match-string 1 line)))
                        (string-trim (match-string 2 line)))
                  current-props))
           ;; 普通内容行
           (current-name
            (unless in-properties
              (push line current-lines)))))
        (forward-line 1))
      ;; 保存最后一个角色
      (when current-name
        (push (list :name current-name
                    :prompt (string-trim
                             (mapconcat #'identity (nreverse current-lines) "\n"))
                    :props (nreverse current-props))
              roles))
      (nreverse roles))))

;;; ============================================================
;;; 绕过交互式实例名提示
;;; ============================================================

(defvar claude-group--preset-instance-name nil
  "批量创建时预设的实例名，非 nil 时跳过交互式提示直接使用此名称。")


(defun claude-group--instance-name-override (orig-fn dir existing &optional force)
  "若 `claude-group--preset-instance-name' 已设置，直接返回该值，跳过提示。"
  (if claude-group--preset-instance-name
      claude-group--preset-instance-name
    (funcall orig-fn dir existing force)))

(advice-add 'claude-code--prompt-for-instance-name :around
            #'claude-group--instance-name-override
            '((name . claude-group-override) (depth . 100)))

;;; ============================================================
;;; 动态 MCP 配置：让每个 Claude 实例连接到正确的 Emacs server
;;; ============================================================

(defun claude-group--emacs-server-name ()
  "返回当前 Emacs 的 server socket 名称。"
  (if (bound-and-true-p server-name)
      server-name
    "server"))

(defun claude-group--mcp-config-for-server (socket-name)
  "为 SOCKET-NAME 生成 MCP 配置 JSON 文件路径，不存在则创建。
返回 JSON 文件的路径。文件缓存在 /tmp/ 下，同名 server 复用。"
  (let ((config-file (expand-file-name
                      (format "claude-mcp-emacs-%s.json" socket-name)
                      temporary-file-directory)))
    ;; 每次都重新写入，确保内容最新
    (with-temp-file config-file
      (insert (json-encode
               `(("mcpServers"
                  . (("emacs-eval"
                      . (("type" . "stdio")
                         ("command" . "python3")
                         ("args" . ["/root/.emacs.d/mcp/emacs-eval-server.py"])
                         ("env" . (("EMACS_SOCKET_NAME" . ,socket-name)))))))))))
    config-file))

(defun claude-group--auto-mcp-switches ()
  "返回 --mcp-config 参数列表，指向当前 Emacs server 的 MCP 配置。"
  (let* ((socket (claude-group--emacs-server-name))
         (config-file (claude-group--mcp-config-for-server socket)))
    (list "--mcp-config" config-file)))

;;; ============================================================
;;; 为所有 Claude 实例自动注入正确的 MCP 配置
;;; ============================================================

(defun claude-group--inject-mcp-config (orig-fn arg extra-switches &optional force-prompt force-switch-to-buffer)
  "Advice：在 claude-code--start 的 extra-switches 中自动注入 --mcp-config。
确保每个 Claude 实例连接到启动它的那个 Emacs server。"
  (let ((mcp-switches (claude-group--auto-mcp-switches)))
    (funcall orig-fn arg
             (append (or extra-switches nil) mcp-switches)
             force-prompt force-switch-to-buffer)))

(with-eval-after-load 'claude-code
  (advice-add 'claude-code--start :around #'claude-group--inject-mcp-config))

;;; ============================================================
;;; 构建 CLI 参数
;;; ============================================================

(defun claude-group--build-switches (role-name prompt props)
  "为角色构建 Claude CLI 的额外参数列表。

ROLE-NAME 是角色名/character_id，PROMPT 是角色提示词，
PROPS 是从 org :PROPERTIES: 解析的 alist。

生成的参数包括：
  --append-system-prompt  角色提示词 + character_id 信息
  --mcp-config           MCP 配置文件（来自 props 或 defcustom）
  --model                模型（来自 props）
  --allowed-tools        工具白名单（来自 props）"
  (let ((switches nil)
        (system-prompt prompt)
        (mcp-config (or (cdr (assoc "MCP_CONFIG" props))
                        claude-group-mcp-config))
        (model (cdr (assoc "MODEL" props)))
        (allowed-tools (cdr (assoc "ALLOWED_TOOLS" props))))
    ;; 注意：push + nreverse 模式下，先 push 的排在最后。
    ;; 因此 flag 要后 push（排在前面），value 先 push（排在后面）。
    ;; --append-system-prompt: 角色提示词
    ;; 必须 shell-quote，因为 vterm 用 mapconcat 拼 shell 命令，
    ;; 不转义的话空格和换行会拆散参数
    (push "--append-system-prompt" switches)
    (push (shell-quote-argument system-prompt) switches)
    ;; --mcp-config（可选）
    (when (and mcp-config (not (string-empty-p mcp-config)))
      (push "--mcp-config" switches)
      (push mcp-config switches))
    ;; --model（可选）
    (when (and model (not (string-empty-p model)))
      (push "--model" switches)
      (push model switches))
    ;; --allowed-tools（可选）
    (when (and allowed-tools (not (string-empty-p allowed-tools)))
      (push "--allowedTools" switches)
      (push allowed-tools switches))
    (nreverse switches)))

;;; ============================================================
;;; 启动单个实例
;;; ============================================================

(defvar claude-group--retry-interval 0.5
  "Minibuffer 活跃时重试的间隔秒数。")

(defun claude-group--safe-start-instance (dir role-name switches is-first)
  "安全启动实例：如果 minibuffer 活跃则延迟重试，避免栈溢出。
Emacs timer 会在 `read-from-minibuffer' 期间触发，此时调用栈已经
很深（ivy/helm 等补全框架额外压入 ~16 帧），加上 vterm-mode 初始化
本身接近 max-lisp-eval-depth，容易触发 1601 溢出。"
  (if (active-minibuffer-window)
      ;; minibuffer 活跃，延迟重试
      (progn
        (message "[claude-group] 角色 %s 等待 minibuffer 关闭..." role-name)
        (run-with-timer claude-group--retry-interval nil
                        (lambda ()
                          (claude-group--safe-start-instance
                           dir role-name switches is-first))))
    ;; minibuffer 不活跃，正常启动
    (let ((existing (claude-group--find-existing role-name)))
      (if existing
          (message "[claude-group] 角色 %s 已存在（buffer: %s），跳过"
                   role-name (buffer-name existing))
        (condition-case err
            (let ((buf (claude-group--start-instance
                        dir role-name switches (not is-first))))
              (if (buffer-live-p buf)
                  (message "[claude-group] 已启动角色：%s" role-name)
                (message "[claude-group] 角色 %s 启动失败：buffer 不存在" role-name)))
          (error
           (message "[claude-group] 角色 %s 启动出错：%s"
                    role-name (error-message-string err))))))))

(defun claude-group--find-existing (role-name)
  "查找 character-id 等于 ROLE-NAME 的已有 Claude buffer，不存在返回 nil。"
  (cl-find-if (lambda (buf)
                (string= (claude-code--get-character-id buf) role-name))
              (claude-code--find-all-claude-buffers)))

(defun claude-group--mark-no-display ()
  "在 claude-code-start-hook 中标记当前 buffer 不弹窗。
仅当 `claude-group--pending-suppress' 为非 nil 时生效。"
  (when (bound-and-true-p claude-group--pending-suppress)
    (setq-local claude-group--no-display t)))

;; 确保在 auto-open-input 之前运行（prepend 到 hook）
(add-hook 'claude-code-start-hook #'claude-group--mark-no-display -90)

(defvar claude-group--pending-suppress nil
  "临时标志，非 nil 时 start-hook 会在 buffer 上设置 no-display 标记。")

(defun claude-group--start-instance (dir role-name extra-switches &optional suppress-display)
  "在 DIR 下启动名为 ROLE-NAME 的 Claude 实例，传递 EXTRA-SWITCHES。

返回对应 buffer。当 SUPPRESS-DISPLAY 非 nil 时，
让 vterm 正常初始化（需要窗口测量宽度），完成后将窗口切回原 buffer，
并通过 start-hook 在 buffer 上设置标记以抑制 input 弹窗。"
  (let ((claude-group--preset-instance-name role-name)
        (default-directory dir)
        (claude-group--pending-suppress suppress-display)
        ;; suppress 时仍然走正常 display（vterm 需要窗口），事后切回
        (claude-code-display-window-fn
         (if suppress-display #'ignore claude-code-display-window-fn))
)
    ;; DEBUG: 记录调用前状态 + 完整 backtrace
    (let ((frames 0)
          (bt-lines nil))
      (mapbacktrace (lambda (evald func args _flags)
                      (setq frames (1+ frames))
                      (push (format "  #%d %s %s %S"
                                    frames
                                    (if evald ">" " ")
                                    func
                                    (if (> (length (format "%S" args)) 100)
                                        "(args truncated)"
                                      args))
                            bt-lines)))
      (append-to-file
       (format "[%s] PRE claude-code--start: frames=%d suppress=%s dir=%s\nBacktrace:\n%s\n\n"
               role-name frames suppress-display dir
               (mapconcat #'identity (nreverse bt-lines) "\n"))
       nil "/tmp/claude-debug.log"))
    (condition-case err
        (claude-code--start nil extra-switches nil nil)
      (error
       (append-to-file
        (format "[%s] ERROR in claude-code--start: %s\n" role-name (error-message-string err))
        nil "/tmp/claude-debug.log")
       (signal (car err) (cdr err))))
    ;; DEBUG: 记录调用后状态
    (let ((buf (get-buffer (claude-code--buffer-name role-name))))
      (append-to-file
       (format "[%s] POST claude-code--start: buf=%s live=%s process=%s\n"
               role-name buf (and buf (buffer-live-p buf))
               (and buf (get-buffer-process buf) t))
       nil "/tmp/claude-debug.log"))
    ;; suppress 模式下 pop-to-buffer 走原始路径（临时分窗），
    ;; delete-window 正常关掉，不需要手动切回
    (get-buffer (claude-code--buffer-name role-name))))

;;; ============================================================
;;; 主入口：批量创建
;;; ============================================================

(defcustom claude-group-org-file
  "/mnt/lishiyu/quant1/RNN/orgnize.org"
  "默认角色定义 org 文件路径。"
  :type 'file
  :group 'claude-code)

(defcustom claude-group-mcp-config nil
  "全局 MCP 配置文件路径，传递给 --mcp-config。

可以是 JSON 文件路径或 JSON 字符串。
如果 org 文件中某角色的 :PROPERTIES: 指定了 MCP_CONFIG，则覆盖此值。
为 nil 时不传递 --mcp-config（使用 Claude CLI 默认 MCP 配置）。"
  :type '(choice (const :tag "不指定" nil)
                 (string :tag "MCP 配置文件路径或 JSON"))
  :group 'claude-code)

(defcustom claude-group-instance-start-interval 2.5
  "每个实例启动之间的间隔秒数，避免并发冲突。"
  :type 'number
  :group 'claude-code)

;;;###autoload
(defun claude-group-start-from-org (file)
  "从 org FILE 读取角色定义，批量创建 Claude 实例。

org 格式：每个 * 一级标题为角色名，标题下方内容通过
--append-system-prompt 作为系统提示词传给 Claude CLI。

可选 :PROPERTIES: 块支持：
  :MCP_CONFIG:     MCP 配置文件路径
  :MODEL:          模型名称
  :ALLOWED_TOOLS:  工具白名单"
  (interactive
   (list (read-file-name "角色定义文件: " nil nil t)))
  (let* ((org-file (expand-file-name file))
         (dir (file-name-directory org-file))
         (roles (claude-group--parse-org org-file)))
    (if (null roles)
        (message "[claude-group] 未在 %s 中找到任何角色定义" org-file)
      (message "[claude-group] 开始创建 %d 个角色实例：%s"
               (length roles)
               (mapconcat (lambda (r) (plist-get r :name)) roles ", "))
      (let ((i 0))
        (dolist (role roles)
          (let* ((role-name (plist-get role :name))
                 (prompt    (plist-get role :prompt))
                 (props     (plist-get role :props))
                 (switches  (claude-group--build-switches role-name prompt props))
                 (start-at  (* i claude-group-instance-start-interval))
                 (is-first  (= i 0)))
            (run-with-timer
             start-at nil
             (lambda ()
               (claude-group--safe-start-instance
                dir role-name switches is-first))))
          (setq i (1+ i)))))))

;;; ============================================================
;;; 绑定快捷键
;;; ============================================================

(with-eval-after-load 'claude-code
  (define-key claude-code-command-map (kbd "g") #'claude-group-start-from-org))

(provide 'init-claude-group)
;;; init-claude-group.el ends here
