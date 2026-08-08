;;; early-init.el --- Early startup settings -*- lexical-binding: t; -*-

;; Prevent Emacs from activating ELPA packages before init.el has a chance to
;; disable packages that should come from Emacs itself, such as `project'.
(setq package-enable-at-startup nil)

;;; early-init.el ends here
