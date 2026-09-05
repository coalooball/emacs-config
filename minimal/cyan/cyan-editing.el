;;; cyan-editing.el --- Personal editing commands -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:

;; Personal configuration loaded from post-init.el.

;;; Code:

(require 'use-package)
(defun my-copy-file-path-and-line ()
  "Copy the current file's absolute path and line number to the kill ring."
  (interactive)
  (unless buffer-file-name
    (user-error "Current buffer is not visiting a file"))
  (let ((location (format "%s:%d"
                         (file-truename buffer-file-name)
                         (line-number-at-pos))))
    (kill-new location)
    (message "%s" location)))

(global-set-key (kbd "C-c c c") #'my-copy-file-path-and-line)

(defun my-mark-string ()
  "Mark the contents of the string at point, excluding its delimiters."
  (interactive)
  (let ((start (nth 8 (syntax-ppss))))
    (unless start
      (user-error "Point is not inside a string"))
    (let ((end (scan-sexps start 1)))
      (goto-char (1+ start))
      (set-mark (1- end))
      (activate-mark))))

(global-set-key (kbd "C-c c i") #'my-mark-string)

;;; VS Code-style editing

(use-package move-dup
  :bind (("M-<up>" . move-dup-move-lines-up)
         ("M-<down>" . move-dup-move-lines-down)
         ("M-S-<up>" . move-dup-duplicate-up)
         ("M-S-<down>" . move-dup-duplicate-down)))

(defun my-multiple-cursors-mark-all ()
  "Mark all occurrences of the region or the symbol at point."
  (interactive)
  (require 'multiple-cursors)
  (if (use-region-p)
      (mc/mark-all-like-this)
    (mc/mark-all-symbols-like-this)))

(use-package multiple-cursors
  :bind (("M-s-<up>" . mc/mark-previous-lines)
         ("M-s-<down>" . mc/mark-next-lines)
         ("s-d" . mc/mark-next-like-this-word)
         ("s-L" . my-multiple-cursors-mark-all)
         ("M-<mouse-1>" . mc/add-cursor-on-click))
  :init
  (setq mc/list-file
        (expand-file-name "var/multiple-cursors-lists.el"
                          user-emacs-directory))
  ;; Let Option-click reach `mc/add-cursor-on-click'.
  (global-unset-key (kbd "M-<down-mouse-1>"))
  :config
  ;; Match VS Code: Return inserts a newline and Escape exits multi-cursor mode.
  (define-key mc/keymap (kbd "<return>") nil)
  (define-key mc/keymap (kbd "<escape>") #'multiple-cursors-mode))

(provide 'cyan-editing)
;;; cyan-editing.el ends here
