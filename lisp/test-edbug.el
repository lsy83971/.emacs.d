(defun gg3 (sb) (message sb))

(defun paste (a)
  (message a)
  (gg3 a)
  (message (concat a "asdf"))
  (setq b (+ 10 (* 10 20)))
  )

(paste "asdf")  




eval region
C-u 
important:eval-region
let edebug knows how to find each function definition

edebug-all-defs


inside edebug
spc n
t T g G
c C
i I
evaluation: e *** M-: *** C-x C-e ***

enter point
C-M-x


The current Edebug execution mode determines how far Edebug continues execution before stopping


I
debug-on-error

elpy-rpc--default-error-callback((process-sentinel "exited abnormally with code 1"))
  elpy-promise-reject([*elpy-promise* #f(compiled-function (result) #<bytecode 0x2f49871>) elpy-rpc--default-error-callback #<buffer  *elpy-rpc [project:~/.emacs.d/elpa/elpy-20220322.41/ environment:c:/]*> nil] (process-sentinel "exited abnormally with code 1"))
  #f(compiled-function (call-id promise) #<bytecode 0x2ff02a1>)(1 [*elpy-promise* #f(compiled-function (result) #<bytecode 0x2f49871>) elpy-rpc--default-error-callback #<buffer  *elpy-rpc [project:~/.emacs.d/elpa/elpy-20220322.41/ environment:c:/]*> nil])
  maphash(#f(compiled-function (call-id promise) #<bytecode 0x2ff02a1>) #<hash-table equal 2/65 0x2fe8179>)
elpy-rpc--sentinel(#<process  *elpy-rpc [project:~/.emacs.d/elpa/elpy-20220322.41/ environment:c:/]*> "exited abnormally with code 1\n")


([*elpy-promise* #f(compiled-function (result) #<bytecode 0x2f49871>) elpy-rpc--default-error-callback #<buffer  *elpy-rpc [project:~/.emacs.d/elpa/elpy-20220322.41/ environment:c:/]*> nil] (process-sentinel "exited abnormally with code 1"))
#f(compiled-function (call-id promise) #<bytecode 0x2ff02a1>)
(1 [*elpy-promise* #f(compiled-function (result) #<bytecode 0x2f49871>) elpy-rpc--default-error-callback #<buffer  *elpy-rpc [project:~/.emacs.d/elpa/elpy-20220322.41/ environment:c:/]*> nil])

process-sentinel

elpy-rpc--backend-callbacks

(type-of lsy-tmp1)

lsy-tmp1

#s(hash-table size 65 test equal rehash-size 1.5 rehash-threshold 0.8125 data (1 [*elpy-promise* #[257 "ÁA" [elpy-rpc--jedi-available jedi_available] 3 "

(fn RESULT)"] elpy-rpc--default-error-callback #<buffer  *elpy-rpc [project:~/.emacs.d/elpa/elpy-20220322.41/ environment:c:/]*> t] 2 [*elpy-promise* #[257 ";	 À!ÂAÃE ÄAÅAÆA0 Ç8ÈÉ# ¶ÇÈÊ#ËÌÍÎÏ##À!¶ÂAÐ^ ÄAÑAÀÒÓÊ%	u Ô t ÕÖÇË×\"ÈÊ#P!ÕØ!" [#[385 "ÂÃ\"ÂÄ\"/ ÅÆÇÈÉ#\"²ÊË\"& ÅÌ#- ÍÎ\")²Ï!" [emacs-version eldoc-echo-area-use-multiline-p plist-get :thing :face format "%s: " propertize face font-lock-function-name-face version<= "25" ...] 10 "

(fn DOC &rest PLIST)"] elpy-eldoc-show-current-function kind "calltip" name index params propertize face eldoc-highlight-function-argument font-lock-function-name-face format ...] 12 "

(fn INFO)"] elpy-rpc--default-error-callback #<buffer rpc.py> nil] ...))


(type-of lsy-tmp1)


(maphash (lambda (x y) (message (format "%s" x))) lsy-tmp1)


(setq a '())
(maphash (lambda (x y) (setq a (cons y a))) lsy-tmp1)
(type-of (car a))

(length (elt a 1))


(length (elt a 0) )
(elt (elt a 0) 0)
(elt (elt a 0) 5)

(length a)




(setq library-root "~/.emacs.d/elpa/elpy-20220322.41/" python-command "pythonw")
(elpy-rpc--open library-root python-command)


(defmacro with-elpy-rpc-virtualenv-activated (&rest body)
  "Run BODY with Elpy's RPC virtualenv activated.

During the execution of BODY the following variables are available:
- `current-environment': current environment path.
- `current-environment-binaries': current environment python binaries path.
- `current-environment-is-deactivated': non-nil if the current
  environment has been deactivated (it is not if the RPC environment and
  the current environment are the same)."
  `(if (not (executable-find elpy-rpc-python-command))
       (error "Cannot find executable '%s', please set 'elpy-rpc-python-command' to an existing executable." elpy-rpc-python-command)
     (let* ((pyvenv-post-activate-hooks (remq 'elpy-rpc--disconnect
                                              pyvenv-post-activate-hooks))
            (pyvenv-post-deactivate-hooks (remq 'elpy-rpc--disconnect
                                                pyvenv-post-deactivate-hooks))
            (venv-was-activated pyvenv-virtual-env)
            (current-environment-binaries (executable-find
                                           elpy-rpc-python-command))
            (current-environment (directory-file-name (file-name-directory (directory-file-name (file-name-directory current-environment-binaries)))))
            ;; No need to change of venv if they are the same
            (same-venv (or (string= current-environment
                                    (elpy-rpc-get-virtualenv-path))
                           (file-equal-p current-environment
                                         (elpy-rpc-get-virtualenv-path))))
            current-environment-is-deactivated)
       ;; If different than the current one, try to activate the RPC virtualenv
       (unless same-venv
         (condition-case err
             (pyvenv-activate (elpy-rpc-get-or-create-virtualenv))
           ((error quit) (if venv-was-activated
                             (pyvenv-activate venv-was-activated)
                           (pyvenv-deactivate))))
         (setq current-environment-is-deactivated t))
       (let (venv-err result)
         ;; Run BODY and catch errors and quit to avoid keeping the RPC
         ;; virtualenv activated
           (condition-case err
               (setq result (progn ,@body))
             (error (setq venv-err
                          (if (stringp err)
                              err
                            (car (cdr err)))))
             (quit nil))
         ;; Reactivate the previous environment if necessary
         (unless same-venv
           (if venv-was-activated
               (pyvenv-activate venv-was-activated)
             (pyvenv-deactivate)))
         ;; Raise errors that could have happened in BODY
         (when venv-err
           (error venv-err))
         result))))

(defun elpy-rpc--open (library-root python-command)
 "Start a new RPC process and return the associated buffer."
  (elpy-rpc--cleanup-buffers)
  (with-elpy-rpc-virtualenv-activated
   (gg)
   ))



(defun gg ()
    (let* ((full-python-command (executable-find python-command))
          (name (format " *elpy-rpc [project:%s environment:%s]*"
                        library-root
                        current-environment))
          (new-elpy-rpc-buffer (generate-new-buffer name))
          (proc nil))
     (unless full-python-command
       (error "Can't find Python command, configure `elpy-rpc-python-command'"))
     (with-current-buffer new-elpy-rpc-buffer
       (setq elpy-rpc--buffer-p t
             elpy-rpc--buffer (current-buffer)
             elpy-rpc--backend-library-root library-root
             elpy-rpc--backend-python-command full-python-command
             default-directory "/"
             proc (condition-case err
                      (let ((process-connection-type nil)
                            (process-environment (elpy-rpc--environment)))
                        (start-process name
                                       (current-buffer)
                                       full-python-command
                                       "-W" "ignore"
                                       "-m" "elpy.__main__"))
                    (error
                     (elpy-config-error
                      "Elpy can't start Python (%s: %s)"
                      (car err) (cadr err)))))
       (set-process-query-on-exit-flag proc nil)
       (set-process-sentinel proc #'elpy-rpc--sentinel)
       (set-process-filter proc #'elpy-rpc--filter)
       (elpy-rpc-init library-root
                      (when current-environment-is-deactivated
                        current-environment-binaries)
                      (lambda (result)
                        (setq elpy-rpc--jedi-available
                              (cdr (assq 'jedi_available result))))))
     new-elpy-rpc-buffer)
  )


(defun executable-find (command &optional remote)
  "Search for COMMAND in `exec-path' and return the absolute file name.
Return nil if COMMAND is not found anywhere in `exec-path'.  If
REMOTE is non-nil, search on the remote host indicated by
`default-directory' instead."
  (if (and remote (file-remote-p default-directory))
      (let ((res (locate-file
	          command
	          (mapcar
	           (lambda (x) (concat (file-remote-p default-directory) x))
	           (exec-path))
	          exec-suffixes 'file-executable-p)))
        (when (stringp res) (file-local-name res)))
    ;; Use 1 rather than file-executable-p to better match the
    ;; behavior of call-process.
    (let ((default-directory (file-name-quote default-directory 'top)))
      (locate-file command exec-path exec-suffixes 1))))
