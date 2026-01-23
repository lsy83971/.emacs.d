(require 'subr-x)
;;(global-hungry-delete-mode nil)
(defun lsy-python-shell-insert-string (s)
  (let* ((process (python-shell-get-process-or-error)))
    (with-current-buffer (process-buffer process)
      (save-excursion
        (goto-char (process-mark process))
        ;;(insert-before-markers "\n... ")
	(insert-before-markers s)
	))

    )
  )

(defun lsy-change-cwd ()
  (let ((
	 cmd (concat
	      "import os\n"
	      "os.chdir("
	      "'"
	      (file-name-directory (directory-file-name (buffer-file-name)))
	      "'"
	      ")\n"
	      "import pandas as pd\n"
	      "pd.set_option('display.max_rows',500)\n"
	      "import warnings\n"
	      "warnings.filterwarnings('ignore')\n"
	      )
	     ))
    (python-shell-send-string cmd)
    ))

(defun lsy-python-eval-line ()
  (interactive)
  (let* (
	 (window (selected-window))
	 )
    (if (get-buffer-process "*Python*")
	nil
      (elpy-shell--ensure-shell-running)
      (lsy-change-cwd)
      )
    ;; TODO
    ;; NOT UPDATE completion-at-point-function
    (defun company--capf-data-real ()
      (cl-letf* (((default-value 'completion-at-point-functions)
		  ;; Ignore tags-completion-at-point-function because it subverts
		  ;; company-etags in the default value of company-backends, where
		  ;; the latter comes later.
		  (remove 'tags-completion-at-point-function
			  (default-value 'completion-at-point-functions)))
		 (completion-at-point-functions (company--capf-workaround))
		 (data (run-hook-wrapped 'completion-at-point-functionsa
					 ;; Ignore misbehaving functions.
					 #'completion--capf-wrapper 'optimist)))
	(when (and (consp (cdr data)) (integer-or-marker-p (nth 1 data))) data)))
    (if(use-region-p)
	(let* ((p1 (region-beginning))
	       (p2 (region-end))
	       (p3 (line-beginning-position))
	       (p4 (line-end-position))
	       (tmp-string (buffer-substring p1 p2))
	       (tmp-string (string-trim  tmp-string))
	       ;;(tmp-string (string-replace "\\" "\\\\" tmp-string))
	       )
	  (if (and (<= p2 p4) (>= p1 p3))
	      (progn
		(lsy-python-shell-insert-string tmp-string)
		(python-shell-send-string tmp-string)
		)
	    (elpy-shell-send-region-or-buffer)
	    ))
      (let* ((p1 (line-beginning-position))
	     (p2 (line-end-position))
	     (tmp-string (buffer-substring p1 p2))
	     ;;(tmp-string (string-replace "\\" "\\\\" tmp-string))
	     (tmp-string (string-trim  tmp-string))
	     )
	(progn
	  (lsy-python-shell-insert-string tmp-string)
	  (python-shell-send-string tmp-string)
	  )
	))

    (select-window window)
    )
  )

(use-package electric-spacing)
(use-package elpy)
(use-package rainbow-delimiters
  :ensure t
  :defer t)

(use-package python-mode
  :ensure t
  :hook
  (
   (python-mode
    .
    (lambda ()
      (hs-minor-mode t)
      (electric-spacing-mode)
      (setq-local electric-spacing-operators
		  '(?= ?< ?> ?% ?+ ?- ?* ?/ ?& ?| ?: ?? ?, ?~ ?. ?^ ?\; ?!))
      (elpy-enable)
      (setq-local company-backends (cons 'elpy-company-backend company-backends))
      (company-mode 1)
      (rainbow-delimiters-mode)
      ))
   )
  :ensure t
  :custom(
	  (python-shell-prompt-regexp "In \\[[0-9]+\\]: ")
	  (python-shell-prompt-output-regexp "Out\\[[0-9]+\\]: ")
	  )
  :bind
  (:map python-mode-map
	("C-r" . lsy-python-eval-line)
	("M-," . xref-pop-marker-stack)
	("C-<up>" . python-nav-backward-defun)
	("C-<down>" . python-nav-forward-defun)
	("C-<down>" . python-nav-forward-defun)
	("C-<tab>" . hs-toggle-hiding)			
	)
  :config
  (setq read-process-output-max (* 1024 1024))
  (setq gc-cons-threshold (eval-when-compile (* 1024 1024 1024)))
  (if (eq system-type 'windows-nt)
      (progn
	(setq python-shell-interpreter "C:/Users/52258/AppData/Local/Python/bin/python.exe")
	(setq elpy-rpc-python-command "C:/Users/52258/AppData/Local/Python/bin/python.exe")
	)
    (setq python-shell-interpreter "python3")
    )
  )

(if (eq system-type 'windows-nt)
    (progn
	(setq python-shell-interpreter "C:/Users/52258/AppData/Local/Python/bin/python.exe")
	(setq elpy-rpc-python-command "C:/Users/52258/AppData/Local/Python/bin/python.exe")
      )
  )

(when (eq system-type 'windows-nt)
  ;; 1. 设置 Python 环境变量
  (setenv "PYTHONIOENCODING" "utf-8")
  (setenv "PYTHONUTF8" "1")  ; Python 3.7+
  
  ;; 2. 设置 Elpy RPC 参数
  (setq elpy-rpc-python-command python-shell-interpreter)
  (setq elpy-rpc-python-command-args
        '("-c" "import sys; sys.stdout.reconfigure(encoding='utf-8'); import elpy.__main__; elpy.__main__.main()"))
  
  ;; 3. 强制使用 UTF-8 编码
  (prefer-coding-system 'utf-8)
  (setq default-process-coding-system '(utf-8 . utf-8))
  
  ;; 4. 设置 Python shell 编码
  (setq python-shell-encoding "utf-8")
  (setq python-shell-font-lock-encoding "utf-8")
  
  ;; 5. 为 Elpy RPC 进程单独设置环境
  (defun my/elpy-rpc-environment ()
    "为 Elpy RPC 设置环境变量"
    (let ((process-environment (copy-sequence process-environment)))
      (setenv "PYTHONIOENCODING" "utf-8")
      (setenv "PYTHONUTF8" "1")
      (setenv "LC_ALL" "en_US.UTF-8")
      (setenv "LANG" "en_US.UTF-8")
      process-environment))
  (setq elpy-rpc--process-environment-function #'my/elpy-rpc-environment))

(setq elpy-modules (delq 'elpy-module-flymake elpy-modules))
(setq elpy-modules (delq 'elpy-module-syntax-checking elpy-modules))

(provide 'init-python)


