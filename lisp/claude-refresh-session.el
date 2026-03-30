;;; claude-refresh-session.el --- 刷新单个角色的 session

(defun claude-code-refresh-session ()
  "删除当前 Claude 实例在 topic 文件中的 session-id，下次 resume 会生成新的。"
  (interactive)
  (let ((buf (current-buffer)))
    (unless (claude-code--buffer-p buf)
      (user-error "当前 buffer 不是 Claude 实例"))
    (let ((topic (buffer-local-value 'claude-code--k8s-topic buf))
          (char-id (and (fboundp 'claude-code--get-character-id)
                        (claude-code--get-character-id buf))))
      (unless (and topic char-id)
        (user-error "无法读取 topic 或角色信息"))
      (let* ((slug (buffer-local-value 'claude-code--topic-slug buf))
             (file (expand-file-name (concat topic ".json") (expand-file-name slug "~/.claude/topics/"))))
        (unless (file-exists-p file)
          (user-error "未找到 topic 文件"))
        (when (y-or-n-p (format "删除 '%s' 的 session-id？下次 resume 会创建新的。" char-id))
          (with-temp-buffer
            (insert-file-contents file)
            (let ((data (json-read)))
              (when (alist-get 'sessions data)
                (let ((sessions (alist-get 'sessions data)))
                  (setf (alist-get 'sessions data)
                        (assq-delete-all (intern char-id) sessions))))
              (erase-buffer)
              (insert (json-encode data))
              (write-file file)))
          (message "已删除 '%s' 的 session-id" char-id))))))

(provide 'claude-refresh-session)
;;; claude-refresh-session.el ends here
