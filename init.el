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
(defun cyan/vterm-project-popup ()
  "Open a new project-root vterm as a bottom popup."
  (interactive)
  (let* ((start-directory (if buffer-file-name
                              (file-name-directory buffer-file-name)
                            default-directory))
         (project-root (or (projectile-project-root start-directory)
                           start-directory))
         (project-name
          (file-name-nondirectory (directory-file-name project-root)))
         (buffer-name (format "%s[vterm]" project-name))
         (default-directory (file-name-as-directory project-root))
         (display-buffer-overriding-action
          '((popper-select-popup-at-bottom))))
    (vterm buffer-name)))

(use-package vterm ; Provides a fast terminal emulator backed by libvterm.
  :custom
  (vterm-always-compile-module t)
  (vterm-max-scrollback 20000)
  :bind ("C-c v" . cyan/vterm-project-popup))

;; ace-window
(use-package ace-window ; Selects and switches windows using short keys.
  :custom
  (aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
  (aw-scope 'frame)
  :bind ("M-o" . ace-window))

(use-package windresize ; Resizes windows interactively with direction keys.
  :bind ("C-c z" . windresize))

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
  :hook ((prog-mode . diff-hl-mode)
         (text-mode . diff-hl-mode)
         (magit-post-refresh . diff-hl-magit-post-refresh)))

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
  (revert-buffer :ignore-auto :noconfirm :preserve-modes))

(global-set-key (kbd "C-c r") #'cyan/revert-buffer-no-confirm)

(use-package gruber-darker-theme ; Provides the Gruber Darker color theme.
  :config
  (load-theme 'gruber-darker t))
