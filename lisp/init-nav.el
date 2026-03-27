;;; ============================================================
;;; avy：跳转 + Claude 实例 copy 模式管理
;;; ============================================================

(defmacro my/avy--with-english-im (&rest body)
  "执行 BODY 前暂时关闭输入法（rime），完成后恢复。"
  (declare (indent 0))
  `(let ((im--was-active current-input-method))
     (when im--was-active (deactivate-input-method))
     (unwind-protect (progn ,@body)
       (when im--was-active (activate-input-method im--was-active)))))

(defun my/avy--enter-copy-mode-all ()
  "让所有可见窗口中的 Claude 实例进入 copy 模式，返回已处理的窗口列表。"
  (let (entered)
    (dolist (win (window-list))
      (with-selected-window win
        (when (and (fboundp 'claude-code--buffer-p)
                   (claude-code--buffer-p (current-buffer))
                   (not (bound-and-true-p vterm-copy-mode)))
          (let ((win-start (window-start))
                (win-point (window-point)))
            (claude-code--term-read-only-mode claude-code-terminal-backend)
            (set-window-start win win-start t)
            (goto-char (max win-point win-start)))
          (push win entered))))
    entered))

(defun my/avy--exit-copy-mode-others (entered-wins)
  "跳转后，非当前窗口的 Claude 实例退出 copy 模式。"
  (let ((cur-win (selected-window)))
    (dolist (win entered-wins)
      (unless (eq win cur-win)
        (with-current-buffer (window-buffer win)
          (when (bound-and-true-p vterm-copy-mode)
            (vterm-copy-mode -1)
            (setq-local cursor-type nil)))))))

(defun my/avy-goto-char-timer ()
  "avy 跳转，自动管理 Claude 实例的 copy 模式。"
  (interactive)
  (my/avy--with-english-im
    (let ((entered-wins (my/avy--enter-copy-mode-all)))
      (avy-goto-char-timer)
      (my/avy--exit-copy-mode-others entered-wins))))

(defun my/avy-save-line ()
  "用 avy 选择一行，复制到 kill-ring（不粘贴、不删除、光标和窗口不动）。
vterm buffer 中自动过滤控制字符。"
  (interactive)
  (my/avy--with-english-im
  (save-selected-window
    (let ((orig-win (selected-window))
          (orig-point (point))
          (orig-start (window-start)))
      (avy-goto-line)
      (let* ((beg (line-beginning-position))
             (end (line-beginning-position 2))
             (raw (buffer-substring beg end))
             (cleaned (if (and (fboundp 'vterm--filter-buffer-substring)
                               (derived-mode-p 'vterm-mode))
                          (vterm--filter-buffer-substring raw)
                        raw)))
        (kill-new cleaned))
      ;; 确保回到原窗口
      (select-window orig-win)
      (goto-char orig-point)
      (set-window-start orig-win orig-start t)
      (message "已复制到 kill-ring")))))

(defun my/avy-save-region ()
  "用 avy 选两个点，区域内容复制到 kill-ring（不删除、光标和窗口不动）。
vterm buffer 中自动过滤控制字符。"
  (interactive)
  (my/avy--with-english-im
  (save-selected-window
    (let ((orig-win (selected-window))
          (orig-point (point))
          (orig-start (window-start)))
      (avy-goto-char-timer)
      (let ((p1 (point)))
        (avy-goto-char-timer)
        (let* ((p2 (point))
               (beg (min p1 p2))
               (end (max p1 p2))
               (raw (buffer-substring beg end))
               (cleaned (if (and (fboundp 'vterm--filter-buffer-substring)
                                 (derived-mode-p 'vterm-mode))
                            (vterm--filter-buffer-substring raw)
                          raw)))
          (kill-new cleaned)))
      ;; 确保回到原窗口和位置
      (select-window orig-win)
      (goto-char orig-point)
      (set-window-start orig-win orig-start t)
      (message "已复制区域到 kill-ring")))))

;; 为直接绑定的 avy 命令也加上输入法切换
(defun my/avy-goto-line ()
  "avy-goto-line，自动切英文输入法。"
  (interactive)
  (my/avy--with-english-im (avy-goto-line)))

(defun my/avy-goto-word-1 ()
  "avy-goto-word-1，自动切英文输入法。"
  (interactive)
  (my/avy--with-english-im (call-interactively #'avy-goto-word-1)))

(defun my/avy-move-line ()
  "avy-move-line，自动切英文输入法。"
  (interactive)
  (my/avy--with-english-im (call-interactively #'avy-move-line)))

(defun my/avy-kill-whole-line ()
  "avy-kill-whole-line，自动切英文输入法。"
  (interactive)
  (my/avy--with-english-im (call-interactively #'avy-kill-whole-line)))

(defun my/avy-kill-region ()
  "avy-kill-region，自动切英文输入法。"
  (interactive)
  (my/avy--with-english-im (call-interactively #'avy-kill-region)))

(use-package avy
  :bind (("C-2" . my/avy-goto-char-timer)
         ("C-;" . my/avy-goto-char-timer)
         ("M-g l" . my/avy-goto-line)
         ("M-g w" . my/avy-goto-word-1)
         ("C-c y" . my/avy-save-line)
         ("C-c m" . my/avy-move-line)
         ("C-c k" . my/avy-kill-whole-line)
         ("C-c K" . my/avy-kill-region)
         ("C-c Y" . my/avy-save-region)))

;;; ============================================================
;;; multiple-cursors
;;; ============================================================

(use-package multiple-cursors
  :bind
  (("C->" . mc/mark-next-like-this)
   ("C-<" . mc/mark-previous-like-this)
   ("C-c C-<" . mc/mark-all-like-this)
   )
  )

;;; ============================================================
;;; 复制路径/角色名
;;; ============================================================

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
(setq select-active-regions nil) ;; 禁用 "选中区域自动复制到剪贴板"

;;; ============================================================
;;; 剪切/复制/粘贴/删除
;;; ============================================================

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
