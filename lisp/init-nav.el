(use-package avy
  :bind (("C-2" . avy-goto-char-timer)
         ("M-g l" . avy-goto-line)
         ("M-g w" . avy-goto-word-1)
         ("C-c y" . avy-copy-line)
         ("C-c m" . avy-move-line)
         ("C-c k" . avy-kill-whole-line)))


(use-package multiple-cursors
  :bind
  (("C->" . mc/mark-next-like-this)
   ("C-<" . mc/mark-previous-like-this)
   ("C-c C-<" . mc/mark-all-like-this)
   )
  )

(defun lsy:copy-file-name()
  "put current file name in the killing ring"
  (interactive)
  (kill-new (buffer-file-name))
  )

(defun lsy:copy-character-id ()
  "将 Claude buffer 的角色名（instance name）复制到 kill ring。
当前不是 Claude buffer 时弹出选择。"
  (interactive)
  (let* ((buf (if (and (fboundp 'claude-code--buffer-p)
                       (claude-code--buffer-p (current-buffer)))
                  (current-buffer)
                (and (fboundp 'claude-code--get-or-prompt-for-buffer)
                     (claude-code--get-or-prompt-for-buffer))))
         (cid (and buf (fboundp 'claude-code--get-character-id)
                   (claude-code--get-character-id buf))))
    (if cid
        (progn (kill-new cid) (message "已复制角色名: %s" cid))
      (message "该实例未设置角色名"))))

(global-set-key (kbd "<f5>") #'lsy:copy-character-id)

(setq x-select-enable-clipboard t)
(setq select-active-regions nil) ;; 禁用 “选中区域自动复制到剪贴板” 


(defun lsy-kill ()
  (interactive)
  (if (region-active-p)
      (call-interactively #'kill-ring-save) ;; then
      (kill-ring-save (line-beginning-position) (line-end-position))
      ))

(defun lsy-kill-region ()
  (interactive)
  (if (region-active-p)
      (call-interactively #'kill-region) ;; then
      (kill-region (line-beginning-position) (line-end-position))
      ))

(defun lsy-yank ()
  (interactive)
  (if (region-active-p)
      (progn
	(delete-region (region-beginning) (region-end))
	(call-interactively #'yank)	
       )
      (call-interactively #'yank) ;; then
      ))

(defun insert-split-line ()
  (interactive)
  (save-restriction
    (narrow-to-region (line-beginning-position) (line-end-position))
    (goto-char (point-min))
    (setq a (re-search-forward "[^ ]" nil t))
    (if (null a)
        (progn
          (goto-char (point-min))
          (delete-char (- (point-max) (point-min)))
          (insert "-----------------------------------------------------------------"))
      (progn
        (goto-char (point-min))
        (insert "-----------------------------------------------------------------\n")))))


(defun my-delete-region-no-kill ()
  "删除选中的区域，但不将内容加入 kill ring/剪贴板"
  (interactive)
  (cond
   ;; 有选中区域且不在minibuffer中：删除区域
   ((and (region-active-p) (not (minibufferp)))
    (delete-region (region-beginning) (region-end))
    (deactivate-mark))
   
   ;; 在minibuffer中：使用ivy的backspace函数（如果可用）
   ((minibufferp)
    (if (and (boundp 'ivy-mode) ivy-mode (fboundp 'ivy-backward-delete-char))
        (call-interactively 'ivy-backward-delete-char)
      (backward-delete-char-untabify 1)))
   
   ;; 其他情况：普通backspace
   (t
    (backward-delete-char-untabify 1))))  ; 无选中时执行普通 Backspace


(defun my-backward-delete-word-no-kill ()
  "Delete the word backward from point, without adding to kill ring.
In minibuffer, use default backward-kill-word instead."
  (interactive)
  (if (minibufferp)
      ;; 在minibuffer中使用默认行为
      (backward-kill-word 1)
    ;; 在非minibuffer中使用不加入kill ring的删除
    (let ((beg (point)))
      ;; 移动光标到单词开头（与原生 backward-kill-word 逻辑一致）
      (backward-word)
      ;; 纯删除区域内容，不调用 kill 函数
      (delete-region beg (point)))))

;; 自定义：向前删除一个单词，不写入 kill ring/剪贴板（可选，对应 kill-word）
(defun my-forward-delete-word-no-kill ()
  "Delete the word forward from point, without adding to kill ring.
In minibuffer, use default kill-word instead."
  (interactive)
  (if (minibufferp)
      ;; 在minibuffer中使用默认行为
      (kill-word 1)
    ;; 在非minibuffer中使用不加入kill ring的删除
    (let ((beg (point)))
      (forward-word)
      (delete-region beg (point)))))

(global-set-key (kbd "C-<backspace>") 'my-backward-delete-word-no-kill)
(global-set-key (kbd "C-<delete>") 'my-forward-delete-word-no-kill)

(defun lsy:copy-path-from-buffers-and-recentf ()
  "从 buffer 列表和 recentf 中选择一个文件路径，复制其绝对路径到剪切板。"
  (interactive)
  (require 'recentf)
  (let* ((buffer-paths
          (delq nil (mapcar (lambda (b)
                              (buffer-file-name b))
                            (buffer-list))))
         (recent-paths (mapcar #'expand-file-name recentf-list))
         (all-paths (delete-dups (append buffer-paths recent-paths)))
         (chosen (completing-read "复制路径: " all-paths nil t)))
    (kill-new chosen)
    (message "已复制: %s" chosen)))

;; 将 Backspace 键映射到自定义函数
(global-set-key (kbd "<f7>" ) 'lsy:copy-file-name)
(global-set-key (kbd "<f6>" ) 'lsy:copy-path-from-buffers-and-recentf)
(global-set-key (kbd "M-w" ) 'lsy-kill)
(global-set-key (kbd "C-w" ) 'lsy-kill-region)
(global-set-key (kbd "C-y" ) 'lsy-yank)
(global-set-key (kbd "<backspace>") 'my-delete-region-no-kill)

(global-set-key (kbd "S-<left>" ) 'windmove-left)
(global-set-key (kbd "S-<right>" ) 'windmove-right)
(global-set-key (kbd "S-<up>" ) 'windmove-up)
(global-set-key (kbd "S-<down>" ) 'windmove-down)


(provide 'init-nav)
