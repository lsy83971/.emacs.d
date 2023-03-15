(python-shell-send-string "# -*- coding: utf-8 -*-\n\n\n\na")
(elpy-shell-send-region-or-buffer-and-step)
(let ((process (or process (python-shell-get-process-or-error msg)))
        (code (format "__PYTHON_EL_eval(%s, %s)\n"
                      (python-shell--encode-string string)
                      (python-shell--encode-string (or (buffer-file-name)
                                                       "<string>")))))
    (unless python-shell-output-filter-in-progress
      (with-current-buffer (process-buffer process)
        (save-excursion
          (goto-char (process-mark process))
          (insert-before-markers "\n"))))
    (if (or (null (process-tty-name process))
            (<= (string-bytes code)
                (or (bound-and-true-p comint-max-line-length)
                    1024))) ;; For Emacs < 28
        (comint-send-string process code)
      (let* ((temp-file-name (with-current-buffer (process-buffer process)
                               (python-shell--save-temp-file string)))
             (file-name (or (buffer-file-name) temp-file-name)))
        (python-shell-send-file file-name process temp-file-name t))))
