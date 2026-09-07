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
  "Mark contents inside quotes, brackets, or spaces at point.
Prefer a syntactic string, then the innermost pair of (), [] or {}.
Otherwise select non-whitespace text surrounded by literal spaces on
the same line.  Exclude the delimiters from the selection."
  (interactive)
  (let ((table (copy-syntax-table (syntax-table)))
        bounds)
    ;; Recognize all three bracket pairs even in text-oriented modes.
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    (setq bounds
          (save-excursion
            (with-syntax-table table
              (let* ((state (save-excursion
                              (parse-partial-sexp (point-min) (point))))
                     (start (cond
                             ((nth 3 state) (nth 8 state))
                             ((nth 4 state) nil)
                             ((memq (char-after) '(?\( ?\[ ?\{))
                              (point))
                             ((and (nth 1 state)
                                   (memq (char-after (nth 1 state))
                                         '(?\( ?\[ ?\{)))
                              (nth 1 state)))))
                (if start
                    (let ((end (condition-case nil
                                   (scan-sexps start 1)
                                 (scan-error nil))))
                      (when end
                        (cons (1+ start) (1- end))))
                  (skip-chars-backward "^ \t\r\n" (line-beginning-position))
                  (let ((start (point)))
                    (skip-chars-forward "^ \t\r\n" (line-end-position))
                    (when (and (< start (point))
                               (eq (char-before start) ?\s)
                               (eq (char-after) ?\s))
                      (cons start (point)))))))))
    (unless bounds
      (user-error "No enclosing string, brackets, or spaces at point"))
    (goto-char (car bounds))
    (set-mark (cdr bounds))
    (activate-mark)))

(global-set-key (kbd "C-c c i") #'my-mark-string)

(global-set-key (kbd "C-c c o") #'set-mark-command)

(defun my-shift-lines (columns)
  "Shift the current line or active region's lines by COLUMNS.
Include whole lines, excluding a line whose beginning ends the region.
Keep the region active and never reduce indentation below zero."
  (let* ((region-active (use-region-p))
         (start (if region-active (region-beginning) (point)))
         (end (if region-active (region-end) (line-end-position))))
    (save-excursion
      (goto-char end)
      (when (and region-active (> end start) (bolp))
        (backward-char))
      (let ((last-line (copy-marker (line-beginning-position))))
        (unwind-protect
            (progn
              (goto-char start)
              (beginning-of-line)
              (let ((indent-tabs-mode nil)
                    (more-lines t))
                (while (and more-lines (<= (point) last-line))
                  (indent-line-to (max 0 (+ (current-indentation) columns)))
                  (setq more-lines (= (forward-line 1) 0)))))
          (set-marker last-line nil))))
    (when region-active
      (setq deactivate-mark nil))))

(defun my-shift-lines-left ()
  "Shift the current line or selected lines left by two columns."
  (interactive)
  (my-shift-lines -2))

(defun my-shift-lines-right ()
  "Shift the current line or selected lines right by two columns."
  (interactive)
  (my-shift-lines 2))

(global-set-key (kbd "C-c c b") #'my-shift-lines-left)
(global-set-key (kbd "C-c c f") #'my-shift-lines-right)

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
