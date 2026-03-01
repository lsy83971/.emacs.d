(use-package gptel
  :ensure t
  :config
  (gptel-make-openai "OpenRouter"
    :host "openrouter.ai"
    :endpoint "/api/v1/chat/completions"
    :stream t
    :key "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"
    :models '(deepseek/deepseek-v3.2
              anthropic/claude-sonnet-4-6))

  (setq gptel-backend (gptel-get-backend "OpenRouter")
        gptel-model   'deepseek/deepseek-v3.2
        gptel-proxy   "http://127.0.0.1:7890")

  (defvar my/clickhouse-host "10.20.128.181")
  (defvar my/clickhouse-port "8123")
  (defvar my/clickhouse-user "ai_reader")
  (defvar my/clickhouse-password "fingfingha")
  (defvar my/clickhouse-database "default")
  (defvar my/workspace-dir "/mnt/lishiyu/AI/")

  (make-directory my/workspace-dir t)

  (setq gptel-tools
        (list
         (gptel-make-tool
          :name "query_clickhouse"
          :description "Execute a SQL query on ClickHouse and return results. Use this to explore schemas and fetch data."
          :args (list '(:name "sql"
                        :type string
                        :description "SQL query to execute"))
          :include t
          :function (lambda (sql)
                      (let ((result (shell-command-to-string
                                     (format "curl -s 'http://%s:%s/?user=%s&password=%s&database=%s&query=%s'"
                                             my/clickhouse-host
                                             my/clickhouse-port
                                             my/clickhouse-user
                                             my/clickhouse-password
                                             my/clickhouse-database
                                             (url-hexify-string sql)))))
                        (if (string-empty-p result)
                            "No results."
                          (substring result 0 (min 5000 (length result)))))))

         (gptel-make-tool
          :name "run_python"
          :description "Execute Python code for data analysis and factor computation. Has pandas, numpy, scipy. Working dir is /tmp/gptel-workspace/."
          :args (list '(:name "code"
                        :type string
                        :description "Python code to execute"))
          :include t
          :function (lambda (code)
                      (let ((script-file (concat my/workspace-dir "gptel_script.py")))
                        (with-temp-file script-file
                          (insert (format "import os\nos.chdir('%s')\n" my/workspace-dir))
                          (insert code))
                        (let ((result (shell-command-to-string
                                       (format "python3 %s 2>&1" script-file))))
                          (if (string-empty-p result)
                              "Code executed with no output."
                            (substring result 0 (min 8000 (length result))))))))

         (gptel-make-tool
          :name "read_file"
          :description "Read contents of a file in the workspace."
          :args (list '(:name "filepath"
                        :type string
                        :description "File path to read"))
          :include t
          :function (lambda (filepath)
                      (let ((path (if (file-name-absolute-p filepath)
                                      filepath
                                    (concat my/workspace-dir filepath))))
                        (if (file-exists-p path)
                            (with-temp-buffer
                              (insert-file-contents path)
                              (let ((content (buffer-string)))
                                (substring content 0 (min 8000 (length content)))))
                          (format "File not found: %s" path)))))

         (gptel-make-tool
          :name "write_file"
          :description "Write content to a file in the workspace."
          :args (list '(:name "filename"
                        :type string
                        :description "Filename to write")
                      '(:name "content"
                        :type string
                        :description "Content to write"))
          :include t
          :function (lambda (filename content)
                      (let ((path (if (file-name-absolute-p filename)
                                      filename
                                    (concat my/workspace-dir filename))))
                        (with-temp-file path
                          (insert content))
                        (format "Written: %s" path))))

         (gptel-make-tool
          :name "list_files"
          :description "List files in the workspace directory."
          :args nil
          :include t
          :function (lambda ()
                      (mapconcat #'identity
                                 (directory-files my/workspace-dir nil nil t)
                                 "\n"))))))
