(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))

(add-to-list 'default-frame-alist '(vertical-scroll-bars . nil))
(when (fboundp 'scroll-bar-mode)
  (scroll-bar-mode -1))

(require 'package)

(setq package-archives '(("gnu"    . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
                         ("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
                         ("melpa"  . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))
(package-initialize)

(setq cyan/packages
      '(which-key
        magit
        vterm
        ace-window
        move-text
        multiple-cursors
        popper
        vertico))

(dolist (package cyan/packages)
  (unless (package-installed-p package)
    (unless package-archive-contents
      (package-refresh-contents))
    (package-install package)))

;; which-key
(require 'which-key)

(setq which-key-idle-delay 0.5
      which-key-idle-secondary-delay 0.05)

(which-key-mode 1)

;; vertico
(require 'vertico)

(setq vertico-cycle t)

(vertico-mode 1)
(savehist-mode 1)

;; magit
(global-set-key (kbd "C-c g") #'magit-status)

;; vterm
(setq vterm-always-compile-module t
      vterm-max-scrollback 20000)

(defun cyan/vterm-same-window ()
  "Open vterm in the selected window."
  (interactive)
  (let ((display-buffer-overriding-action
         '((display-buffer-same-window))))
    (vterm)))

(global-set-key (kbd "C-c v") #'cyan/vterm-same-window)

;; ace-window
(setq aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l)
      aw-scope 'frame)

(global-set-key (kbd "M-o") #'ace-window)

;; winner-mode
(winner-mode 1)

(global-set-key (kbd "C-c <left>") #'winner-undo)
(global-set-key (kbd "C-c <right>") #'winner-redo)

;; popper
(require 'popper)
(require 'popper-echo)

(setq popper-reference-buffers
      '("\\*Messages\\*"
        "Output\\*$"
        "\\*Async Shell Command\\*"
        help-mode
        compilation-mode))

(global-set-key (kbd "C-`") #'popper-toggle)
(global-set-key (kbd "M-`") #'popper-cycle)
(global-set-key (kbd "C-M-`") #'popper-toggle-type)

(popper-mode 1)
(popper-echo-mode 1)

;; move-text
(require 'move-text)

(global-set-key (kbd "M-<up>") #'move-text-up)
(global-set-key (kbd "M-<down>") #'move-text-down)

;; multiple-cursors
(require 'multiple-cursors)

;; (global-set-key (kbd "C-S-c C-S-c") #'mc/edit-lines)
(global-set-key (kbd "C->") #'mc/mark-next-like-this)
(global-set-key (kbd "C-<") #'mc/mark-previous-like-this)
;; (global-set-key (kbd "C-c C-<") #'mc/mark-all-like-this)

;; Comment current line or active region.
(global-set-key (kbd "C-;") #'comment-line)

(defun cyan/copy-file-line ()
  "Copy the absolute file path and current line or selected line range."
  (interactive)
  (unless buffer-file-name
    (user-error "Current buffer is not visiting a file"))
  (let* ((region (use-region-p))
         (start-position (if region (region-beginning) (point)))
         (region-end-position (and region (region-end)))
         (end-position
          (when region
            (if (and (> region-end-position start-position)
                     (save-excursion
                       (goto-char region-end-position)
                       (bolp)))
                (1- region-end-position)
              region-end-position)))
         (start-line (line-number-at-pos start-position))
         (end-line (and end-position (line-number-at-pos end-position)))
         (location
          (if (and end-line (/= start-line end-line))
              (format "%s:%d-%d" (expand-file-name buffer-file-name)
                      start-line end-line)
            (format "%s:%d" (expand-file-name buffer-file-name)
                    start-line))))
    (kill-new location)
    (setq deactivate-mark t)
    (message "Copied: %s" location)))

(global-set-key (kbd "C-c w") #'cyan/copy-file-line)

(defun cyan/revert-buffer-no-confirm ()
  "Revert the current buffer without confirmation."
  (interactive)
  (revert-buffer :ignore-auto :noconfirm))

(global-set-key (kbd "C-c r") #'cyan/revert-buffer-no-confirm)

(load-theme 'gruber-darker t)
