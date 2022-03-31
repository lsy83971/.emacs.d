;;windows only stuff
(progn
  (setq cygwin-bin "c:\\cygwin64\\bin")
  ;;(setq gnu-bin "C:\\apps\\GnuWin32\\gnuwin32\\bin")
  (setenv "PATH"
  ;;(concat cygwin-bin ";" gnu-bin ";")
  (concat cygwin-bin ";" (getenv "PATH")))
  (setq exec-path
	'(cygwin-bin gnu-bin)))

(provide 'init-cygwin)
