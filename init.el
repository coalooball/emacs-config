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

(require 'use-package)
(setq use-package-always-ensure t)

;; which-key
(use-package which-key ; Displays available key bindings in a popup.
  :custom
  (which-key-idle-delay 0.5)
  (which-key-idle-secondary-delay 0.05)
  :config
  (which-key-mode 1))

;; vertico
(use-package vertico ; Provides a vertical minibuffer completion interface.
  :custom
  (vertico-cycle t)
  :config
  (vertico-mode 1)
  (savehist-mode 1))

;; magit
(use-package magit ; Provides a full Git interface inside Emacs.
  :bind ("C-c g" . magit-status))

;; vterm
(defun cyan/current-project-root ()
  "Return the Projectile root for the current file or directory."
  (let ((start-directory (if buffer-file-name
                             (file-name-directory buffer-file-name)
                           default-directory)))
    (file-name-as-directory
     (or (projectile-project-root start-directory)
         start-directory))))

(defvar cyan/vterm-popup-buffers nil
  "Project vterm popup buffers in creation order.")

(defvar cyan/vterm-regular-buffers nil
  "Project vterm regular-window buffers in creation order.")

(defvar-local cyan/vterm-session-type nil
  "Window group used when cycling project vterm buffers.")

(defvar-local cyan/vterm-directory-tracking-enabled nil
  "Whether shell-side vterm directory tracking has been enabled.")

(defun cyan/vterm-buffer-list-variable ()
  "Return the buffer-list variable for the current vterm session."
  (pcase cyan/vterm-session-type
    ('popup 'cyan/vterm-popup-buffers)
    ('regular 'cyan/vterm-regular-buffers)
    (_ (user-error "Current buffer is not a managed project vterm"))))

(defun cyan/vterm-cycle-buffer (step)
  "Switch STEP positions through vterms in the current window group."
  (let* ((list-variable (cyan/vterm-buffer-list-variable))
         (buffers (seq-filter #'buffer-live-p
                              (symbol-value list-variable)))
         (count (length buffers)))
    (set list-variable buffers)
    (cond
     ((zerop count)
      (user-error "No vterm buffers in this window group"))
     ((= count 1)
      (message "Only one vterm buffer in this window group"))
     (t
      (let* ((current-index
              (or (seq-position buffers (current-buffer)) 0))
             (next-index (mod (+ current-index step) count)))
        (switch-to-buffer (nth next-index buffers)))))))

(defun cyan/vterm-next-buffer ()
  "Switch to the next project vterm buffer."
  (interactive)
  (cyan/vterm-cycle-buffer 1))

(defun cyan/vterm-previous-buffer ()
  "Switch to the previous project vterm buffer."
  (interactive)
  (cyan/vterm-cycle-buffer -1))

(defvar-keymap cyan/vterm-session-mode-map
  :doc "Keymap used by project vterm sessions."
  "M-n" #'cyan/vterm-next-buffer
  "M-p" #'cyan/vterm-previous-buffer)

(define-minor-mode cyan/vterm-session-mode
  "Enable navigation between project vterm sessions."
  :init-value nil
  :lighter nil
  :keymap cyan/vterm-session-mode-map)

(defun cyan/rename-vterm-for-current-directory (&rest _)
  "Rename the managed vterm buffer for its current directory."
  (when cyan/vterm-session-type
    (let* ((directory
            (directory-file-name
             (file-local-name (expand-file-name default-directory))))
           (directory-name (file-name-nondirectory directory))
           (display-name (if (string= directory-name "")
                             directory
                           directory-name))
           (suffix (pcase cyan/vterm-session-type
                     ('popup "vterm")
                     ('regular "vterm-regular"))))
      (when suffix
        (rename-buffer (format "%s[%s]" display-name suffix) t)))))

(defun cyan/vterm-enable-directory-tracking ()
  "Load vterm's directory tracking integration for a local zsh."
  (when (and (not cyan/vterm-directory-tracking-enabled)
             (not (file-remote-p default-directory))
             (string-match-p "\\(?:^\\|/\\)zsh\\(?:[[:space:]]\\|$\\)"
                             vterm-shell))
    (let* ((vterm-directory (file-name-directory (locate-library "vterm")))
           (script (expand-file-name "etc/emacs-vterm-zsh.sh"
                                     vterm-directory)))
      (when (file-readable-p script)
        (vterm-send-string
         (format "source %s; clear" (shell-quote-argument script)))
        (vterm-send-return)
        (setq-local cyan/vterm-directory-tracking-enabled t)))))

(defun cyan/register-vterm-buffer (buffer session-type)
  "Register BUFFER as a project vterm of SESSION-TYPE."
  (unless (memq session-type '(popup regular))
    (error "Invalid vterm session type: %S" session-type))
  (with-current-buffer buffer
    (setq-local cyan/vterm-session-type session-type)
    (cyan/vterm-session-mode 1)
    (cyan/rename-vterm-for-current-directory))
  (setq cyan/vterm-popup-buffers
        (delq buffer (seq-filter #'buffer-live-p
                                 cyan/vterm-popup-buffers))
        cyan/vterm-regular-buffers
        (delq buffer (seq-filter #'buffer-live-p
                                 cyan/vterm-regular-buffers)))
  (let ((list-variable (if (eq session-type 'popup)
                           'cyan/vterm-popup-buffers
                         'cyan/vterm-regular-buffers)))
    (set list-variable (append (symbol-value list-variable) (list buffer)))))

(defun cyan/vterm-project-popup ()
  "Open a new project-root vterm as a bottom popup."
  (interactive)
  (let* ((project-root (cyan/current-project-root))
         (project-name
          (file-name-nondirectory (directory-file-name project-root)))
         (buffer-name (format "%s[vterm]" project-name))
         (default-directory project-root)
         (display-buffer-overriding-action
          '((popper-select-popup-at-bottom))))
    (cyan/register-vterm-buffer (vterm buffer-name) 'popup)))

(defun cyan/regular-window-for-vterm ()
  "Return the most recently used non-side window for a vterm session."
  (let ((selected (selected-window)))
    (if (not (window-parameter selected 'window-side))
        selected
      (car
       (sort (seq-filter
              (lambda (window)
                (not (window-parameter window 'window-side)))
              (window-list nil 'nomini))
             (lambda (left right)
               (> (window-use-time left) (window-use-time right))))))))

(defun cyan/vterm-project-regular ()
  "Open a new project-root vterm in a regular window."
  (interactive)
  (let* ((project-root (cyan/current-project-root))
         (project-name
          (file-name-nondirectory (directory-file-name project-root)))
         (buffer-name (format "%s[vterm-regular]" project-name))
         (target-window (cyan/regular-window-for-vterm)))
    (unless (window-live-p target-window)
      (user-error "No regular window is available for vterm"))
    (select-window target-window)
    (let ((default-directory project-root)
          (display-buffer-overriding-action
           '((display-buffer-same-window))))
      (cyan/register-vterm-buffer (vterm buffer-name) 'regular))))

(defalias 'vterm-regular #'cyan/vterm-project-regular)

(defvar cyan/codex-buffers nil
  "Codex vterm buffers in creation order.")

(defun cyan/codex-cycle-buffer (step)
  "Switch STEP positions through live Codex buffers."
  (setq cyan/codex-buffers
        (seq-filter #'buffer-live-p cyan/codex-buffers))
  (let ((count (length cyan/codex-buffers)))
    (cond
     ((zerop count)
      (user-error "No Codex buffers"))
     ((= count 1)
      (message "Only one Codex buffer"))
     (t
      (let* ((current-index
              (or (seq-position cyan/codex-buffers (current-buffer)) 0))
             (next-index (mod (+ current-index step) count)))
        (switch-to-buffer (nth next-index cyan/codex-buffers)))))))

(defun cyan/codex-next-buffer ()
  "Switch to the next Codex buffer."
  (interactive)
  (cyan/codex-cycle-buffer 1))

(defun cyan/codex-previous-buffer ()
  "Switch to the previous Codex buffer."
  (interactive)
  (cyan/codex-cycle-buffer -1))

(defun cyan/codex-kill-session ()
  "Kill the current Codex process, its vterm process, and its buffer."
  (interactive)
  (unless cyan/codex-session-mode
    (user-error "Current buffer is not a Codex session"))
  (let ((buffer (current-buffer))
        (process (get-buffer-process (current-buffer))))
    (setq cyan/codex-buffers (delq buffer cyan/codex-buffers))
    (when (process-live-p process)
      (set-process-query-on-exit-flag process nil)
      ;; Kill Codex as the terminal's foreground process group first.
      (ignore-errors (kill-process process t))
      (when (process-live-p process)
        (delete-process process)))
    (when (buffer-live-p buffer)
      (kill-buffer buffer))))

(defvar-keymap cyan/codex-session-mode-map
  :doc "Keymap used by Codex vterm sessions."
  "M-n" #'cyan/codex-next-buffer
  "M-p" #'cyan/codex-previous-buffer
  "M-k" #'cyan/codex-kill-session)

(define-minor-mode cyan/codex-session-mode
  "Enable navigation between Codex vterm sessions."
  :init-value nil
  :lighter " Codex"
  :keymap cyan/codex-session-mode-map)

(defun cyan/register-codex-buffer (buffer)
  "Register BUFFER as a navigable Codex vterm session."
  (with-current-buffer buffer
    (cyan/codex-session-mode 1))
  (unless (memq buffer cyan/codex-buffers)
    (setq cyan/codex-buffers
          (append (seq-filter #'buffer-live-p cyan/codex-buffers)
                  (list buffer)))))

(defun cyan/regular-window-for-codex ()
  "Return the most recently used non-side window for a Codex session."
  (let ((selected (selected-window)))
    (if (not (window-parameter selected 'window-side))
        selected
      (car
       (sort (seq-filter
              (lambda (window)
                (not (window-parameter window 'window-side)))
              (window-list nil 'nomini))
             (lambda (left right)
               (> (window-use-time left) (window-use-time right))))))))

(defun cyan/codex ()
  "Start a new Codex vterm session at the current project root."
  (interactive)
  (let* ((project-root (cyan/current-project-root))
         (project-name
          (file-name-nondirectory (directory-file-name project-root)))
         (buffer-name (format "%s[codex]" project-name))
         (target-window (cyan/regular-window-for-codex)))
    (unless (window-live-p target-window)
      (user-error "No regular window is available for Codex"))
    (select-window target-window)
    (let* ((default-directory project-root)
           (display-buffer-overriding-action
            '((display-buffer-same-window)))
           (buffer (vterm buffer-name)))
      (cyan/register-codex-buffer buffer)
      (with-current-buffer buffer
        (vterm-send-string "codex")
        (vterm-send-return))
      buffer)))

(defalias 'codex #'cyan/codex)

(defun to-popper ()
  "Move the current vterm window into Popper."
  (interactive)
  (unless (derived-mode-p 'vterm-mode)
    (user-error "Current buffer is not a vterm"))
  (when (bound-and-true-p cyan/codex-session-mode)
    (user-error "Codex sessions cannot be moved into the vterm popup group"))
  (let ((buffer (current-buffer)))
    (cyan/register-vterm-buffer buffer 'popup)
    (popper-lower-to-popup buffer)))

(use-package vterm ; Provides a fast terminal emulator backed by libvterm.
  :custom
  (vterm-always-compile-module t)
  (vterm-max-scrollback 20000)
  :hook (vterm-mode . cyan/vterm-enable-directory-tracking)
  :bind (("C-c v" . cyan/vterm-project-popup)
         ([remap vterm] . cyan/vterm-project-popup))
  :config
  (unless (advice-member-p #'cyan/rename-vterm-for-current-directory
                           #'vterm--set-directory)
    (advice-add #'vterm--set-directory
                :after #'cyan/rename-vterm-for-current-directory))
  ;; Let Popper handle M-` instead of sending it to the terminal.
  (unless (member "M-`" vterm-keymap-exceptions)
    (customize-set-variable
     'vterm-keymap-exceptions
     (cons "M-`" vterm-keymap-exceptions)))
  ;; Register managed vterms that existed before re-evaluating this config.
  (dolist (buffer (buffer-list))
    (when (and (buffer-live-p buffer)
               (with-current-buffer buffer
                 (derived-mode-p 'vterm-mode)))
      (with-current-buffer buffer
        (cyan/vterm-enable-directory-tracking))
      (cond
       ((string-match-p "\\[codex\\]\\(?:<[0-9]+>\\)?$"
                        (buffer-name buffer))
        (cyan/register-codex-buffer buffer))
       ((string-match-p "\\[vterm-regular\\]\\(?:<[0-9]+>\\)?$"
                        (buffer-name buffer))
        (cyan/register-vterm-buffer buffer 'regular))
       ((string-match-p "\\[vterm\\]\\(?:<[0-9]+>\\)?$"
                        (buffer-name buffer))
        (cyan/register-vterm-buffer buffer 'popup))))))

;; ace-window
(use-package ace-window ; Selects and switches windows using short keys.
  :custom
  (aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
  (aw-scope 'frame)
  :bind ("M-o" . ace-window))

(defun cyan/remember-popper-window-height (&rest _)
  "Use the current popup height for subsequently opened Popper windows."
  (when (and (bound-and-true-p popper-mode)
             (popper-popup-p (current-buffer)))
    (setq popper-window-height (window-total-height))))

(use-package windresize ; Resizes windows interactively with direction keys.
  :bind ("C-c z" . windresize)
  :config
  ;; Reuse a manually confirmed popup height when cycling Popper buffers.
  (unless (advice-member-p #'cyan/remember-popper-window-height
                           #'windresize-exit)
    (advice-add #'windresize-exit
                :before #'cyan/remember-popper-window-height))
  ;; windresize already binds RET, the ordinary Return event (C-m).
  ;; Bind the GUI Return event before vterm handles it.
  (define-key windresize-map (kbd "<return>") #'windresize-exit)
  ;; Bind the numeric keypad Enter event before vterm handles it.
  (define-key windresize-map (kbd "<kp-enter>") #'windresize-exit))

;; winner-mode
(use-package winner ; Restores previous window configurations.
  :ensure nil
  :config
  (winner-mode 1)
  :bind (("C-c <left>" . winner-undo)
         ("C-c <right>" . winner-redo)))

;; popper
(use-package popper ; Manages temporary and popup buffers consistently.
  :demand t
  :custom
  (popper-window-height 15)
  (popper-reference-buffers
   '("\\*Messages\\*"
     "Output\\*$"
     "\\*Async Shell Command\\*"
     "\\[vterm\\]\\(?:<[0-9]+>\\)?$"
     help-mode
     compilation-mode))
  :bind (("C-`" . popper-toggle)
         ("M-`" . popper-cycle)
         ("C-M-`" . popper-toggle-type))
  :config
  (popper-mode 1)
  (popper-echo-mode 1))

;; move-text
(use-package move-text ; Moves the current line or region up and down.
  :bind (("M-<up>" . move-text-up)
         ("M-<down>" . move-text-down)))

;; multiple-cursors
(use-package multiple-cursors ; Edits multiple text locations simultaneously.
  :bind (("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this)))

;; minibuffer completion and navigation
(use-package orderless ; Matches completion candidates in any component order.
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion)))))

(use-package marginalia ; Adds helpful annotations to minibuffer candidates.
  :config
  (marginalia-mode 1))

(use-package consult ; Provides enhanced search, navigation, and buffer commands.
  :bind (("C-s" . consult-line)
         ("C-x b" . consult-buffer)
         ("C-c s" . consult-ripgrep)
         ("M-g i" . consult-imenu)
         ("M-g f" . consult-flymake)))

(use-package embark ; Runs context-sensitive actions on the item at point.
  :bind (("C-." . embark-act)
         ("C-c ." . embark-dwim)
         ("C-h B" . embark-bindings))
  :custom
  (prefix-help-command #'embark-prefix-help-command))

(use-package embark-consult ; Integrates Embark actions with Consult results.
  :after (embark consult)
  :hook (embark-collect-mode . consult-preview-at-point-mode))

;; in-buffer completion
(use-package corfu ; Displays completion candidates next to point.
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.15)
  (corfu-cycle t)
  (corfu-preselect 'prompt)
  :config
  (global-corfu-mode 1))

(use-package cape ; Adds reusable completion-at-point sources.
  :init
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-dabbrev))

(use-package yasnippet ; Expands reusable code and text snippets.
  :config
  (yas-global-mode 1))

;; language intelligence and diagnostics
(use-package eglot ; Connects buffers to Language Server Protocol servers.
  :ensure nil
  :commands (eglot eglot-ensure)
  :bind (:map eglot-mode-map
              ("C-c l r" . eglot-rename)
              ("C-c l a" . eglot-code-actions)
              ("C-c l f" . eglot-format-buffer)))

(use-package flymake ; Displays syntax and language-server diagnostics.
  :ensure nil
  :bind (:map flymake-mode-map
              ("M-n" . flymake-goto-next-error)
              ("M-p" . flymake-goto-prev-error)))

(use-package treesit-auto ; Selects Tree-sitter major modes when available.
  :custom
  (treesit-auto-install 'prompt)
  :config
  (global-treesit-auto-mode 1))

(use-package apheleia ; Formats source buffers asynchronously.
  :config
  (apheleia-global-mode 1))

(use-package editorconfig ; Applies project-specific EditorConfig settings.
  :config
  (editorconfig-mode 1))

;; projects and development environments
(use-package projectile ; Provides project discovery and project-wide commands.
  :demand t
  :custom
  (projectile-completion-system 'default)
  :bind-keymap
  ("C-c p" . projectile-command-map)
  :config
  (projectile-mode 1))

(use-package envrc ; Loads direnv environments for project buffers.
  :if (executable-find "direnv")
  :config
  (envrc-global-mode 1))

;; Git integration
(use-package diff-hl ; Shows Git changes in the window fringe.
  :demand t
  :hook (magit-post-refresh . diff-hl-magit-post-refresh)
  :config
  (global-diff-hl-mode 1)
  (diff-hl-flydiff-mode 1))

(use-package git-modes ; Provides major modes for Git configuration files.
  :defer t)

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
  (revert-buffer :ignore-auto :noconfirm :preserve-modes)
  (when (bound-and-true-p diff-hl-mode)
    (diff-hl-update)))

(global-set-key (kbd "C-c r") #'cyan/revert-buffer-no-confirm)

(use-package gruber-darker-theme ; Provides the Gruber Darker color theme.
  :defer t)

(use-package catppuccin-theme ; Provides the Catppuccin pastel color theme.
  :defer t
  :custom
  (catppuccin-flavor 'mocha))

(use-package vscode-dark-plus-theme ; Provides the Visual Studio Code Dark+ theme.
  :config
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme 'vscode-dark-plus t)
  ;; Replace the blue mode lines with neutral VS Code grays.
  (custom-theme-set-faces
   'vscode-dark-plus
   '(mode-line
     ((t (:foreground "#fafafa" :background "#333333" :box nil))))
   '(mode-line-inactive
     ((t (:foreground "#858585" :background "#252526" :box nil))))
   '(mode-line-buffer-id
     ((t (:foreground unspecified :weight bold)))))
  (enable-theme 'vscode-dark-plus))
