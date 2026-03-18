;;; mm-mcp.el --- Emacs MCP client for MiniMax integration -*- lexical-binding: t; -*-
;;
;; 通过 JSON-RPC over stdio 与 MCP 服务器通信。
;; 供 init-minimax.el 调用，使 MiniMax 后端也能使用 MCP 工具。

(require 'cl-lib)
(require 'json)

;;; ============================================================
;;; 配置
;;; ============================================================

(defgroup mm-mcp nil
  "Emacs MCP client for MiniMax."
  :group 'minimax)

(defcustom mm-mcp-servers
  '(("python-shell" . (:command ("python3" "/mnt/lishiyu/quant1/mcp/python_shell_server.py")))
    ("quant-db"     . (:command ("python3" "/mnt/lishiyu/quant1/mcp/quant_db_server.py")))
    ("s3-io"        . (:command ("python3" "/mnt/lishiyu/quant1/mcp/s3_server.py")))
    ("k8s-runner"   . (:command ("python3" "/mnt/lishiyu/quant1/mcp/k8s_server.py")))
    ("emacs-eval"   . (:command ("python3" "/root/.emacs.d/mcp/emacs-eval-server.py")
                       :env (("EMACS_SOCKET_NAME" . "server")))))
  "MCP 服务器配置列表。
每个元素为 (NAME . (:command (CMD ARGS...) :env ((VAR . VAL) ...)))。"
  :type '(alist :key-type string :value-type plist)
  :group 'mm-mcp)

(defcustom mm-mcp-call-timeout 60
  "MCP 工具调用超时秒数。"
  :type 'integer
  :group 'mm-mcp)

;;; ============================================================
;;; 内部状态
;;; ============================================================

(defvar mm-mcp--servers (make-hash-table :test 'equal)
  "活跃的 MCP 服务器状态表。key=server-name, value=plist。
plist keys: :process :id-counter :pending :tools :ready")

(defvar mm-mcp--tools-cache nil
  "合并后的所有 MCP 工具列表，每个元素为 (:server :name :description :input-schema)。")

;;; ============================================================
;;; Debug 日志（复用 mm--log）
;;; ============================================================

(declare-function mm--log "init-minimax")
(defvar mm-debug)

(defun mm-mcp--log (fmt &rest args)
  "MCP 模块的 debug 日志。"
  (when (bound-and-true-p mm-debug)
    (apply #'mm--log (concat "[MCP] " fmt) args)))

;;; ============================================================
;;; JSON-RPC over stdio
;;; ============================================================

(defun mm-mcp--next-id (server-name)
  "返回下一个请求 ID。"
  (let* ((state (gethash server-name mm-mcp--servers))
         (id (1+ (or (plist-get state :id-counter) 0))))
    (plist-put state :id-counter id)
    id))

(defun mm-mcp--send (server-name method params &optional callback)
  "向 SERVER-NAME 发送 JSON-RPC 请求。CALLBACK 接收 (result error)。"
  (let* ((state (gethash server-name mm-mcp--servers))
         (proc (plist-get state :process)))
    (unless (and proc (process-live-p proc))
      (error "MCP 服务器 %s 未运行" server-name))
    (let* ((id (mm-mcp--next-id server-name))
           (msg `(("jsonrpc" . "2.0")
                  ("id" . ,id)
                  ("method" . ,method)
                  ,@(when params `(("params" . ,params)))))
           (json-str (let ((json-encoding-pretty-print nil))
                       (json-encode msg))))
      (when callback
        (let ((pending (plist-get state :pending)))
          (puthash id callback pending)))
      (mm-mcp--log "SEND [%s] id=%d method=%s" server-name id method)
      (process-send-string proc (concat json-str "\n"))
      id)))

(defun mm-mcp--send-notification (server-name method &optional params)
  "向 SERVER-NAME 发送 JSON-RPC 通知（无 id，不期望响应）。"
  (let* ((state (gethash server-name mm-mcp--servers))
         (proc (plist-get state :process)))
    (unless (and proc (process-live-p proc))
      (error "MCP 服务器 %s 未运行" server-name))
    (let* ((msg `(("jsonrpc" . "2.0")
                  ("method" . ,method)
                  ,@(when params `(("params" . ,params)))))
           (json-str (let ((json-encoding-pretty-print nil))
                       (json-encode msg))))
      (mm-mcp--log "NOTIFY [%s] method=%s" server-name method)
      (process-send-string proc (concat json-str "\n")))))

(defun mm-mcp--process-filter (server-name _proc output)
  "处理 MCP 服务器的 stdout 输出。按 \\n 切分，解析 JSON-RPC 响应。"
  (let* ((state (gethash server-name mm-mcp--servers))
         (partial-key :partial-buf)
         (partial (or (plist-get state partial-key) ""))
         (data (concat partial output))
         (lines (split-string data "\n"))
         (json-object-type 'alist)
         (json-array-type 'vector)
         (json-key-type 'symbol))
    ;; 最后一行可能不完整
    (plist-put state partial-key (car (last lines)))
    (dolist (line (butlast lines))
      (setq line (string-trim line))
      (when (and (not (string-empty-p line))
                 (string-prefix-p "{" line))
        (condition-case err
            (let* ((obj (json-read-from-string line))
                   (id (alist-get 'id obj))
                   (result (alist-get 'result obj))
                   (error-val (alist-get 'error obj)))
              (mm-mcp--log "RECV [%s] id=%s keys=%s"
                           server-name id
                           (mapcar #'car obj))
              (when id
                (let* ((pending (plist-get state :pending))
                       (cb (gethash id pending)))
                  (when cb
                    (remhash id pending)
                    (funcall cb result error-val)))))
          (error
           (mm-mcp--log "PARSE-ERROR [%s]: %s | line=%s"
                        server-name (error-message-string err)
                        (substring line 0 (min 200 (length line))))))))))

;;; ============================================================
;;; 服务器进程管理
;;; ============================================================

(defun mm-mcp--start-server (server-name config callback)
  "启动单个 MCP 服务器。CONFIG 为 plist。
CALLBACK 在 initialize 握手完成后调用，参数为 (server-name success-p)。"
  (when-let* ((old-state (gethash server-name mm-mcp--servers))
              (old-proc (plist-get old-state :process)))
    (when (process-live-p old-proc)
      (mm-mcp--log "STOP [%s] 先停止旧进程" server-name)
      (delete-process old-proc)))
  (let* ((cmd (plist-get config :command))
         (env-pairs (plist-get config :env))
         (proc-env (append
                    (mapcar (lambda (pair)
                              (format "%s=%s" (car pair) (cdr pair)))
                            env-pairs)
                    process-environment))
         (proc-buf (generate-new-buffer (format " *mcp:%s*" server-name)))
         (state (list :process nil
                      :id-counter 0
                      :pending (make-hash-table :test 'eql)
                      :tools nil
                      :ready nil
                      :partial-buf ""))
         (process-environment proc-env)
         (proc (make-process
                :name (format "mcp-%s" server-name)
                :buffer proc-buf
                :command cmd
                :connection-type 'pipe
                :noquery t
                :filter (lambda (proc output)
                          (mm-mcp--process-filter server-name proc output))
                :sentinel (lambda (proc event)
                            (mm-mcp--log "SENTINEL [%s] %s"
                                         server-name (string-trim event))
                            (when (not (process-live-p proc))
                              (let ((st (gethash server-name mm-mcp--servers)))
                                (when st (plist-put st :ready nil))))))))
    (plist-put state :process proc)
    (puthash server-name state mm-mcp--servers)
    (mm-mcp--log "START [%s] pid=%s cmd=%s" server-name (process-id proc) cmd)
    ;; initialize 握手
    (run-with-timer
     0.5 nil
     (lambda ()
       (condition-case err
           (mm-mcp--send
            server-name "initialize"
            `(("protocolVersion" . "2024-11-05")
              ("capabilities" . ,(make-hash-table))
              ("clientInfo" . (("name" . "mm-mcp") ("version" . "1.0"))))
            (lambda (result error-val)
              (if error-val
                  (progn
                    (mm-mcp--log "INIT-FAIL [%s]: %s" server-name error-val)
                    (funcall callback server-name nil))
                (mm-mcp--log "INIT-OK [%s]: %s" server-name
                             (alist-get 'serverInfo result))
                ;; 发送 initialized 通知
                (mm-mcp--send-notification server-name "notifications/initialized")
                (plist-put (gethash server-name mm-mcp--servers) :ready t)
                (funcall callback server-name t))))
         (error
          (mm-mcp--log "INIT-ERROR [%s]: %s" server-name (error-message-string err))
          (funcall callback server-name nil)))))))

(defun mm-mcp--stop-server (server-name)
  "停止单个 MCP 服务器。"
  (when-let* ((state (gethash server-name mm-mcp--servers))
              (proc (plist-get state :process)))
    (when (process-live-p proc)
      (mm-mcp--log "STOP [%s]" server-name)
      (delete-process proc))
    (when-let ((buf (process-buffer proc)))
      (when (buffer-live-p buf) (kill-buffer buf)))
    (remhash server-name mm-mcp--servers)))

;;; ============================================================
;;; 启动/停止所有服务器
;;; ============================================================

(defun mm-mcp-start-all ()
  "启动所有配置的 MCP 服务器，完成后自动获取工具列表。"
  (interactive)
  (setq mm-mcp--tools-cache nil)
  (let ((total (length mm-mcp-servers))
        (done 0)
        (ok 0))
    (if (= total 0)
        (message "[MCP] 没有配置任何服务器")
      (dolist (entry mm-mcp-servers)
        (let ((name (car entry))
              (config (cdr entry)))
          (mm-mcp--start-server
           name config
           (lambda (_srv-name success)
             (when success (setq ok (1+ ok)))
             (setq done (1+ done))
             (mm-mcp--log "PROGRESS: %d/%d done, %d ok" done total ok)
             (when (= done total)
               ;; 所有服务器握手完成，获取工具列表
               (mm-mcp--fetch-all-tools
                (lambda ()
                  (message "[MCP] %d/%d 服务器就绪，共 %d 个工具"
                           ok total (length mm-mcp--tools-cache))))))))))))

(defun mm-mcp-stop-all ()
  "停止所有 MCP 服务器。"
  (interactive)
  (maphash (lambda (name _state)
             (mm-mcp--stop-server name))
           (copy-hash-table mm-mcp--servers))
  (clrhash mm-mcp--servers)
  (setq mm-mcp--tools-cache nil)
  (message "[MCP] 所有服务器已停止"))

;;; ============================================================
;;; 工具操作
;;; ============================================================

(defun mm-mcp--fetch-tools (server-name callback)
  "获取单个服务器的工具列表。CALLBACK 接收 (server-name tools-list)。"
  (let ((state (gethash server-name mm-mcp--servers)))
    (unless (and state (plist-get state :ready))
      (funcall callback server-name nil)
      (cl-return-from mm-mcp--fetch-tools nil))
    (mm-mcp--send
     server-name "tools/list" nil
     (lambda (result error-val)
       (if error-val
           (progn
             (mm-mcp--log "TOOLS-LIST-FAIL [%s]: %s" server-name error-val)
             (funcall callback server-name nil))
         (let* ((tools-vec (alist-get 'tools result))
                (tools (and tools-vec (append tools-vec nil))))  ; vector → list
           (mm-mcp--log "TOOLS-LIST [%s]: %d 个工具" server-name (length tools))
           (plist-put (gethash server-name mm-mcp--servers) :tools tools)
           (funcall callback server-name tools)))))))

(defun mm-mcp--fetch-all-tools (callback)
  "获取所有就绪服务器的工具列表，合并后调用 CALLBACK。"
  (let ((servers nil)
        (total 0)
        (done 0)
        (all-tools nil))
    ;; 收集就绪的服务器
    (maphash (lambda (name state)
               (when (plist-get state :ready)
                 (push name servers)
                 (setq total (1+ total))))
             mm-mcp--servers)
    (if (= total 0)
        (progn
          (setq mm-mcp--tools-cache nil)
          (funcall callback))
      (dolist (srv servers)
        (mm-mcp--fetch-tools
         srv
         (lambda (srv-name tools)
           (when tools
             (dolist (tool tools)
               (push (list :server srv-name
                           :name (alist-get 'name tool)
                           :description (or (alist-get 'description tool) "")
                           :input-schema (alist-get 'inputSchema tool))
                     all-tools)))
           (setq done (1+ done))
           (when (= done total)
             (setq mm-mcp--tools-cache (nreverse all-tools))
             (funcall callback))))))))

(defun mm-mcp-list-tools ()
  "显示所有已缓存的 MCP 工具。"
  (interactive)
  (if (null mm-mcp--tools-cache)
      (message "[MCP] 无工具缓存，请先 mm-mcp-start-all")
    (let ((buf (get-buffer-create "*mm-mcp-tools*")))
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (format "MCP 工具列表（共 %d 个）\n%s\n\n"
                          (length mm-mcp--tools-cache)
                          (make-string 50 ?=)))
          (dolist (tool mm-mcp--tools-cache)
            (insert (format "%-40s [%s]\n  %s\n\n"
                            (format "mcp__%s__%s"
                                    (plist-get tool :server)
                                    (plist-get tool :name))
                            (plist-get tool :server)
                            (plist-get tool :description))))))
      (display-buffer buf))))

;;; ============================================================
;;; 工具调用
;;; ============================================================

(defun mm-mcp-call-tool (server-name tool-name arguments callback)
  "调用 MCP 工具。ARGUMENTS 为 alist。CALLBACK 接收 (result-text error-msg)。"
  (mm-mcp--log "CALL [%s] %s args=%s" server-name tool-name
               (let ((json-encoding-pretty-print nil))
                 (json-encode arguments)))
  (let ((timer (run-with-timer
                mm-mcp-call-timeout nil
                (lambda ()
                  (mm-mcp--log "TIMEOUT [%s] %s" server-name tool-name)
                  (funcall callback nil "工具调用超时")))))
    (mm-mcp--send
     server-name "tools/call"
     `(("name" . ,tool-name)
       ("arguments" . ,(or arguments (make-hash-table))))
     (lambda (result error-val)
       (cancel-timer timer)
       (if error-val
           (funcall callback nil (format "%s" error-val))
         ;; 提取结果文本
         (let* ((content-vec (alist-get 'content result))
                (texts (mapcar
                        (lambda (c)
                          (or (alist-get 'text c) ""))
                        (append content-vec nil)))
                (full-text (mapconcat #'identity texts "\n")))
           (funcall callback full-text nil)))))))

;;; ============================================================
;;; OpenAI function calling 格式转换
;;; ============================================================

(defun mm-mcp-tools-as-openai ()
  "将缓存的 MCP 工具转换为 OpenAI function calling 格式的 vector。
返回 [{\"type\":\"function\",\"function\":{...}} ...]"
  (when mm-mcp--tools-cache
    (vconcat
     (mapcar
      (lambda (tool)
        (let* ((server (plist-get tool :server))
               (name (plist-get tool :name))
               (full-name (format "mcp__%s__%s" server name))
               (desc (plist-get tool :description))
               (schema (plist-get tool :input-schema)))
          `(("type" . "function")
            ("function"
             . (("name" . ,full-name)
                ("description" . ,desc)
                ,@(when schema
                    `(("parameters" . ,schema))))))))
      mm-mcp--tools-cache))))

(defun mm-mcp-resolve-tool (full-name)
  "从 mcp__server__tool 格式解析出 (server-name . tool-name)。"
  (when (string-match "^mcp__\\([^_]+\\(?:-[^_]+\\)*\\)__\\(.+\\)$" full-name)
    (cons (match-string 1 full-name)
          (match-string 2 full-name))))

(provide 'mm-mcp)
;;; mm-mcp.el ends here
