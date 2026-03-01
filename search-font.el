;; 方法3：检查所有中文字体（包括文泉驿）
(defun find-all-chinese-fonts ()
  "查找所有中文字体"
  (interactive)
  
  (let ((all-fonts (font-family-list))
        (chinese-fonts '())
        (cjk-fonts '())
        (other-fonts '()))
    
    ;; 分类字体
    (dolist (font all-fonts)
      (let ((font-lower (downcase font)))
        (cond
         ;; 文泉驿字体
         ((or (string-match "wqy" font-lower)
              (string-match "wenquan" font-lower)
              (string-match "wenquanyi" font-lower)	      
              (string-match "文泉驿" font))
          (push (cons 'wenquanyi font) chinese-fonts))
         
         ;; 其他中文字体
         ((or (string-match "chinese" font-lower)
              (string-match "cjk" font-lower)
              (string-match "china" font-lower)
              (string-match "中文" font)
              (string-match "简体" font)
              (string-match "繁体" font)
              (string-match "宋体" font)
              (string-match "黑体" font)
              (string-match "微软雅黑" font)
              (string-match "yahei" font-lower)
              (string-match "simsun" font-lower)
              (string-match "noto" font-lower)
              (string-match "思源" font)
              (string-match "sarasa" font-lower))
          (push (cons 'cjk font) cjk-fonts))
         
         ;; 其他字体
         (t
          (push (cons 'other font) other-fonts)))))
    
    ;; 显示结果
    (with-current-buffer (get-buffer-create "*中文字体列表*")
      (erase-buffer)
      
      ;; 文泉驿字体
      (insert "=" 60 "=\n")
      (insert "                   文泉驿字体\n")
      (insert "=" 60 "=\n\n")
      
      (if chinese-fonts
          (progn
            (insert (format "找到 %d 个文泉驿字体:\n\n" (length chinese-fonts)))
            (dolist (font (sort chinese-fonts 
                               (lambda (a b) (string< (cdr a) (cdr b)))))
              (insert (format "  • %s\n" (cdr font)))))
        (insert "未找到文泉驿字体\n"))
      
      ;; 其他中文字体
      (insert "\n" "=" 60 "=\n")
      (insert "                   其他中文字体\n")
      (insert "=" 60 "=\n\n")
      
      (if cjk-fonts
          (progn
            (insert (format "找到 %d 个其他中文字体:\n\n" (length cjk-fonts)))
            (dolist (font (sort cjk-fonts 
                               (lambda (a b) (string< (cdr a) (cdr b)))))
              (insert (format "  • %s\n" (cdr font)))))
        (insert "未找到其他中文字体\n"))
      
      ;; 字体总数
      (insert "\n" "=" 60 "=\n")
      (insert (format "总计: %d 个字体\n" (length all-fonts)))
      (insert "=" 60 "=\n")
      
      (display-buffer (current-buffer)))
    
    (message "已生成中文字体列表，查看缓冲区 *中文字体列表*")))

;; 执行查找
(find-all-chinese-fonts)
(dolist (font (font-family-list))
  (message font)
  )


(defun find-chinese-font-names ()
  "查找包含中文名称的字体"
  (interactive)
  
  (let ((fonts (font-family-list))
        (chinese-fonts '()))
    
    ;; 查找包含中文字符的字体名
    (dolist (font fonts)
      ;; 检查是否包含中文字符（CJK 统一表意文字范围）
      (when (string-match "[\u4e00-\u9fff]" font)
        (push font chinese-fonts)))
    
    ;; 显示结果
    (if chinese-fonts
        (progn
          (message "找到 %d 个包含中文名称的字体:" (length chinese-fonts))
          
          (with-current-buffer (get-buffer-create "*中文字体名*")
            (erase-buffer)
            (insert "=== 中文字体名称列表 ===\n\n")
            
            (dolist (font chinese-fonts)
              ;; 显示原始字符串和解释后的字符串
              (insert (format "原始: %S\n" font))
              (insert (format "显示: %s\n\n" font)))
            
            (display-buffer (current-buffer))))
      
      (message "未找到包含中文名称的字体"))))

;; 运行查找
(find-chinese-font-names)

(defun setup-fonts-using-english-names ()
  "使用英文字体名称避免编码问题"
  (interactive)
  
  (when (display-graphic-p)
    ;; 英文字体
    (set-face-attribute 'default nil :font "Ubuntu Mono-12")
    
    ;; 查找 Sarabun 的英文变体
    (let* ((all-fonts (font-family-list))
           (sarabun-fonts
            (cl-remove-if-not
             (lambda (font)
               (string-match "sarabun" (downcase font)))
             all-fonts)))
      
      (if sarabun-fonts
          (progn
            (message "找到 Sarabun 字体变体:")
            (dolist (font sarabun-fonts)
              (message "  📌%s" font))
            
            ;; 优先选择 Slab SC 版本
            (let ((preferred-font nil))
              (dolist (font sarabun-fonts)
                (when (string-match "slab.*sc" (downcase font))
                  (setq preferred-font font)
                  (cl-return)))
              
              ;; 如果没有 Slab SC，使用第一个
              (unless preferred-font
                (setq preferred-font (car sarabun-fonts)))
              
              ;; 设置字体
              (let ((font-spec (font-spec :family preferred-font)))
                (when font-spec
                  (dolist (charset '(han kana cjk-misc bopomofo))
                    (set-fontset-font t charset font-spec))
                  
                  (message "✅ 设置成功: %s" preferred-font)
                  
                  ;;测试未找到 Sarabun 字体尝试其他中文字体
                  (test-font-display preferred-font)))))
        
        (message "❌ 未找到 Sarabun 字体，尝试其他中文字体...")
        (try-other-chinese-fonts)))))

(setup-fonts-using-english-names)

(defun my/set-font ()
  (interactive)
  ;; sdf
  (set-face-attribute 'default nil :font "UbuntuMono" :height 120)
  (dolist (charset '(kana han cjk-misc bopomofo))
    (set-fontset-font t charset (font-spec :family "Sarasa Fixed SC" :height 120)))
  (set-fontset-font t 'emoji
                  (font-spec :family "Noto Color Emoji" :size 12))
  )
中

(my/set-font)
(set-face-attribute 'default nil :font "UbuntuMono" :height 120)

(defun get-font-xlfd (family)
  (let ((font (find-font (font-spec :family family))))
    (when font
      (font-xlfd-name font))))
(get-font-xlfd "Sarasa Fixed SC")


(set-fontset-font t 'han
		  (font-xlfd-name (find-font (font-spec :family "Sarasa Fixed SC" :size 5)))
		  )


(defun xlfd-get-family (xlfd)
  "从XLFD字符串提取family字段"
  (let* ((parts (split-string xlfd "-" t))  ; t表示忽略空字符串
         (family-index 1))                  ; XLFD中family是第2个字段（从0开始）
    (when (>= (length parts) (1+ family-index))
      (nth family-index parts))))
(font-xlfd-name (find-font (font-spec :family "Sarasa Fixed SC" :size 5)))
;; 使用示例
(xlfd-get-family "-????-Sarasa Fixed SC-ultralight-italic-normal-*-*-*-*-*-d-0-iso10646-1")
(defun my/set-font ()
  (interactive)
  ;; sdf
  (set-face-attribute 'default nil :font "Sarasa Fixed SC" :height 120)
  (dolist (charset '(kana han cjk-misc bopomofo))
    (set-fontset-font t charset (font-spec :family "Sarasa Fixed SC" :height 120)))
  (set-fontset-font t 'emoji
                  (font-spec :family "Noto Color Emoji" :size 12))
  )
(my/set-font)


