;;; cyan-codex.el --- Codex terminal commands -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:

;; Personal configuration loaded from post-init.el.

;;; Code:

(require 'use-package)
(require 'cl-lib)
(require 'seq)
(require 'cyan-terminal)

;;; Codex in Ghostel

(defvar-local my/codex-directory nil
  "Directory associated with the current Codex buffer.")

(defvar-local my/codex-project-root nil
  "Project root associated with the current Codex buffer.")

(defvar-local my/codex-tab-name nil
  "Tabspace that owns the current Codex buffer.")

(defun my/codex-disable-auto-composition ()
  "Disable expensive text shaping and bidi scans in the current Codex buffer.

Ghostel materializes the terminal screen as a large text-property buffer.
On macOS, automatic CJK composition makes redisplay walk composition
properties across that whole buffer after each IME edit; this becomes
pathologically slow after `/resume' loads a long Codex transcript.  Ghostel's
native renderer still displays the UTF-8 text when these Emacs redisplay
features are disabled."
  (when (fboundp 'auto-composition-mode)
    (auto-composition-mode -1))
  (setq-local auto-composition-mode nil
              ;; `nil' is not a valid value here: M-x completion calls
              ;; `find-automatic-composition' and Emacs can crash on it.
              ;; An empty table disables automatic composition safely while
              ;; retaining the normal global table everywhere else.
              composition-function-table
              (make-char-table 'composition-function-table))
  ;; Codex is an LTR terminal UI.  Avoid rescanning the entire transcript for
  ;; bidirectional paragraph resolution after each composed CJK character.
  (setq-local bidi-display-reordering nil
              bidi-paragraph-direction 'left-to-right)
  ;; Remove properties already created before this setting took effect.
  (remove-list-of-text-properties (point-min) (point-max) '(composition)))

(defun my/codex-ghostel-performance-setup ()
  "Apply Codex-only redisplay safeguards as soon as Ghostel starts."
  (when (string-match-p "\\[codex\\]" (buffer-name))
    (my/codex-disable-auto-composition)))

(add-hook 'ghostel-mode-hook #'my/codex-ghostel-performance-setup)

(defun my/codex-buffers ()
  "Return live Codex buffers from the current tabspace, sorted by name."
  (let ((buffers (if (and (bound-and-true-p tabspaces-mode)
                         (fboundp 'tabspaces--buffer-list))
                    (tabspaces--buffer-list)
                  (buffer-list))))
    (sort (seq-filter
           (lambda (buffer)
             (buffer-local-value 'my/codex-ghostel-mode buffer))
           buffers)
          (lambda (a b)
            (string< (buffer-name a) (buffer-name b))))))

(defun my/codex-display-buffer (buffer)
  "Display BUFFER in the selected window and keep it in the current tabspace."
  (let ((window (selected-window)))
    (when (window-dedicated-p window)
      (set-window-dedicated-p window nil))
    (with-selected-window window
      ;; `switch-to-buffer' updates tabspaces' frame-local buffer list;
      ;; `set-window-buffer' alone would leave BUFFER outside the workspace.
      (switch-to-buffer buffer))
    buffer))

(defun my/codex-cycle-buffer (direction)
  "Switch to another Codex buffer in DIRECTION, wrapping at the ends."
  (let* ((buffers (my/codex-buffers))
         (count (length buffers))
         (index (cl-position (current-buffer) buffers))
         (target (cond
                  ((zerop count) nil)
                  ((null index) (if (> direction 0)
                                    (car buffers)
                                  (car (last buffers))))
                  (t (nth (mod (+ index direction) count) buffers)))))
    (cond
     ((null target)
      (user-error "No Codex buffers"))
     ((and (= count 1) (eq target (current-buffer)))
      (message "Only one Codex buffer"))
     (t
      (my/codex-display-buffer target)))))

(defun my/codex-next-buffer ()
  "Switch to the next Codex buffer."
  (interactive)
  (my/codex-cycle-buffer 1))

(defun my/codex-previous-buffer ()
  "Switch to the previous Codex buffer."
  (interactive)
  (my/codex-cycle-buffer -1))

(defvar my/codex-ghostel-mode-map
  (make-sparse-keymap)
  "Keymap active in Codex Ghostel buffers.")

;; Rebind explicitly so reloading this file updates existing Codex buffers.
(define-key my/codex-ghostel-mode-map (kbd "C-n") nil)
(define-key my/codex-ghostel-mode-map (kbd "C-p") nil)
(define-key my/codex-ghostel-mode-map (kbd "M-n") #'my/codex-next-buffer)
(define-key my/codex-ghostel-mode-map (kbd "M-p") #'my/codex-previous-buffer)

(define-minor-mode my/codex-ghostel-mode
  "Minor mode for a Codex process running inside Ghostel."
  :lighter " Codex"
  :keymap my/codex-ghostel-mode-map)

;; Also repair an already-running Codex buffer when this file is re-evaluated.
(dolist (buffer (buffer-list))
  (when (and (buffer-live-p buffer)
             (buffer-local-value 'my/codex-ghostel-mode buffer))
    (with-current-buffer buffer
      (my/codex-disable-auto-composition))))

(defun my/codex-executable ()
  "Return the Codex executable, including installations under NVM."
  (or (executable-find "codex")
      (car (last
            (sort
             (seq-filter
              #'file-executable-p
              (file-expand-wildcards
               (expand-file-name "~/.nvm/versions/node/v*/bin/codex")))
             #'string<)))))

(defcustom my/codex-terminal-backend 'ghostel
  "Terminal backend used by `codex'.

The built-in `term' backend is the default because Ghostel materializes
terminal cells as text properties; long Codex `/resume' transcripts can make
macOS CJK composition and redisplay pathologically expensive there.  Set this
to `ghostel' to opt back into the Ghostel renderer."
  :type '(choice (const :tag "Built-in term" term)
                 (const :tag "Ghostel" ghostel)))

(defun codex (&optional directory)
  "Run a new Codex process in DIRECTORY inside Ghostel.

When DIRECTORY is nil, use the current tabspace project root.  If the
tabspace has no project, prompt for a directory.

Each invocation creates a separate buffer and process.  When the default
buffer name is already in use, Emacs adds a unique suffix such as `<2>'."
  (interactive
   (list nil))
  (when (eq my/codex-terminal-backend 'ghostel)
    (require 'ghostel))
  (let* ((tab-project-root (my/tabspaces-project-root))
         (directory (file-name-as-directory
                     (expand-file-name
                      (or directory
                          tab-project-root
                          (my/read-terminal-directory "Codex directory: ")))))
         (directory-name (file-name-nondirectory (directory-file-name directory)))
         (buffer-name (format "%s[codex]" directory-name))
         (program (my/codex-executable))
         (tab-name (when (fboundp 'tabspaces--current-tab-name)
                     (tabspaces--current-tab-name)))
         (project-root
          (unless (file-remote-p directory)
            (when-let ((project (project-current nil directory)))
              (file-name-as-directory
               (expand-file-name (project-root project)))))))
    (when (file-remote-p directory)
      (user-error "Codex directory must be local"))
    (when (and tab-project-root
               (not (and (file-in-directory-p directory tab-project-root)
                         (or (null project-root)
                             (file-equal-p project-root tab-project-root)))))
      (user-error "Codex directory does not belong to the current project workspace"))
    (unless program
      (user-error "Cannot find the codex executable"))
    (let ((buffer (generate-new-buffer buffer-name))
          (process-environment (copy-sequence process-environment)))
      ;; The npm launcher uses `#!/usr/bin/env node', so make its NVM directory
      ;; visible only to this Codex child process.
      (setenv "PATH"
              (concat (file-name-directory program)
                      path-separator
                      (or (getenv "PATH") "")))
      (condition-case err
          (progn
            (with-current-buffer buffer
              (setq default-directory directory)
              (if (eq my/codex-terminal-backend 'ghostel)
                  (progn
                    (ghostel-mode)
                    (setq-local ghostel-buffer-name-function nil
                                ghostel-max-scrollback (* 256 1024)))
                (require 'term)
                (term-mode)))
            (with-current-buffer buffer
              (setq-local my/codex-directory directory)
              (setq-local my/codex-project-root
                          (or project-root tab-project-root))
              (setq-local my/codex-tab-name tab-name))
            (my/codex-display-buffer buffer)
            (if (eq my/codex-terminal-backend 'ghostel)
                ;; Keep Codex on Ghostel's alternate screen.  `--no-alt-screen'
                ;; makes Codex preserve every TUI repaint in terminal scrollback.
                (ghostel-exec buffer program nil)
              ;; `term' does not attach Ghostel's per-cell display properties,
              ;; so CJK input is composed without rescanning the transcript.
                (term-exec buffer (buffer-name buffer) program nil nil)
              (term-char-mode))
            (with-current-buffer buffer
              (when (eq my/codex-terminal-backend 'ghostel)
                ;; Codex owns its transcript/history.  Do not mirror it into
                ;; Ghostel's Emacs text buffer, where CJK redisplay becomes
                ;; quadratic after `/resume'.
                (setq-local ghostel-max-scrollback (* 256 1024)))
              (my/codex-disable-auto-composition)
              (when (eq my/codex-terminal-backend 'ghostel)
                ;; Handle Quail/Emacs Lisp IME commits through Ghostel's
                ;; composition-aware forwarding path when available.
                (require 'ghostel-ime)
                (ghostel-ime-mode 1))
              (my/codex-ghostel-mode 1))
            buffer)
        ((error quit)
         (when (buffer-live-p buffer)
           (kill-buffer buffer))
         (signal (car err) (cdr err)))))))

(provide 'cyan-codex)
;;; cyan-codex.el ends here
