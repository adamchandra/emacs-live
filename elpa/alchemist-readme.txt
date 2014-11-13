Installation:

   alchemist.el is available on both community maintained repositories - Marmalade and MELPA

   (add-to-list 'package-archives
                '("marmalade" . "http://marmalade-repo.org/packages/"))

   or

   (add-to-list 'package-archives
                '("melpa" . "http://melpa.org/packages/") t)

   M-x package-install alchemist

  Manual Installation:

   (add-to-list 'load-path "~/path/to/alchemist.el/")
   (require 'alchemist)
   (alchemist-mode 1)
