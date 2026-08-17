;;; custom-post.el --- Post-init customizations -*- lexical-binding: t; no-byte-compile: t -*-

;;; Code:

(require 'cl-lib)
(require 'seq)

;; File location
(defun my/copy-file-location ()
  "Copy the current file's absolute path and selected line range."
  (interactive)
  (if-let ((file-name (buffer-file-name (buffer-base-buffer))))
      (let* ((region-p (use-region-p))
             (begin (if region-p (region-beginning) (point)))
             (end (if region-p (region-end) (point)))
             ;; A region ending at the next line's beginning does not
             ;; include that line's contents.
             (end (if (and region-p
                           (> end begin)
                           (save-excursion
                             (goto-char end)
                             (bolp)))
                      (1- end)
                    end))
             (begin-line (line-number-at-pos begin t))
             (end-line (line-number-at-pos end t))
             (location (if (= begin-line end-line)
                           (format "%s:%d"
                                   (expand-file-name file-name)
                                   begin-line)
                         (format "%s:%d-%d"
                                 (expand-file-name file-name)
                                 begin-line
                                 end-line))))
        (kill-new location)
        (message "Copied: %s" location))
    (user-error "Current buffer is not visiting a file")))

(global-set-key (kbd "C-c y") #'my/copy-file-location)
(global-set-key (kbd "M-S-<down>") #'duplicate-dwim)

;; Edit Magit commit messages in the currently selected window.  Disabling the
;; automatic pending diff keeps it from splitting or replacing that window.
(with-eval-after-load 'magit
  (setq magit-commit-show-diff nil))

;; Syntax-highlight Magit diffs with git-delta when it is available.
;; Install the required executable on macOS with: brew install git-delta
(use-package magit-delta
  :commands magit-delta-mode
  :hook (magit-mode . my/magit-delta-mode)
  :custom
  (magit-delta-hide-plus-minus-markers nil)
  :init
  (defun my/magit-delta-mode ()
    "Enable `magit-delta-mode' when the delta executable is available."
    (when (executable-find "delta")
      (magit-delta-mode 1))))

;; Ghostel
(defvar my/ssh-command-snippets nil
  "Commands available for insertion in a Ghostel terminal.")

(setq my/ssh-command-snippets
      '(("Disk usage" . "df -h")
        ("shangqi JumpServer" . "ssh shangqi-bastion")
        ("shangqi arm" . "ssh shangqi-arm")
        ("Memory usage" . "free -h")
        ("Listening ports" . "ss -lntp")
        ("System logs" . "journalctl -xe --no-pager")))

(defun my/ghostel-insert-command ()
  "Select and insert a command into Ghostel without executing it."
  (interactive)
  (let* ((candidates
          (mapcar (lambda (snippet)
                    (cons (format "%s  [%s]" (car snippet) (cdr snippet))
                          (cdr snippet)))
                  my/ssh-command-snippets))
         (selection (completing-read "Command: " candidates nil t))
         (command (alist-get selection candidates nil nil #'string=)))
    (ghostel-paste-string command)))

(defun my/ghostel-enter-copy-mode ()
  "Enter copy mode and materialize the complete Ghostel scrollback."
  (unless (eq ghostel--input-mode 'copy)
    (ghostel-copy-mode)
    ;; Inline TUIs can leave the native scrollback ahead of the Emacs buffer.
    (when ghostel--term
      (let ((inhibit-read-only t)
            (inhibit-modification-hooks t)
            (gc-cons-threshold most-positive-fixnum))
        (ghostel--redraw ghostel--term t t)))))

(defun my/ghostel-scroll-backward ()
  "Enter copy mode and scroll backward in a Ghostel buffer."
  (interactive)
  (my/ghostel-enter-copy-mode)
  (scroll-down-command))

(defun my/ghostel-freeze-before-wheel-scroll (event &rest _)
  "Enter copy mode before scrolling a main-screen Ghostel buffer."
  (when-let* ((window (and (eventp event)
                           (posn-window (event-start event))))
              ((windowp window))
              (buffer (window-buffer window)))
    (with-selected-window window
      (with-current-buffer buffer
        (when (and (derived-mode-p 'ghostel-mode)
                   (eq ghostel--input-mode 'semi-char)
                   (not (ghostel-alt-screen-p)))
          (my/ghostel-enter-copy-mode))))))

(with-eval-after-load 'ghostel
  (setq-default ghostel-glyph-scale-floor 1.0)
  (define-key ghostel-semi-char-mode-map (kbd "C-c j")
    #'my/ghostel-insert-command)
  (define-key ghostel-semi-char-mode-map (kbd "M-v")
    #'my/ghostel-scroll-backward)
  (define-key ghostel-semi-char-mode-map (kbd "<prior>")
    #'my/ghostel-scroll-backward)
  (unless (advice-member-p #'my/ghostel-freeze-before-wheel-scroll
                           #'mwheel-scroll)
    (advice-add #'mwheel-scroll :before
                #'my/ghostel-freeze-before-wheel-scroll)))

;; Codex in Ghostel
(defvar-local my/codex-directory nil
  "Directory associated with the current Codex buffer.")

(defun my/codex-buffers ()
  "Return live Codex Ghostel buffers sorted by name."
  (sort (seq-filter
         (lambda (buffer)
           (buffer-local-value 'my/codex-ghostel-mode buffer))
         (buffer-list))
        (lambda (a b)
          (string< (buffer-name a) (buffer-name b)))))

(defun my/codex-display-buffer (buffer)
  "Display BUFFER in the selected window, even when it is dedicated."
  (let ((window (selected-window)))
    (when (window-dedicated-p window)
      (set-window-dedicated-p window nil))
    (set-window-buffer window buffer)
    (select-window window)
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

(defun codex (directory)
  "Run a new Codex process in DIRECTORY inside Ghostel.

Each invocation creates a separate buffer and process.  When the default
buffer name is already in use, Emacs adds a unique suffix such as `<2>'."
  (interactive
   (list (read-directory-name "Codex directory: " default-directory nil t)))
  (require 'ghostel)
  (let* ((directory (file-name-as-directory (expand-file-name directory)))
         (directory-name (file-name-nondirectory (directory-file-name directory)))
         (buffer-name (format "%s[codex]" directory-name))
         (program (executable-find "codex")))
    (when (file-remote-p directory)
      (user-error "Codex directory must be local"))
    (unless program
      (user-error "Cannot find the codex executable"))
    (let ((buffer (generate-new-buffer buffer-name)))
      (condition-case err
          (progn
            (with-current-buffer buffer
              (setq default-directory directory)
              (ghostel-mode)
              (setq-local ghostel-buffer-name-function nil)
              (setq-local my/codex-directory directory))
            (my/codex-display-buffer buffer)
            (ghostel-exec buffer program '("--no-alt-screen"))
            (with-current-buffer buffer
              (my/codex-ghostel-mode 1))
            buffer)
        ((error quit)
         (when (buffer-live-p buffer)
           (kill-buffer buffer))
         (signal (car err) (cdr err)))))))

(provide 'custom-post)

;;; custom-post.el ends here
