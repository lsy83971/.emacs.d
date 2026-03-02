(global-set-key (kbd "C-1") 'set-mark-command)
(global-set-key (kbd "C-t") 'anzu-query-replace)
(global-set-key (kbd "C-j") 'mc/edit-lines)
(global-set-key (kbd "C-3") 'toggle-input-method)

(defun my-backward-delete-word ()
  "向后删除单词，不保存到 kill ring。"
  (interactive)
  (delete-region (point) (progn (backward-word) (point))))
;;(global-set-key (kbd "M-DEL") 'my-backward-delete-word)
(global-set-key (kbd "M-<backspace>") 'my-backward-delete-word)

(provide 'init-keymap)
