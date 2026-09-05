;;; cyan-terminal.el --- Ghostel terminal integration -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:

;; Personal configuration loaded from post-init.el.

;;; Code:

(require 'use-package)
(require 'cyan-workspaces)

;;; Terminal

(setq ghostel-module-directory
      (expand-file-name "var/ghostel/" user-emacs-directory)
      ghostel-module-auto-install 'download)

(defun my/tabspaces-project-root ()
  "Return the project root associated with the current tabspace, or nil."
  (when (and (bound-and-true-p tabspaces-mode)
             (fboundp 'tabspaces--current-tab-name)
             (fboundp 'tabspaces--get-project-for-tab))
    (when-let ((root (tabspaces--get-project-for-tab
                      (tabspaces--current-tab-name))))
      (file-name-as-directory (expand-file-name root)))))

(defun my/read-terminal-directory (prompt)
  "Read a terminal DIRECTORY with PROMPT."
  (read-directory-name prompt default-directory nil t))

(defvar-local my/ghostel-project-root nil
  "Project root associated with the current Ghostel buffer.")

(defvar-local my/ghostel-tab-name nil
  "Tabspace that owns the current Ghostel buffer.")

(defun my/ghostel-display-buffer (buffer)
  "Display BUFFER and register it in the current tabspace."
  (let ((window (selected-window)))
    (when (window-dedicated-p window)
      (set-window-dedicated-p window nil))
    (with-selected-window window
      ;; `switch-to-buffer' updates tabspaces' frame-local buffer list;
      ;; `pop-to-buffer' alone does not reliably do so for a new terminal.
      (switch-to-buffer buffer))
    buffer))

(defun my/ghostel ()
  "Start a fresh Ghostel buffer for the current tabspace or chosen directory."
  (interactive)
  (require 'ghostel)
  (let* ((project-root (my/tabspaces-project-root))
         (directory (or project-root
                        (my/read-terminal-directory "Ghostel directory: ")))
         (buffer (if project-root
                     ;; Non-numeric t asks Ghostel for a new project instance.
                     (let ((default-directory project-root))
                       (ghostel-project t))
                   ;; Keep the default workspace usable even when it has no
                   ;; project association.
                   (let ((default-directory directory))
                     (ghostel t)))))
    (with-current-buffer buffer
      (setq-local my/ghostel-project-root project-root)
      (setq-local my/ghostel-tab-name
                  (when (fboundp 'tabspaces--current-tab-name)
                    (tabspaces--current-tab-name))))
    (my/ghostel-display-buffer buffer)
    buffer))

(use-package ghostel
  :commands (my/ghostel
             ghostel
             ghostel-project
             ghostel-project-list-buffers)
  :bind (("C-c t" . my/ghostel)
         :map project-prefix-map
         ("m" . ghostel-project)
         ("M" . ghostel-project-list-buffers))
  :init
  ;; Keep CJK fallback glyphs at their natural size instead of shrinking them
  ;; to Ghostel's strict terminal grid.
  (setq-default ghostel-glyph-scale-floor 1.0)
  ;; Keep high-volume terminal output from materializing an oversized
  ;; text-property buffer in Emacs.  Codex uses the alternate screen below,
  ;; but this cap also protects regular Ghostel terminals.
  (setq ghostel-max-scrollback (* 1 1024 1024))
  (with-eval-after-load 'project
    (add-to-list 'project-switch-commands
                 '(ghostel-project "Ghostel") t)
    (add-to-list 'project-switch-commands
                 '(ghostel-project-list-buffers "Ghostel buffers") t)))

(provide 'cyan-terminal)
;;; cyan-terminal.el ends here
