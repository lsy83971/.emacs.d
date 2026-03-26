;;; claude-code-logger.el --- Claude 多实例主题（上下文保存/恢复）  -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 通过复用 Claude Code 的 --session-id / --resume 机制，
;; 实现多角色对话的「主题」保存与恢复。
;;
;; 存储结构：
;;   ~/.claude/topics/{project-slug}/topic_name.json
;;
;; 每个主题文件记录 {角色名: session-id} 的映射关系。

;;; Code:

(require 'json)

;;; ============================================================
;;; 配置
;;; ============================================================

(defvar claude-code-logger-topic-dir "~/.claude/topics/"
  "主题文件的根目录。")

(defvar claude-code-logger--current-topic nil
  "当前活跃主题名。")

(defvar claude-code-logger--ipc-log '()
  "IPC 通信记录（内存缓存）。")

;;; ============================================================
;;; 工具函数
;;; ============================================================

(defun claude-code-logger--project-slug (dir)
  "将目录路径 DIR 转为 Claude Code 的 slug 格式。
如 /root/.emacs.d → -root--emacs-d"
  (replace-regexp-in-string
   "/" "-"
   (directory-file-name (expand-file-name dir))))

(defun claude-code-logger--uuid ()
  "生成 v4 UUID（纯 Elisp 实现）。"
  (let ((hex "0123456789abcdef"))
    (format "%c%c%c%c%c%c%c%c-%c%c%c%c-4%c%c%c-%c%c%c%c-%c%c%c%c%c%c%c%c%c%c%c%c"
            (aref hex (random 16)) (aref hex (random 16))
            (aref hex (random 16)) (aref hex (random 16))
            (aref hex (random 16)) (aref hex (random 16))
            (aref hex (random 16)) (aref hex (random 16))
            (aref hex (random 16)) (aref hex (random 16))
            (aref hex (random 16)) (aref hex (random 16))
            (aref hex (random 16)) (aref hex (random 16))
            (aref hex (random 16))
            ;; variant: 8, 9, a, b
            (aref "89ab" (random 4))
            (aref hex (random 16)) (aref hex (random 16))
            (aref hex (random 16))
            (aref hex (random 16)) (aref hex (random 16))
            (aref hex (random 16)) (aref hex (random 16))
            (aref hex (random 16)) (aref hex (random 16))
            (aref hex (random 16)) (aref hex (random 16))
            (aref hex (random 16)) (aref hex (random 16))
            (aref hex (random 16)) (aref hex (random 16)))))

;;; ============================================================
;;; 主题文件读写
;;; ============================================================

(defun claude-code-logger--topic-dir (project-dir)
  "返回 PROJECT-DIR 对应的主题目录路径，不存在则创建。"
  (let ((dir (expand-file-name
              (claude-code-logger--project-slug project-dir)
              claude-code-logger-topic-dir)))
    (unless (file-directory-p dir)
      (make-directory dir t))
    dir))

(defun claude-code-logger--list-topics (project-dir)
  "列出 PROJECT-DIR 下所有已保存的主题名。"
  (let ((dir (claude-code-logger--topic-dir project-dir)))
    (when (file-directory-p dir)
      (mapcar (lambda (f)
                (file-name-sans-extension (file-name-nondirectory f)))
              (directory-files dir t "\\.json$")))))

(defun claude-code-logger--topic-file (project-dir topic-name)
  "返回主题文件的完整路径。"
  (expand-file-name (concat topic-name ".json")
                    (claude-code-logger--topic-dir project-dir)))

(defun claude-code-logger--read-topic (project-dir topic-name)
  "读取 PROJECT-DIR 下名为 TOPIC-NAME 的主题映射，返回 alist。"
  (let ((file (claude-code-logger--topic-file project-dir topic-name)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (json-read)))))

(defun claude-code-logger--save-topic (project-dir topic-name org-file sessions)
  "保存/更新主题映射。
SESSIONS 为 ((role . session-id) ...) 形式的 alist。"
  (let* ((file (claude-code-logger--topic-file project-dir topic-name))
         (existing (and (file-exists-p file)
                        (with-temp-buffer
                          (insert-file-contents file)
                          (json-read))))
         (now (format-time-string "%Y-%m-%dT%H:%M:%S"))
         (data `((name . ,topic-name)
                 (org_file . ,(expand-file-name org-file))
                 (created . ,(or (cdr (assoc 'created existing)) now))
                 (updated . ,now)
                 (sessions . ,sessions))))
    (with-temp-file file
      (let ((json-encoding-pretty-print t))
        (insert (json-encode data))))))

;;; ============================================================
;;; IPC 通信记录
;;; ============================================================

(defun claude-code-logger--record-ipc (orig-fn target message)
  "Advice around `claude-code-ipc-send'，实时追加写日志文件。"
  (let* ((time (format-time-string "%Y-%m-%d %H:%M:%S"))
         (result (funcall orig-fn target message)))
    (push (list :time time :to target :message message :result result)
          claude-code-logger--ipc-log)
    ;; 崩溃安全：实时追加到文件
    (let ((log-file (expand-file-name "ipc.log" claude-code-logger-topic-dir)))
      (unless (file-directory-p claude-code-logger-topic-dir)
        (make-directory claude-code-logger-topic-dir t))
      (append-to-file
       (format "[%s] → %s: %s | %s\n" time target
               (truncate-string-to-width message 200) result)
       nil log-file))
    result))

(advice-add 'claude-code-ipc-send :around #'claude-code-logger--record-ipc)

(provide 'claude-code-logger)
;;; claude-code-logger.el ends here
