;ielm
(setq a '(c b))
(dolist (s a) (print "aa"))


(defvar my-ticker nil)
(let ((x 0))             ; x is lexically bound.
  (setq my-ticker (lambda ()
                    (setq x (1+ x)))))


(funcall my-ticker)


(setq lexical-binding nil)

(defcustom elpy-modules '(elpy-module-sane-defaults
                          elpy-module-company
                          elpy-module-eldoc
                          elpy-module-flymake
                          elpy-module-highlight-indentation
                          elpy-module-pyvenv
                          elpy-module-yasnippet
                          elpy-module-django)
  "Which Elpy modules to use.

Elpy can use a number of modules for additional features, which
can be inidividually enabled or disabled."
  :type '(set (const :tag "Inline code completion (company-mode)"
                     elpy-module-company)
              (const :tag "Show function signatures (ElDoc)"
                     elpy-module-eldoc)
              (const :tag "Highlight syntax errors (Flymake)"
                     elpy-module-flymake)
              (const :tag "Code folding"
                     elpy-module-folding)
              (const :tag "Show the virtualenv in the mode line (pyvenv)"
                     elpy-module-pyvenv)
              (const :tag "Display indentation markers (highlight-indentation)"
                     elpy-module-highlight-indentation)
              (const :tag "Expand code snippets (YASnippet)"
                     elpy-module-yasnippet)
              (const :tag "Django configurations (Elpy-Django)"
                     elpy-module-django)
              (const :tag "Automatically update documentation (Autodoc)."
                     elpy-module-autodoc)
              (const :tag "Configure some sane defaults for Emacs"
                     elpy-module-sane-defaults))
  :group 'elpy)


company-backends
(company-bbdb company-semantic company-cmake company-capf company-clang company-files (company-dabbrev-code company-gtags company-etags company-keywords) company-oddmuse company-dabbrev)

(defun soso (regex)
  (message "asdf")
  (message "asdf1")
  )

(soso 1)

;; name
;; " *elpy-rpc [project:~/.emacs.d/elpa/elpy-20220322...."

;; full-python-command
;; "c:/Users/48944/.emacs.d/elpy/rpc-venv/Scripts/pyth..."
