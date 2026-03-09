(require 'subr-x)

(defun lsy-python-shell-insert-string (s)
  (let* ((process (python-shell-get-process-or-error)))
    (with-current-buffer (process-buffer process)
      (save-excursion
        (goto-char (process-mark process))
	(insert-before-markers s)))))

(defun lsy-change-cwd ()
  (let ((cmd (concat
	      "import os\n"
	      "os.chdir("
	      "'"
	      (file-name-directory (directory-file-name (buffer-file-name)))
	      "'"
	      ")\n"
	      "import pandas as pd\n"
	      "pd.set_option('display.max_rows',500)\n"
	      "import warnings\n"
	      "warnings.filterwarnings('ignore')\n")))
    (python-shell-send-string cmd)))

(defun lsy-python-eval-line ()
  (interactive)
  (let* ((window (selected-window)))
    (if (get-buffer-process "*Python*")
	nil
      (elpy-shell--ensure-shell-running)
      (lsy-change-cwd))
    (if (use-region-p)
	(let* ((p1 (region-beginning))
	       (p2 (region-end))
	       (p3 (line-beginning-position))
	       (p4 (line-end-position))
	       (tmp-string (string-trim (buffer-substring p1 p2))))
	  (if (and (<= p2 p4) (>= p1 p3))
	      (progn
		(lsy-python-shell-insert-string tmp-string)
		(python-shell-send-string tmp-string))
	    (elpy-shell-send-region-or-buffer)))
      (let* ((p1 (line-beginning-position))
	     (p2 (line-end-position))
	     (tmp-string (string-trim (buffer-substring p1 p2))))
	(lsy-python-shell-insert-string tmp-string)
	(python-shell-send-string tmp-string)))
    (select-window window)))

(use-package electric-spacing)
(use-package elpy)
(use-package rainbow-delimiters
  :ensure t
  :defer t)

(use-package python-mode
  :ensure t
  :hook
  ((python-mode
    .
    (lambda ()
      (hs-minor-mode t)
      (electric-spacing-mode)
      (setq-local electric-spacing-operators
		  '(?= ?< ?> ?% ?+ ?- ?* ?/ ?& ?| ?: ?? ?, ?~ ?. ?^ ?\; ?!))
      (setq-local company-backends '(elpy-company-backend
                                     company-capf
                                     company-dabbrev-code
                                     company-files))
      (company-mode 1)
      (rainbow-delimiters-mode))))
  :config
  (elpy-enable)
  :custom
  ((python-shell-prompt-regexp "In \\[[0-9]+\\]: ")
   (python-shell-prompt-output-regexp "Out\\[[0-9]+\\]: "))
  :bind
  (:map python-mode-map
	("C-r" . lsy-python-eval-line)
	("M-," . xref-pop-marker-stack)
	("C-<up>" . python-nav-backward-defun)
	("C-<down>" . python-nav-forward-defun)
	("C-<tab>" . hs-toggle-hiding))
  :config
  (setq read-process-output-max (* 1024 1024))
  (setq gc-cons-threshold (* 100 1024 1024))  ;; 100MB，不要 1GB
  (if (eq system-type 'windows-nt)
      (progn
	(setq python-shell-interpreter "C:/Users/52258/AppData/Local/Python/bin/python.exe")
	(setq elpy-rpc-python-command "C:/Users/52258/AppData/Local/Python/bin/python.exe"))
    (setq python-shell-interpreter "python3")))

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
