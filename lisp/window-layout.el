;;; window-layout.el --- Save/restore window layouts by name -*- lexical-binding: t; -*-

(defcustom window-layout-file
  (expand-file-name "window-layouts.el" user-emacs-directory)
  "持久化存储窗口布局的文件路径。"
  :type 'file
  :group 'window-layout)

(defvar window-layout--store (make-hash-table :test 'equal)
  "内存中的布局表，name -> window-state。")

(defun window-layout--save-to-disk ()
  "将布局表写入磁盘。"
  (let ((data '()))
    (maphash (lambda (k v) (push (cons k v) data)) window-layout--store)
    (with-temp-file window-layout-file
      (insert ";; -*- no-byte-compile: t; -*-\n")
      (prin1 data (current-buffer))
      (insert "\n"))))

(defun window-layout--load-from-disk ()
  "从磁盘读取布局表。"
  (when (file-exists-p window-layout-file)
    (with-temp-buffer
      (insert-file-contents window-layout-file)
      (let ((data (read (current-buffer))))
        (clrhash window-layout--store)
        (dolist (pair data)
          (puthash (car pair) (cdr pair) window-layout--store))))))

;; 启动时加载
(window-layout--load-from-disk)

;;;###autoload
(defun window-layout-save (name)
  "保存当前窗口布局，命名为 NAME。"
  (interactive "s布局名称: ")
  (when (string-empty-p name)
    (user-error "名称不能为空"))
  (let ((state (window-state-get (frame-root-window) t)))
    (puthash name state window-layout--store)
    (window-layout--save-to-disk)
    (message "已保存布局: %s" name)))

;;;###autoload
(defun window-layout-load (name)
  "恢复名为 NAME 的窗口布局。"
  (interactive
   (list (let ((names (hash-table-keys window-layout--store)))
           (if names
               (completing-read "加载布局: " names nil t)
             (user-error "没有已保存的布局")))))
  (let ((state (gethash name window-layout--store)))
    (unless state
      (user-error "布局 '%s' 不存在" name))
    ;; 检查布局中引用的 buffer 是否都存在
    (let ((missing '()))
      (cl-labels ((walk (node)
                    (when (proper-list-p node)
                      (let ((buf-entry (alist-get 'buffer node)))
                        (when buf-entry
                          (let ((bname (car buf-entry)))
                            (when (and (stringp bname)
                                       (not (get-buffer bname)))
                              (push bname missing)))))
                      (dolist (child node)
                        (walk child)))))
        (walk state))
      (setq missing (delete-dups missing))
      (when missing
        (user-error "以下 buffer 不存在，无法恢复布局: %s"
                    (string-join missing ", "))))
    (delete-other-windows)
    (window-state-put state (frame-root-window) 'safe)
    (message "已恢复布局: %s" name)))

;;;###autoload
(defun window-layout-delete (name)
  "删除名为 NAME 的布局。"
  (interactive
   (list (let ((names (hash-table-keys window-layout--store)))
           (if names
               (completing-read "删除布局: " names nil t)
             (user-error "没有已保存的布局")))))
  (remhash name window-layout--store)
  (window-layout--save-to-disk)
  (message "已删除布局: %s" name))

;;;###autoload
(defun window-layout-list ()
  "列出所有已保存的布局名称。"
  (interactive)
  (let ((names (sort (hash-table-keys window-layout--store) #'string<)))
    (if names
        (message "已保存的布局: %s" (string-join names ", "))
      (message "没有已保存的布局"))))

(global-set-key (kbd "C-c w s") #'window-layout-save)
(global-set-key (kbd "C-c w l") #'window-layout-load)
(global-set-key (kbd "C-c w d") #'window-layout-delete)

(provide 'window-layout)
;;; window-layout.el ends here
