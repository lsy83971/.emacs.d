;;; init-minimax.el --- MiniMax API chat interface for Emacs -*- lexical-binding: t; -*-
;;
;; 纯 Emacs Lisp 实现，不依赖 vterm。
;; 聊天显示用只读 buffer，输入用独立输入框，API 通过 curl 流式调用。
;;
;; 快捷键（C-c m 前缀）：
;;   C-c m c   创建新对话实例
;;   C-c m i   打开/跳转到输入框
;;   C-c m g   从 org 文件批量创建角色实例
;;   C-c m r   重命名当前实例
;;   C-c m k   关闭当前实例
;;
;; 环境变量：MINIMAX_API_KEY

(require 'cl-lib)
(require 'json)
(require 'mm-mcp)
(declare-function claude-group--parse-org "init-claude-group")

;;; ============================================================
;;; Debug 日志
;;; ============================================================

(defvar mm-debug nil
  "非 nil 时启用 debug 日志，输出到 *mm-debug* buffer。")

(defun mm--log (fmt &rest args)
  "当 `mm-debug' 非 nil 时，写一行带时间戳的日志到 *mm-debug* buffer。"
  (when mm-debug
    (let ((buf (get-buffer-create "*mm-debug*"))
          (msg (apply #'format fmt args)))
      (with-current-buffer buf
        (goto-char (point-max))
        (insert (format "[%s] %s\n"
                        (format-time-string "%H:%M:%S.%3N")
                        msg))))))

(defun mm-toggle-debug ()
  "切换 debug 模式。"
  (interactive)
  (setq mm-debug (not mm-debug))
  (message "[MiniMax] debug %s — 日志见 *mm-debug* buffer"
           (if mm-debug "ON" "OFF")))

(defun mm-reset-streaming ()
  "强制重置所有 mm buffer 的 streaming 状态（用于卡死恢复）。"
  (interactive)
  (dolist (buf (mm--find-all-buffers))
    (with-current-buffer buf
      (when mm--streaming
        (setq mm--streaming nil)
        (mm--log "RESET: %s streaming 已强制重置" (buffer-name buf)))))
  (message "[MiniMax] 所有实例的 streaming 状态已重置"))

;;; ============================================================
;;; 配置
;;; ============================================================

(defgroup minimax nil
  "MiniMax API chat interface."
  :group 'tools)

(defcustom mm-api-key ""
  "MiniMax 国际版 API Key，也可通过环境变量 MINIMAX_API_KEY 设置。"
  :type 'string
  :group 'minimax)

(defcustom mm-api-base-url "https://api.minimaxi.chat/v1"
  "MiniMax 国际版 API Base URL。"
  :type 'string
  :group 'minimax)

(defcustom mm-model "MiniMax-Text-01"
  "默认使用的 MiniMax 模型。"
  :type 'string
  :group 'minimax)

(defcustom mm-input-window-height 6
  "输入框窗口高度（行数）。"
  :type 'integer
  :group 'minimax)

;;; ============================================================
;;; Buffer 命名与查找
;;; ============================================================

(defun mm--buffer-name (instance-name)
  (format "*mm:%s*" instance-name))

(defun mm--input-buffer-name (instance-name)
  (format "*input:mm:%s*" instance-name))

(defun mm--buffer-p (&optional buf)
  "判断 BUF 是否为 mm 聊天 buffer。"
  (string-match-p "^\\*mm:" (buffer-name (or buf (current-buffer)))))

(defun mm--input-buffer-p (&optional buf)
  "判断 BUF 是否为 mm 输入 buffer。"
  (string-match-p "^\\*input:mm:" (buffer-name (or buf (current-buffer)))))

(defun mm--extract-name (buf)
  "从 BUF 的 buffer 名提取实例名。支持 chat 和 input buffer。"
  (let ((name (buffer-name buf)))
    (cond
     ((string-match "^\\*mm:\\(.*\\)\\*$" name)
      (match-string 1 name))
     ((string-match "^\\*input:mm:\\(.*\\)\\*$" name)
      (match-string 1 name)))))

(defun mm--find-all-buffers ()
  "返回所有活跃的 mm 聊天 buffer。"
  (cl-remove-if-not
   (lambda (b) (and (buffer-live-p b) (mm--buffer-p b)))
   (buffer-list)))

(defun mm--find-existing (instance-name)
  (get-buffer (mm--buffer-name instance-name)))

(defun mm--get-or-prompt ()
  "返回当前关联的 mm chat buffer，或提示用户选择。
在 chat buffer 中直接返回；在 input buffer 中通过 target 找到 chat buffer。"
  (cond
   ;; 当前是 mm chat buffer
   ((mm--buffer-p) (current-buffer))
   ;; 当前是 mm input buffer → 找到关联的 chat buffer
   ((mm--input-buffer-p)
    (let ((target (and (boundp 'mm-input--target)
                       (buffer-local-value 'mm-input--target (current-buffer)))))
      (or (and target (get-buffer target))
          (user-error "输入框未关联到任何 MiniMax 实例"))))
   ;; 其他情况 → 提示选择
   (t
    (let ((bufs (mm--find-all-buffers)))
      (cond
       ((null bufs)
        (user-error "没有运行中的 MiniMax 实例，请先用 C-c m c 创建"))
       ((= 1 (length bufs)) (car bufs))
       (t (get-buffer
           (completing-read "选择 MiniMax 实例: "
                            (mapcar #'buffer-name bufs) nil t))))))))

;;; ============================================================
;;; Buffer-local 状态（在 chat buffer 中）
;;; ============================================================

(defvar-local mm--history nil
  "对话历史列表，每个元素为 (\"role\" . \"content\")。")
(defvar-local mm--streaming nil
  "是否正在流式接收回复。")

;;; ============================================================
;;; mm-input-mode — 独立输入模式
;;; ============================================================

(defvar-local mm-input--target nil
  "对应的 mm chat buffer 名称（字符串）。")
(defvar-local mm-input--history nil
  "发送历史，最新在前。")
(defvar-local mm-input--history-idx -1
  "历史导航位置，-1 为当前编辑。")
(defvar-local mm-input--saved ""
  "进入历史导航前暂存的当前内容。")

(defun mm-input-commit ()
  "将输入框内容提交到对话框显示（不触发 API 调用）。"
  (interactive)
  (let ((content (string-trim
                  (buffer-substring-no-properties (point-min) (point-max)))))
    (when (string-empty-p content)
      (user-error "输入框为空"))
    ;; 加入发送历史
    (setq mm-input--history
          (cons content (delete content mm-input--history))
          mm-input--history-idx -1
          mm-input--saved "")
    (let ((target (and mm-input--target (get-buffer mm-input--target))))
      (unless (buffer-live-p target)
        (user-error "MiniMax 实例已关闭，请用 C-c m c 重新创建"))
      (erase-buffer)
      ;; 追加到历史并显示，但不调 API
      (with-current-buffer target
        (setq mm--history (append mm--history (list (cons "user" content)))))
      (mm--insert target "\n" nil)
      (mm--insert target "You: " 'bold)
      (mm--insert target (concat content "\n") nil)
      (mm--log "COMMIT: 内容已提交到对话框（未发送），历史 %d 条"
               (length (buffer-local-value 'mm--history target))))))

(defun mm-input-send ()
  "发送对话框中已有的全部历史给 MiniMax API。
如果有未发送的 user 消息（通过 C-RET 提交的），一并发出。"
  (interactive)
  ;; 如果输入框还有未提交的内容，先提交
  (let ((content (string-trim
                  (buffer-substring-no-properties (point-min) (point-max)))))
    (when (not (string-empty-p content))
      (mm-input-commit)))
  (let ((target (and mm-input--target (get-buffer mm-input--target))))
    (unless (buffer-live-p target)
      (user-error "MiniMax 实例已关闭"))
    (when (buffer-local-value 'mm--streaming target)
      (user-error "正在等待回复，请稍候"))
    (let ((history (buffer-local-value 'mm--history target)))
      (unless history
        (user-error "对话框为空，没有内容可发送"))
      ;; 检查最后一条是否为 user 消息
      (unless (string= "user" (car (car (last history))))
        (user-error "没有待发送的用户消息"))
      ;; 触发 API 调用
      (mm--do-api-call target))))

(defun mm-input-history-prev ()
  "调出上一条（更旧的）历史记录。"
  (interactive)
  (unless mm-input--history (user-error "暂无发送记录"))
  (when (= mm-input--history-idx -1)
    (setq mm-input--saved
          (buffer-substring-no-properties (point-min) (point-max))))
  (if (< (1+ mm-input--history-idx) (length mm-input--history))
      (progn
        (setq mm-input--history-idx (1+ mm-input--history-idx))
        (erase-buffer)
        (insert (nth mm-input--history-idx mm-input--history))
        (goto-char (point-max)))
    (message "已是最旧记录")))

(defun mm-input-history-next ()
  "调出下一条（更新的）历史记录；回到底端时还原编辑内容。"
  (interactive)
  (cond
   ((> mm-input--history-idx 0)
    (setq mm-input--history-idx (1- mm-input--history-idx))
    (erase-buffer)
    (insert (nth mm-input--history-idx mm-input--history))
    (goto-char (point-max)))
   ((= mm-input--history-idx 0)
    (setq mm-input--history-idx -1)
    (erase-buffer)
    (insert mm-input--saved)
    (goto-char (point-max)))
   (t (message "已是最新"))))

(defvar mm-input-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "C-<return>") #'mm-input-commit)
    (define-key m (kbd "C-r")        #'mm-input-send)
    (define-key m (kbd "C-<up>")     #'mm-input-history-prev)
    (define-key m (kbd "C-<down>")   #'mm-input-history-next)
    m)
  "mm-input-mode 按键表。")

(define-minor-mode mm-input-mode
  "MiniMax 独立输入模式。C-RET 发送，C-↑/↓ 浏览历史，RET 换行。"
  :lighter " MM-In"
  :keymap mm-input-mode-map
  (setq-local header-line-format
              (when mm-input-mode
                (list " MiniMax 输入 → "
                      '(:eval (or mm-input--target "?"))
                      "    C-RET 提交  C-r 发送  C-↑/↓ 历史"))))

;;; ============================================================
;;; mm-chat-mode — 对话显示模式
;;; ============================================================

(defvar mm-chat-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "q") #'quit-window)
    (define-key m (kbd "i") #'mm-open-input)
    m))

(define-derived-mode mm-chat-mode fundamental-mode "MiniMax"
  "MiniMax 对话显示模式。i 打开输入框，q 关闭窗口。"
  (setq buffer-read-only t
        truncate-lines nil
        word-wrap t))

;;; ============================================================
;;; 显示函数
;;; ============================================================

(defun mm--insert (buf text &optional face)
  "向 BUF 末尾插入 TEXT，可选 FACE。保证 buf 可见时滚动到底部。"
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (goto-char (point-max))
        (insert (if face (propertize text 'face face) text))))
    (mm--scroll-to-bottom buf)))

(defun mm--scroll-to-bottom (buf)
  "将 BUF 的所有可见窗口滚动到底部。"
  (dolist (win (get-buffer-window-list buf nil t))
    (with-selected-window win
      (goto-char (point-max)))))

;;; ============================================================
;;; API 调用（curl SSE 流式）
;;; ============================================================

(defvar mm--api-key-cache nil
  "会话内缓存的 API Key，避免重复输入。Emacs 退出即消失。")

(defun mm--get-api-key ()
  "获取 API Key。优先级：环境变量 > defcustom > 会话缓存 > 交互式输入。"
  (or (getenv "MINIMAX_API_KEY")
      (and (stringp mm-api-key) (not (string-empty-p mm-api-key)) mm-api-key)
      mm--api-key-cache
      (let ((key (read-string "MiniMax API Key: ")))
        (if (string-empty-p key)
            (user-error "API Key 不能为空")
          (setq mm--api-key-cache key)
          (message "[MiniMax] API Key 已缓存（本次会话有效）")
          key))))

(defun mm--build-payload (messages &optional tools)
  "将 MESSAGES 列表编码为 JSON payload 字符串。
MESSAGES 元素为 (role . content) 或扩展格式（tool_calls / tool 消息）。
TOOLS 为 OpenAI function calling 格式的 vector，非空时启用工具调用。"
  (let ((json-encoding-pretty-print nil))
    (json-encode
     `(("model"    . ,mm-model)
       ("stream"   . t)
       ("messages" . ,(vconcat
                       (mapcar #'mm--encode-message messages)))
       ,@(when tools
           `(("tools" . ,tools)
             ("tool_choice" . "auto")))))))

(defun mm--encode-message (m)
  "将单个消息 M 编码为 API 可用的 alist。
支持三种格式：
  (\"role\" . \"text\")                     → 普通消息
  (\"assistant\" . (:tool_calls [...]))     → assistant 带 tool_calls
  (\"tool\" . (:tool_call_id ID :content TEXT)) → 工具结果"
  (let ((role (car m))
        (body (cdr m)))
    (cond
     ;; tool 结果消息
     ((string= role "tool")
      `(("role" . "tool")
        ("tool_call_id" . ,(plist-get body :tool_call_id))
        ("content" . ,(plist-get body :content))))
     ;; assistant 带 tool_calls（内部符号 key → API 字符串 key）
     ((and (string= role "assistant")
           (plistp body)
           (plist-get body :tool_calls))
      (let ((tcs (plist-get body :tool_calls)))
        `(("role" . "assistant")
          ("content" . :json-null)
          ("tool_calls" . ,(vconcat
                            (mapcar
                             (lambda (tc)
                               `(("id" . ,(alist-get 'id tc))
                                 ("type" . ,(or (alist-get 'type tc) "function"))
                                 ("function"
                                  . (("name" . ,(alist-get 'name (alist-get 'function tc)))
                                     ("arguments" . ,(alist-get 'arguments (alist-get 'function tc)))))))
                             (append tcs nil)))))))
     ;; 普通文本消息
     (t
      `(("role" . ,role)
        ("content" . ,body))))))

(defun mm--finalize-tool-calls-acc (acc)
  "将 tool_calls 累积器（hash-table）转换为最终的 vector，使用符号 key。"
  (let ((indices (sort (hash-table-keys acc) #'<)))
    (vconcat
     (mapcar
      (lambda (idx)
        (let ((tc (gethash idx acc)))
          `((id . ,(plist-get tc :id))
            (type . "function")
            (function
             . ((name . ,(plist-get tc :name))
                (arguments . ,(apply #'concat
                                     (plist-get tc :arguments-parts))))))))
      indices))))

(defun mm--parse-sse-lines (raw-output partial-ref on-chunk &optional on-tool-call)
  "解析 SSE 流式输出。
RAW-OUTPUT 为新收到的字节串。
PARTIAL-REF 是 (残余字符串 . tool-calls-accumulator)。
ON-CHUNK 回调接收每个文本片段。
ON-TOOL-CALL 回调在流结束时接收完整的 tool_calls vector（如有）。
  tool-calls-accumulator 格式：hash-table index → (:id :name :arguments-parts)"
  (let* ((data (concat (car partial-ref) raw-output))
         (lines (split-string data "\n"))
         (json-object-type 'alist)
         (json-array-type  'vector)
         (json-key-type    'symbol))
    ;; 最后一行可能不完整，留到下次
    (setcar partial-ref (car (last lines)))
    (dolist (line (butlast lines))
      (setq line (string-trim-right line "\r"))
      (when (string-prefix-p "data: " line)
        (let ((payload (substring line 6)))
          (cond
           ((string= payload "[DONE]")
            ;; 流结束，检查是否有累积的 tool_calls
            (when (and on-tool-call (cdr partial-ref))
              (let ((calls (mm--finalize-tool-calls-acc (cdr partial-ref))))
                (when (> (length calls) 0)
                  (funcall on-tool-call calls)))))
           (t
            (condition-case nil
                (let* ((obj (json-read-from-string payload))
                       (choices (alist-get 'choices obj))
                       (choice (and (> (length choices) 0) (aref choices 0)))
                       (delta (alist-get 'delta choice))
                       (_finish (alist-get 'finish_reason choice))
                       (text (alist-get 'content delta))
                       (tool-calls (alist-get 'tool_calls delta)))
                  ;; 处理文本内容
                  (when (and text (stringp text) (not (string-empty-p text)))
                    (funcall on-chunk text))
                  ;; 处理 tool_calls 增量
                  (when (and tool-calls on-tool-call)
                    (unless (cdr partial-ref)
                      (setcdr partial-ref (make-hash-table :test 'eql)))
                    (let ((acc (cdr partial-ref)))
                      (dotimes (i (length tool-calls))
                        (let* ((tc (aref tool-calls i))
                               (idx (or (alist-get 'index tc) i))
                               (tc-id (alist-get 'id tc))
                               (func (alist-get 'function tc))
                               (tc-name (and func (alist-get 'name func)))
                               (tc-args (and func (alist-get 'arguments func)))
                               (existing (gethash idx acc)))
                          (unless existing
                            (setq existing (list :id nil :name nil :arguments-parts nil))
                            (puthash idx existing acc))
                          (when tc-id
                            (plist-put existing :id tc-id))
                          (when tc-name
                            (plist-put existing :name tc-name))
                          (when (and tc-args (stringp tc-args))
                            (plist-put existing :arguments-parts
                                       (append (plist-get existing :arguments-parts)
                                               (list tc-args)))))))))
              (error nil)))))))))

(defun mm--stream-request (chat-buf messages on-chunk on-done on-error
                                    &optional tools on-tool-calls)
  "向 MiniMax API 发送 MESSAGES，通过回调处理流式结果。
ON-CHUNK(text) — 每收到一段文本。
ON-DONE() — 流式完成（无 tool_calls 时）。
ON-ERROR(msg) — 出错。
TOOLS — OpenAI function calling 格式的工具数组（可选）。
ON-TOOL-CALLS(calls-vector) — 收到 tool_calls 时回调（可选）。"
  (mm--log "STREAM-REQ: 开始，model=%s, messages=%d条, tools=%d个, buf=%s"
           mm-model (length messages)
           (if tools (length tools) 0)
           (buffer-name chat-buf))
  (if (not (executable-find "curl"))
      (progn
        (mm--log "STREAM-REQ: curl 未找到")
        (funcall on-error "curl 未安装，请先安装 curl"))
  (let* ((api-key  (mm--get-api-key))
         (payload  (mm--build-payload messages tools))
         (proc-buf (generate-new-buffer " *mm-curl*"))
         (partial  (cons "" nil))
         (tool-calls-received nil)
         (url      (concat mm-api-base-url "/chat/completions")))
    (mm--log "STREAM-REQ: url=%s, payload长度=%d" url (length payload))
    (mm--log "STREAM-REQ: payload=%s"
             (if (> (length payload) 500)
                 (concat (substring payload 0 500) "...")
               payload))
    (condition-case err
        (let ((proc
               (make-process
                :name       "mm-api-stream"
                :buffer     proc-buf
                :command    (list "curl" "--silent" "--no-buffer"
                                 "--max-time" "120"
                                 "--request" "POST" url
                                 "--header" (format "Authorization: Bearer %s" api-key)
                                 "--header" "Content-Type: application/json"
                                 "--data-raw" payload)
                :connection-type 'pipe
                :filter
                (lambda (_proc output)
                  (mm--log "FILTER: 收到 %d 字节" (length output))
                  (mm--log "FILTER: 内容前200字=%s"
                           (substring output 0 (min 200 (length output))))
                  (when (buffer-live-p chat-buf)
                    (mm--parse-sse-lines
                     output partial on-chunk
                     (when on-tool-calls
                       (lambda (calls)
                         (setq tool-calls-received calls))))))
                :sentinel
                (lambda (proc event)
                  (let ((exit-status (process-exit-status proc))
                        (event-clean (string-trim event)))
                    (mm--log "SENTINEL: event=%s, exit=%d" event-clean exit-status)
                    ;; 处理 partial buffer 中可能残留的数据（如 data: [DONE] 无尾部换行）
                    (when (and (buffer-live-p chat-buf)
                               (car partial)
                               (not (string-empty-p (car partial))))
                      (mm--log "SENTINEL: flush partial=%s" (car partial))
                      (mm--parse-sse-lines
                       (concat (car partial) "\n") (cons "" (cdr partial))
                       on-chunk
                       (when on-tool-calls
                         (lambda (calls)
                           (setq tool-calls-received calls))))
                      (setcar partial ""))
                    ;; 如果 filter 中已累积 tool_calls 但 [DONE] 未触发回调，在此兜底
                    (when (and (not tool-calls-received)
                               on-tool-calls
                               (cdr partial))
                      (let ((calls (mm--finalize-tool-calls-acc (cdr partial))))
                        (when (> (length calls) 0)
                          (mm--log "SENTINEL: 兜底构建 tool_calls，%d 个"
                                   (length calls))
                          (setq tool-calls-received calls))))
                    (when (buffer-live-p proc-buf)
                      (mm--log "SENTINEL: 清理 proc-buf")
                      (kill-buffer proc-buf))
                    (if (not (buffer-live-p chat-buf))
                        (mm--log "SENTINEL: chat-buf 已死，跳过回调")
                      (if (and (string-match-p "finished" event-clean)
                               (= exit-status 0))
                          (progn
                            (mm--log "SENTINEL: 成功完成")
                            (if tool-calls-received
                                (progn
                                  (mm--log "SENTINEL: 有 tool_calls，%d 个"
                                           (length tool-calls-received))
                                  (funcall on-tool-calls tool-calls-received))
                              (funcall on-done)))
                        (let ((err-msg (if (= exit-status 0)
                                           event-clean
                                         (format "curl 退出码 %d: %s"
                                                 exit-status event-clean))))
                          (mm--log "SENTINEL: 失败，调用 on-error: %s" err-msg)
                          (funcall on-error err-msg)))))))))
          (mm--log "STREAM-REQ: curl 进程已启动, pid=%s"
                   (process-id proc)))
      (error
       (mm--log "STREAM-REQ: make-process 异常: %s" (error-message-string err))
       (when (buffer-live-p proc-buf) (kill-buffer proc-buf))
       (funcall on-error (error-message-string err)))))))

;;; ============================================================
;;; 核心流程：提交（显示）与 发送（API 调用）分离
;;; ============================================================

(defun mm--commit-to-chat (buf content)
  "将 CONTENT 作为 user 消息追加到 BUF 的历史并显示（不触发 API）。"
  (with-current-buffer buf
    (setq mm--history (append mm--history (list (cons "user" content)))))
  (mm--insert buf "\n" nil)
  (mm--insert buf "You: " 'bold)
  (mm--insert buf (concat content "\n") nil)
  (mm--log "COMMIT: 已提交到对话框，历史 %d 条"
           (length (buffer-local-value 'mm--history buf))))

(defcustom mm-mcp-enabled t
  "非 nil 时在 API 调用中启用 MCP 工具。"
  :type 'boolean
  :group 'minimax)

(defcustom mm-mcp-max-rounds 20
  "工具调用最大轮数，防止无限循环。"
  :type 'integer
  :group 'minimax)

(defvar mm-mcp--auto-started nil
  "非 nil 表示 MCP 服务器已经自动启动过（避免重复启动）。")

(defun mm--ensure-mcp-and-call (buf)
  "确保 MCP 就绪后再发起 API 调用。首次使用时自动启动 MCP 服务器。"
  (cond
   ;; MCP 未启用 → 直接调用
   ((not mm-mcp-enabled)
    (mm--do-api-call-round buf 0))
   ;; 已有工具缓存 → 直接调用
   (mm-mcp--tools-cache
    (mm--do-api-call-round buf 0))
   ;; 尚未启动 → 启动后回调
   ((not mm-mcp--auto-started)
    (setq mm-mcp--auto-started t)
    (mm--log "AUTO-MCP: 自动启动 MCP 服务器，API 调用将在就绪后发出")
    (mm--insert buf "[正在启动 MCP 工具服务器...]\n" '(:foreground "yellow"))
    (let ((total (length mm-mcp-servers))
          (done 0)
          (ok 0))
      (dolist (entry mm-mcp-servers)
        (let ((name (car entry))
              (config (cdr entry)))
          (mm-mcp--start-server
           name config
           (lambda (_srv-name success)
             (when success (setq ok (1+ ok)))
             (setq done (1+ done))
             (when (= done total)
               (mm-mcp--fetch-all-tools
                (lambda ()
                  (mm--log "AUTO-MCP: %d/%d 就绪，%d 工具，发起 API 调用"
                           ok total (length mm-mcp--tools-cache))
                  (mm--insert buf (format "[MCP 就绪: %d 个工具]\n"
                                          (length mm-mcp--tools-cache))
                              '(:foreground "green"))
                  (mm--do-api-call-round buf 0))))))))))
   ;; 已启动但缓存还没回来（不应该发生，兜底）
   (t
    (mm--do-api-call-round buf 0))))

(defun mm--do-api-call (buf)
  "将 BUF 当前的全部历史发送给 MiniMax API，流式接收回复。
支持 MCP 工具调用循环：tool_calls → 执行 → 追加结果 → 再次调用 API。"
  (mm--log "API-CALL: buf=%s, streaming=%s, 历史 %d 条"
           (buffer-name buf)
           (buffer-local-value 'mm--streaming buf)
           (length (buffer-local-value 'mm--history buf)))
  (when (buffer-local-value 'mm--streaming buf)
    (user-error "正在等待回复，请稍候"))
  (with-current-buffer buf
    (setq mm--streaming t))
  (mm--ensure-mcp-and-call buf))

(defun mm--do-api-call-round (buf round)
  "执行第 ROUND 轮 API 调用。"
  (when (>= round mm-mcp-max-rounds)
    (mm--insert buf "\n[工具调用轮数已达上限]\n" '(:foreground "orange"))
    (with-current-buffer buf (setq mm--streaming nil))
    (cl-return-from mm--do-api-call-round nil))
  (let ((tools (and mm-mcp-enabled (mm-mcp-tools-as-openai))))
    (mm--insert buf (if (= round 0) "\nMiniMax: " "")
                '(:inherit bold :foreground "cyan"))
    (let ((full-response ""))
      (mm--stream-request
       buf
       (buffer-local-value 'mm--history buf)
       ;; on-chunk
       (lambda (chunk)
         (mm--log "CHUNK[r%d]: %d 字符" round (length chunk))
         (setq full-response (concat full-response chunk))
         (mm--insert buf chunk nil))
       ;; on-done（无 tool_calls，正常完成）
       (lambda ()
         (mm--log "DONE[r%d]: 回复完成，共 %d 字符" round (length full-response))
         (when (buffer-live-p buf)
           (with-current-buffer buf
             (setq mm--history (append mm--history
                                       (list (cons "assistant" full-response)))
                   mm--streaming nil))
           (mm--insert buf "\n" nil)))
       ;; on-error
       (lambda (err)
         (mm--log "ERROR[r%d]: %s" round err)
         (when (buffer-live-p buf)
           (with-current-buffer buf
             (setq mm--streaming nil)
             (when (= round 0)
               (setq mm--history (butlast mm--history))))
           (mm--insert buf (format "\n[错误] %s\n" err)
                       '(:foreground "red"))))
       ;; tools
       tools
       ;; on-tool-calls
       (when tools
         (lambda (tool-calls)
           (mm--log "TOOL-CALLS[r%d]: %d 个调用" round (length tool-calls))
           (mm--handle-tool-calls buf tool-calls full-response round)))))))

(defun mm--handle-tool-calls (buf tool-calls _assistant-text round)
  "处理 API 返回的 tool_calls，执行工具后继续下一轮调用。"
  (when (buffer-live-p buf)
    ;; 将 assistant 消息（含 tool_calls）追加到历史
    (with-current-buffer buf
      (setq mm--history
            (append mm--history
                    (list (cons "assistant"
                                (list :tool_calls tool-calls))))))
    ;; 串行执行每个 tool call
    (mm--execute-tool-calls-seq buf tool-calls 0 round)))

(defun mm--execute-tool-calls-seq (buf tool-calls idx round)
  "串行执行 TOOL-CALLS 中第 IDX 个工具，完成后继续下一个。"
  (if (>= idx (length tool-calls))
      ;; 所有工具执行完毕，发起下一轮 API 调用
      (progn
        (mm--log "TOOLS-DONE[r%d]: 所有工具已执行" round)
        (mm--do-api-call-round buf (1+ round)))
    ;; 执行当前工具
    (let* ((tc (aref tool-calls idx))
           (tc-id (alist-get 'id tc))
           (func (alist-get 'function tc))
           (full-name (alist-get 'name func))
           (args-str (alist-get 'arguments func))
           (resolved (mm-mcp-resolve-tool full-name)))
      (mm--log "TOOL-EXEC[r%d.%d]: %s args=%s"
               round idx full-name (substring args-str 0 (min 200 (length args-str))))
      ;; 在 chat buffer 显示调用信息
      (mm--insert buf (format "\n[调用工具: %s]\n" full-name)
                  '(:foreground "yellow"))
      (if (not resolved)
          (progn
            ;; 无法解析工具名
            (mm--log "TOOL-RESOLVE-FAIL: %s" full-name)
            (let ((err-msg (format "未知工具: %s" full-name)))
              (with-current-buffer buf
                (setq mm--history
                      (append mm--history
                              (list (cons "tool"
                                          (list :tool_call_id tc-id
                                                :content err-msg))))))
              (mm--insert buf (format "[工具错误: %s]\n" err-msg)
                          '(:foreground "red"))
              (mm--execute-tool-calls-seq buf tool-calls (1+ idx) round)))
        ;; 解析参数并调用
        (let* ((server-name (car resolved))
               (tool-name (cdr resolved))
               (arguments (condition-case nil
                              (let ((json-object-type 'alist)
                                    (json-array-type 'vector)
                                    (json-key-type 'symbol))
                                (json-read-from-string args-str))
                            (error nil))))
          (mm-mcp-call-tool
           server-name tool-name arguments
           (lambda (result-text error-msg)
             (let ((content (or error-msg result-text "")))
               ;; 截断过长结果
               (let ((display-text (if (> (length content) 500)
                                       (concat (substring content 0 500) "...")
                                     content)))
                 (mm--insert buf (format "[结果: %s]\n" display-text)
                             '(:foreground "green")))
               ;; 追加到历史
               (with-current-buffer buf
                 (setq mm--history
                       (append mm--history
                               (list (cons "tool"
                                           (list :tool_call_id tc-id
                                                 :content content))))))
               ;; 继续下一个工具
               (mm--execute-tool-calls-seq buf tool-calls (1+ idx) round)))))))))


(defun mm-send-message (content &optional chat-buf)
  "将 CONTENT 提交到 CHAT-BUF 并立即发送给 API（提交+发送一步完成）。
供 IPC 等外部调用使用。"
  (interactive "s消息: ")
  (let ((buf (or chat-buf (mm--get-or-prompt))))
    (unless (buffer-live-p buf) (user-error "mm buffer 不存在"))
    (mm--commit-to-chat buf content)
    (mm--do-api-call buf)))

;;; ============================================================
;;; 输入框管理
;;; ============================================================

(defun mm--auto-kill-input ()
  "mm chat buffer 关闭时自动关闭对应的输入框。"
  (let* ((name   (mm--extract-name (current-buffer)))
         (in-buf (and name (get-buffer (mm--input-buffer-name name)))))
    (when (buffer-live-p in-buf)
      (when-let ((win (get-buffer-window in-buf t)))
        (ignore-errors (delete-window win)))
      (kill-buffer in-buf))))

(defun mm-open-input (&optional chat-buf)
  "打开当前 mm 实例的输入框，若已打开则直接跳转。
同时保证 chat buffer 可见。"
  (interactive)
  (let* ((buf     (or chat-buf (mm--get-or-prompt)))
         (name    (mm--extract-name buf))
         (in-name (mm--input-buffer-name name))
         (in-buf  (get-buffer-create in-name)))
    ;; 保证 chat buffer 有窗口
    (unless (get-buffer-window buf t)
      (display-buffer buf '(display-buffer-same-window)))
    ;; 初始化输入框
    (with-current-buffer in-buf
      (unless (bound-and-true-p mm-input-mode)
        (mm-input-mode 1))
      (setq-local mm-input--target (buffer-name buf)))
    ;; chat buffer 注册清理 hook（幂等）
    (with-current-buffer buf
      (add-hook 'kill-buffer-hook #'mm--auto-kill-input nil t))
    ;; 显示输入框窗口
    (let ((in-win (get-buffer-window in-buf t)))
      (if in-win
          (select-window in-win)
        (let* ((chat-win (get-buffer-window buf t))
               (new-win (when chat-win
                          (with-selected-window chat-win
                            (split-window-below
                             (- (window-height)
                                mm-input-window-height))))))
          (if new-win
              (progn
                (set-window-buffer new-win in-buf)
                (select-window new-win))
            ;; fallback：弹出新窗口
            (pop-to-buffer in-buf
                           `((display-buffer-pop-up-window)
                             (window-height . ,mm-input-window-height)))))))))

;;; ============================================================
;;; 创建 / 关闭 / 重命名实例
;;; ============================================================

(defun mm--init-buffer (instance-name &optional system-prompt)
  "创建并初始化 mm chat buffer，返回 buffer。"
  (let ((buf (get-buffer-create (mm--buffer-name instance-name))))
    (with-current-buffer buf
      (unless (derived-mode-p 'mm-chat-mode)
        (mm-chat-mode))
      (setq mm--history   nil
            mm--streaming nil)
      (when (and system-prompt (not (string-empty-p system-prompt)))
        (setq mm--history (list (cons "system" system-prompt)))
        (let ((inhibit-read-only t))
          (goto-char (point-max))
          (insert (propertize
                   (format "[系统提示已加载：%d 字符]\n" (length system-prompt))
                   'face '(:foreground "green")))))
      (setq header-line-format
            (list (propertize
                   (format " MiniMax | %s | %s " instance-name mm-model)
                   'face 'bold)))
      ;; 注册清理 hook
      (add-hook 'kill-buffer-hook #'mm--auto-kill-input nil t))
    buf))

(defun mm-start (instance-name)
  "创建一个新的 MiniMax 对话实例。"
  (interactive (list (read-string "实例名: " nil nil "chat")))
  (when (mm--find-existing instance-name)
    (user-error "实例 %s 已存在" instance-name))
  (let ((buf (mm--init-buffer instance-name nil)))
    (switch-to-buffer buf)
    (mm-open-input buf)))

(defun mm-kill ()
  "关闭当前 mm 实例及其输入框。"
  (interactive)
  (let* ((buf  (mm--get-or-prompt))
         (name (mm--extract-name buf))
         (in-buf (get-buffer (mm--input-buffer-name name))))
    (when (buffer-live-p in-buf)
      (when-let ((w (get-buffer-window in-buf t)))
        (ignore-errors (delete-window w)))
      (kill-buffer in-buf))
    (kill-buffer buf)))

(defun mm-rename ()
  "重命名当前 mm 实例。"
  (interactive)
  (let* ((buf      (mm--get-or-prompt))
         (old-name (mm--extract-name buf))
         (new-name (read-string "新实例名: " old-name))
         (in-buf   (get-buffer (mm--input-buffer-name old-name))))
    (unless (string= old-name new-name)
      (with-current-buffer buf
        (rename-buffer (mm--buffer-name new-name) t)
        (setq header-line-format
              (list (propertize
                     (format " MiniMax | %s | %s " new-name mm-model)
                     'face 'bold))))
      (when (buffer-live-p in-buf)
        (with-current-buffer in-buf
          (rename-buffer (mm--input-buffer-name new-name) t)
          (setq-local mm-input--target (mm--buffer-name new-name)))))))

;;; ============================================================
;;; 从 org 文件批量创建角色实例
;;; ============================================================

(defcustom mm-group-instance-interval 0.2
  "批量创建时每个实例之间的间隔秒数。"
  :type 'number
  :group 'minimax)

(defcustom mm-group-auto-activate t
  "非 nil 时，批量创建后自动发送激活消息触发角色响应（与 Claude 行为一致）。"
  :type 'boolean
  :group 'minimax)

(defcustom mm-group-activate-message "请确认你已了解角色设定，简要介绍你的职责和能力。"
  "批量创建后自动发送的激活消息。"
  :type 'string
  :group 'minimax)

(defcustom mm-group-activate-delay 1.0
  "创建实例后延迟多少秒发送激活消息（等 MCP 就绪）。"
  :type 'number
  :group 'minimax)

;;;###autoload
(defun mm-group-start-from-org (file)
  "从 org FILE 读取角色定义，批量创建 MiniMax 实例。
org 格式：每个 * 一级标题为角色名，标题下方内容为系统提示词。
当 `mm-group-auto-activate' 非 nil 时，创建后自动发送激活消息。"
  (interactive (list (read-file-name "角色定义文件: " nil nil t)))
  (unless (fboundp 'claude-group--parse-org)
    (user-error "请先加载 init-claude-group"))
  (let ((roles (claude-group--parse-org (expand-file-name file))))
    (if (null roles)
        (message "[mm-group] 未找到任何角色定义")
      (message "[mm-group] 创建 %d 个 MiniMax 实例：%s"
               (length roles)
               (mapconcat #'car roles ", "))
      ;; 如果需要激活且 MCP 未启动，先启动 MCP（只启动一次，所有实例共享）
      (when (and mm-group-auto-activate
                 mm-mcp-enabled
                 (not mm-mcp--auto-started)
                 (null mm-mcp--tools-cache))
        (setq mm-mcp--auto-started t)
        (mm-mcp-start-all))
      (let ((i 0))
        (dolist (role roles)
          (let* ((role-name (car role))
                 (prompt    (cdr role))
                 (delay     (* i mm-group-instance-interval)))
            (run-with-timer
             delay nil
             (lambda ()
               (if (mm--find-existing role-name)
                   (message "[mm-group] ⚠ %s 已存在，跳过" role-name)
                 (condition-case err
                     (let ((buf (mm--init-buffer role-name prompt)))
                       (message "[mm-group] ✓ 已创建：%s" role-name)
                       ;; 自动激活：发送消息触发角色响应
                       (when mm-group-auto-activate
                         (run-with-timer
                          mm-group-activate-delay nil
                          (lambda ()
                            (when (buffer-live-p buf)
                              (mm-send-message
                               mm-group-activate-message buf))))))
                   (error
                    (message "[mm-group] ✗ %s 创建失败：%s"
                             role-name (error-message-string err))))))))
          (setq i (1+ i)))))))

;;; ============================================================
;;; IPC 兼容：与 claude-code IPC 系统互通
;;; ============================================================

(defun mm-ipc-list ()
  "返回所有 MiniMax 实例的 ((buffer-name . instance-name) ...) alist。"
  (mapcar (lambda (b) (cons (buffer-name b) (mm--extract-name b)))
          (mm--find-all-buffers)))

(defun mm-ipc-send (target message)
  "向 TARGET 指定的 mm 实例发送 MESSAGE。
TARGET 可以是实例名或 buffer 名。返回结果字符串。"
  (let ((buf (or (get-buffer (mm--buffer-name target))
                 (cl-find-if (lambda (b) (string= (mm--extract-name b) target))
                             (mm--find-all-buffers))
                 (get-buffer target))))
    (if (and buf (buffer-live-p buf) (mm--buffer-p buf))
        (progn
          (mm-send-message message buf)
          (format "OK: 已发送至 %s" (buffer-name buf)))
      (format "ERROR: 找不到 mm 实例 \"%s\"" target))))

(with-eval-after-load 'init-claude
  ;; 扩展 ipc-list 返回值，加入 mm 实例
  (when (fboundp 'claude-code-ipc-list)
    (advice-add 'claude-code-ipc-list :filter-return
                (lambda (result) (append result (mm-ipc-list)))
                '((name . mm-ipc-append))))

  ;; 拦截 ipc-send：如果 target 是 mm buffer，走 mm 通道而非 vterm
  (when (fboundp 'claude-code-ipc-send)
    (advice-add 'claude-code-ipc-send :around
                (lambda (orig-fn target message)
                  (let ((mm-buf
                         (or (get-buffer (mm--buffer-name target))
                             (cl-find-if
                              (lambda (b) (string= (mm--extract-name b) target))
                              (mm--find-all-buffers)))))
                    (if (and mm-buf (buffer-live-p mm-buf))
                        (mm-ipc-send target message)
                      (funcall orig-fn target message))))
                '((name . mm-ipc-intercept)))))

;;; ============================================================
;;; 命令映射
;;; ============================================================

(defun mm-toggle-mcp ()
  "切换 MCP 工具支持。"
  (interactive)
  (setq mm-mcp-enabled (not mm-mcp-enabled))
  (message "[MiniMax] MCP 工具 %s（缓存 %d 个工具）"
           (if mm-mcp-enabled "ON" "OFF")
           (length mm-mcp--tools-cache)))

(defvar mm-command-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "c") #'mm-start)
    (define-key m (kbd "i") #'mm-open-input)
    (define-key m (kbd "g") #'mm-group-start-from-org)
    (define-key m (kbd "r") #'mm-rename)
    (define-key m (kbd "k") #'mm-kill)
    (define-key m (kbd "d") #'mm-toggle-debug)
    (define-key m (kbd "R") #'mm-reset-streaming)
    (define-key m (kbd "t") #'mm-toggle-mcp)
    (define-key m (kbd "M") #'mm-mcp-start-all)
    (define-key m (kbd "T") #'mm-mcp-list-tools)
    m)
  "MiniMax 命令前缀映射，绑定到 C-c m。")

(global-set-key (kbd "C-c m") mm-command-map)

(provide 'init-minimax)
;;; init-minimax.el ends here
