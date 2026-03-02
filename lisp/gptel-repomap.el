;;; gptel-repomap.el — Repo Map 集成：让 gptel 自动理解代码结构
;;
;; 依赖：repo-map.py（放在同目录，或配置 grm/script-path）
;;
;; 和 gptel-memory.el 的分工：
;;   gptel-memory.el  → 保存"你告诉 AI 的知识"（人工提炼的理解）
;;   gptel-repomap.el → 自动提取"代码本身的结构"（机器解析的事实）
;;
;; 两者叠加，才是完整的上下文。

;;; ─── 配置 ────────────────────────────────────────────────────────────────────

(defgroup gptel-repomap nil
  "Repo Map 配置"
  :group 'gptel)

(defcustom grm/script-path
  (expand-file-name "repo-map.py"
                    (file-name-directory (or load-file-name buffer-file-name "")))
  "repo-map.py 的路径。如果放在其他位置，修改这里。"
  :type 'file
  :group 'gptel-repomap)

(defcustom grm/default-tokens 2000
  "默认的 token 预算（越大上下文越丰富，但消耗更多）。"
  :type 'integer
  :group 'gptel-repomap)

(defcustom grm/output-file ".repo-map.md"
  "生成的 repo map 缓存文件名（放在项目根目录）。"
  :type 'string
  :group 'gptel-repomap)

(defcustom grm/auto-refresh t
  "非 nil 时，每次加载前自动重新生成 repo map。"
  :type 'boolean
  :group 'gptel-repomap)

;;; ─── 工具函数 ─────────────────────────────────────────────────────────────────

(defun grm/project-root ()
  "返回当前项目根目录。"
  (or (and (fboundp 'projectile-project-root) (projectile-project-root))
      (and (fboundp 'vc-root-dir) (vc-root-dir))
      default-directory))

(defun grm/output-path ()
  "返回 repo map 输出文件的完整路径。"
  (expand-file-name grm/output-file (grm/project-root)))

(defun grm/check-script ()
  "检查 repo-map.py 是否存在，给出提示。"
  (unless (file-exists-p grm/script-path)
    (user-error "找不到 repo-map.py，请设置 grm/script-path。当前路径：%s" grm/script-path)))

;;; ─── 生成 Repo Map ────────────────────────────────────────────────────────────

(defun grm/generate (&optional paths tokens callback)
  "在后台运行 repo-map.py，生成 repo map 并写入文件。
   PATHS 是要分析的路径列表（默认项目根目录）。
   TOKENS 是 token 预算（默认 grm/default-tokens）。
   CALLBACK 是完成后的回调函数（异步模式）。"
  (grm/check-script)
  (let* ((root    (grm/project-root))
         (paths   (or paths (list root)))
         (tokens  (or tokens grm/default-tokens))
         (outfile (grm/output-path))
         (cmd     (append (list "python3" grm/script-path
                                "--tokens" (number-to-string tokens))
                          paths))
         (default-directory root))
    (if callback
        ;; 异步
        (let ((proc (make-process
                     :name "repo-map"
                     :buffer " *repo-map*"
                     :command cmd
                     :sentinel (lambda (proc event)
                                 (when (string-match "finished" event)
                                   (with-current-buffer (process-buffer proc)
                                     (write-region (point-min) (point-max) outfile))
                                   (kill-buffer (process-buffer proc))
                                   (message "✓ Repo map 已生成：%s" outfile)
                                   (funcall callback outfile))))))
          proc)
      ;; 同步
      (let ((result (apply #'call-process-region nil nil "python3" nil
                           (list " *repo-map-sync*" nil) nil
                           (cdr cmd))))
        (with-current-buffer " *repo-map-sync*"
          (write-region (point-min) (point-max) outfile)
          (kill-buffer))
        (if (= result 0)
            (progn (message "✓ Repo map 已生成：%s (~%d tokens)" outfile tokens) outfile)
          (message "✗ repo-map.py 失败，见 *repo-map-error*") nil)))))

(defun grm/generate-sync (&optional paths tokens)
  "同步生成 repo map，返回输出文件路径。"
  (grm/check-script)
  (let* ((root   (grm/project-root))
         (paths  (or paths (list root)))
         (tokens (or tokens grm/default-tokens))
         (outfile (grm/output-path))
         (args   (append (list grm/script-path
                               "--tokens" (number-to-string tokens))
                         paths))
         (default-directory root)
         (buf (generate-new-buffer " *repo-map-out*")))
    (unwind-protect
        (let ((exit (apply #'call-process "python3" nil buf nil args)))
          (if (= exit 0)
              (progn
                (with-current-buffer buf
                  (write-region (point-min) (point-max) outfile))
                outfile)
            (message "✗ repo-map 生成失败")
            nil))
      (kill-buffer buf))))

;;; ─── 加载 Repo Map 到 gptel ──────────────────────────────────────────────────

(defun grm/load (&optional paths tokens)
  "生成并加载 repo map 到 gptel 上下文。
   这是最常用的入口，分析代码前调用。"
  (interactive)
  (let* ((outfile (grm/output-path))
         (need-regen (or grm/auto-refresh
                         (not (file-exists-p outfile)))))
    (if need-regen
        (progn
          (message "正在生成 repo map...")
          (let ((result (grm/generate-sync paths tokens)))
            (when result
              (gptel-add-file result)
              (message "✓ Repo map 已加载（%s）" result))))
      ;; 直接用缓存
      (gptel-add-file outfile)
      (message "✓ 使用缓存的 repo map：%s" outfile))))

(defun grm/load-async (&optional paths tokens)
  "异步生成并加载 repo map（不阻塞 Emacs）。"
  (interactive)
  (message "后台生成 repo map...")
  (grm/generate
   paths tokens
   (lambda (outfile)
     (gptel-add-file outfile)
     (message "✓ Repo map 已异步加载，可以开始对话"))))

;;; ─── 局部分析：只分析当前文件相关的模块 ────────────────────────────────────

(defun grm/load-for-current-file ()
  "只为当前文件生成局部 repo map（更精准，token 更少）。
   适合：我在看某个文件，想让 AI 理解它和它的依赖。"
  (interactive)
  (unless (buffer-file-name)
    (user-error "当前 buffer 没有关联文件"))
  (let* ((current-file (buffer-file-name))
         (root (grm/project-root))
         ;; 分析当前文件 + 项目根（给全局视图）
         (args (list current-file root))
         (tokens (min grm/default-tokens 1500)))
    (message "正在为 %s 生成局部 repo map..."
             (file-name-nondirectory current-file))
    (grm/generate-sync args tokens)
    (grm/load args tokens)))

;;; ─── 查看 Repo Map ───────────────────────────────────────────────────────────

(defun grm/view ()
  "打开 repo map 文件查看（带 markdown 高亮）。"
  (interactive)
  (let ((outfile (grm/output-path)))
    (if (file-exists-p outfile)
        (progn
          (find-file outfile)
          (when (fboundp 'markdown-mode) (markdown-mode))
          (read-only-mode 1))
      (message "尚未生成 repo map，运行 C-c r l 生成"))))

;;; ─── 符号跳转（从 JSON 输出） ────────────────────────────────────────────────

(defvar grm/symbols-cache nil "缓存的符号列表。")

(defun grm/refresh-symbols ()
  "刷新符号缓存（JSON 模式）。"
  (grm/check-script)
  (let* ((root (grm/project-root))
         (args (list grm/script-path "--json" root))
         (buf  (generate-new-buffer " *repo-map-json*"))
         (default-directory root))
    (unwind-protect
        (when (= 0 (apply #'call-process "python3" nil buf nil args))
          (with-current-buffer buf
            (goto-char (point-min))
            (let* ((data    (json-read))
                   (symbols (alist-get 'symbols data)))
              (setq grm/symbols-cache
                    (mapcar (lambda (s)
                              (list (alist-get 'name s)
                                    (alist-get 'file s)
                                    (alist-get 'line s)
                                    (alist-get 'kind s)
                                    (alist-get 'signature s)
                                    (alist-get 'score s)))
                            symbols)))))
      (kill-buffer buf))
    grm/symbols-cache))

(defun grm/jump-to-symbol ()
  "用 completing-read 选择符号并跳转到定义处。"
  (interactive)
  (unless grm/symbols-cache
    (message "正在解析符号...")
    (grm/refresh-symbols))
  (let* ((candidates
          (mapcar (lambda (s)
                    (cons (format "%-30s %-8s %s"
                                  (car s) (nth 3 s) (nth 4 s))
                          s))
                  grm/symbols-cache))
         (choice (completing-read "跳转到符号: " (mapcar #'car candidates)))
         (sym (cdr (assoc choice candidates))))
    (when sym
      (let ((file (expand-file-name (nth 1 sym) (grm/project-root)))
            (line (nth 2 sym)))
        (find-file file)
        (goto-char (point-min))
        (forward-line (1- line))
        (message "%s: %s" (nth 3 sym) (nth 4 sym))))))

;;; ─── 完整工作流入口 ──────────────────────────────────────────────────────────

(defun grm/start-session ()
  "一键启动带 repo map 的 gptel 会话。
   = grm/load + gptel/open。
   这是日常最常用的入口。"
  (interactive)
  (grm/load)
  ;; 如果有 gptel-memory，也加载记忆
  (when (and (fboundp 'gm/load-core)
             (gm/root))
    (gm/load-core)
    (message "✓ 同时加载了项目记忆"))
  (gptel)
  (message "✓ 会话已启动：repo map + 记忆 均已注入"))

;;; ─── 键位绑定（C-c r 前缀） ──────────────────────────────────────────────────

(defvar grm/map (make-sparse-keymap) "gptel-repomap keymap。")

(define-key grm/map (kbd "l") #'grm/load)               ;; 加载 repo map
(define-key grm/map (kbd "L") #'grm/load-async)         ;; 异步加载
(define-key grm/map (kbd "f") #'grm/load-for-current-file) ;; 当前文件局部分析
(define-key grm/map (kbd "v") #'grm/view)               ;; 查看 repo map
(define-key grm/map (kbd "s") #'grm/start-session)      ;; 一键启动完整会话
(define-key grm/map (kbd "j") #'grm/jump-to-symbol)     ;; 符号跳转
(define-key grm/map (kbd "J") #'grm/refresh-symbols)    ;; 刷新符号缓存

(global-set-key (kbd "C-c r") grm/map)

(message "gptel-repomap 已加载。C-c r s 一键启动会话。")

;;; gptel-repomap.el ends here
