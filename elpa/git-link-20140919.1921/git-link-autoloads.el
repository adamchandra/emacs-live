;;; git-link-autoloads.el --- automatically extracted autoloads
;;
;;; Code:


;;;### (autoloads (git-link-commit git-link) "git-link" "git-link.el"
;;;;;;  (21548 10740 436044 966000))
;;; Generated autoloads from git-link.el

(autoload 'git-link "git-link" "\
Create a URL representing the current buffer's location in its
GitHub/Bitbucket/Gitorious/... repository at the current line number
or active region. The URL will be added to the kill ring.

With a prefix argument prompt for the remote's name.
Defaults to \"origin\".

\(fn &optional PROMPT)" t nil)

(autoload 'git-link-commit "git-link" "\
Create a URL representing the commit for the hash under point
in the current buffer's GitHub/Bitbucket/Gitorious/...
repository. The URL will be added to the kill ring.

With a prefix argument prompt for the remote's name.
Defaults to \"origin\".

\(fn &optional PROMPT)" t nil)

;;;***

;;;### (autoloads nil nil ("git-link-pkg.el") (21548 10740 451977
;;;;;;  298000))

;;;***

(provide 'git-link-autoloads)
;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; coding: utf-8
;; End:
;;; git-link-autoloads.el ends here
