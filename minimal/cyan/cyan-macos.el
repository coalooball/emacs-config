;;; cyan-macos.el --- macOS window handling -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:

;; Personal configuration loaded from post-init.el.

;;; Code:

(require 'use-package)
;; GNU Emacs 30's macOS NS port can lose its event-loop wakeup while deleting
;; a native frame.  Keep workspace operations inside one native frame and
;; iconify any extra frames instead of deleting them.  Use Command-Q to exit.
(when (eq system-type 'darwin)
  (defun my-macos-iconify-frame (&optional frame)
    "Iconify FRAME instead of deleting it through the macOS NS port."
    (interactive)
    (iconify-frame frame))

  (defun my-macos-handle-delete-frame (event)
    "Handle macOS close EVENT without deleting its native frame."
    (interactive "e")
    (let ((frame (posn-window (event-start event))))
      (when (frame-live-p frame)
        (iconify-frame frame))))

  (global-set-key (kbd "s-n") #'tab-bar-new-tab)
  (global-set-key (kbd "s-w") #'tab-bar-close-tab)
  (global-set-key (kbd "C-x 5 2") #'tab-bar-new-tab)
  (global-set-key (kbd "C-x 5 0") #'my-macos-iconify-frame)
  (global-set-key [ns-new-frame] #'tab-bar-new-tab)
  (define-key special-event-map [delete-frame]
              #'my-macos-handle-delete-frame))

(provide 'cyan-macos)
;;; cyan-macos.el ends here
