;;windows only stuff
(progn
  (setq cygwin-bin "c:\\cygwin64\\bin")
  ;;(setq gnu-bin "C:\\apps\\GnuWin32\\gnuwin32\\bin")
  (setenv "PATH"
	  (concat cygwin-bin ";" (getenv "PATH")))
  (add-to-list 'exec-path cygwin-bin)
)

(provide 'init-cygwin)
