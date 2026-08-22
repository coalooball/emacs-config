;;; post-init.el --- Personal configuration -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:

;; Personal additions to minimal-emacs.d.  Keep the upstream init files
;; unchanged so they can be updated independently.

;;; Code:

;;; Appearance

(load-theme 'tsdh-dark t)

;;; Scratch buffer

(setq initial-major-mode 'lisp-interaction-mode)

;;; File state and history

(use-package autorevert
  :ensure nil
  :init
  (setq auto-revert-interval 3
        auto-revert-remote-files nil
        auto-revert-use-notify t)
  (global-auto-revert-mode 1))

(use-package recentf
  :ensure nil
  :init
  (setq recentf-auto-cleanup (if (daemonp) 300 'never))
  (recentf-mode 1))

(use-package savehist
  :ensure nil
  :init
  (setq savehist-autosave-interval 600)
  (savehist-mode 1))

(use-package saveplace
  :ensure nil
  :init
  (save-place-mode 1))

;;; Editing and windows

(delete-selection-mode 1)
(electric-pair-mode 1)
(show-paren-mode 1)
(repeat-mode 1)
(winner-mode 1)
(global-so-long-mode 1)
(which-key-mode 1)

(add-hook 'prog-mode-hook #'display-line-numbers-mode)

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

;;; Projects

(with-eval-after-load 'project
  ;; A .project file is an explicit fallback for projects without version
  ;; control.  The manifest files cover common language-specific projects.
  (setq project-vc-extra-root-markers
        '(".project"
          "pyproject.toml"
          "Cargo.toml"
          "go.mod"
          "package.json")))

;;; macOS environment

(use-package exec-path-from-shell
  :if (and (eq system-type 'darwin)
           (or (display-graphic-p) (daemonp)))
  :demand t
  :custom
  (exec-path-from-shell-variables
   '("PATH" "MANPATH" "TMPDIR" "SSH_AUTH_SOCK"
     "LANG" "LC_CTYPE"))
  :config
  (exec-path-from-shell-initialize))

;;; Minibuffer completion and navigation

(use-package vertico
  :init
  (vertico-mode 1))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion)))))

(use-package marginalia
  :bind (:map minibuffer-local-map
              ("M-A" . marginalia-cycle))
  :init
  (marginalia-mode 1))

(use-package consult
  :bind (([remap switch-to-buffer] . consult-buffer)
         ([remap switch-to-buffer-other-window]
          . consult-buffer-other-window)
         ("C-x p b" . consult-project-buffer)
         ("M-g f" . consult-flymake)
         ("M-g i" . consult-imenu)
         ("M-s l" . consult-line)
         ("M-s r" . consult-ripgrep))
  :init
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref))

;;; Workspaces

;; Keep tab-backed workspaces available without showing the top tab bar.
(customize-set-variable 'tab-bar-show nil)

(use-package tabspaces
  :hook (after-init . tabspaces-mode)
  :commands (tabspaces-switch-or-create-workspace
             tabspaces-open-or-create-project-and-workspace)
  :custom
  ;; Consult provides the buffer UI; its workspace source is configured below.
  (tabspaces-use-filtered-buffers-as-default nil)
  (tabspaces-default-tab "Default")
  (tabspaces-remove-to-default t)
  (tabspaces-include-buffers '("*scratch*"))
  ;; Do not create project-todo.org in newly opened projects.
  (tabspaces-initialize-project-with-todo nil)
  (tabspaces-fully-resolve-paths t)
  ;; Make `C-x p p' reuse or create the project's tab, so its window
  ;; configuration is restored together with the project workspace.
  (tabspaces-project-switch-opens-workspace t)
  (tabspaces-session t)
  (tabspaces-session-auto-restore t)
  ;; Keep session metadata out of project repositories.
  (tabspaces-session-project-session-store
   (expand-file-name "tabspaces-sessions/" user-emacs-directory))
  (tab-bar-new-tab-choice "*scratch*"))

(with-eval-after-load 'consult
  ;; Show current-workspace buffers by default.  Narrow with "b" to see the
  ;; complete buffer list from every workspace.
  (plist-put consult-source-buffer :hidden t)
  (plist-put consult-source-buffer :default nil)
  (defvar my-consult-source-workspace
    (list :name "Workspace Buffers"
          :narrow ?w
          :history 'buffer-name-history
          :category 'buffer
          :state #'consult--buffer-state
          :default t
          :items (lambda ()
                   (consult--buffer-query
                    :predicate #'tabspaces--local-buffer-p
                    :sort 'visibility
                    :as #'buffer-name)))
    "Workspace-local buffer source for `consult-buffer'.")
  (add-to-list 'consult-buffer-sources 'my-consult-source-workspace))

;;; In-buffer completion

(use-package corfu
  :custom
  (corfu-auto nil)
  (corfu-cycle t)
  (corfu-preselect 'prompt)
  :init
  (global-corfu-mode 1))

;;; Programming tools

(use-package flymake
  :ensure nil
  :bind (:map flymake-mode-map
              ("M-g n" . flymake-goto-next-error)
              ("M-g p" . flymake-goto-prev-error)
              ("M-g d" . flymake-show-buffer-diagnostics)))

(use-package eglot
  :ensure nil
  :commands (eglot
             eglot-ensure
             eglot-rename
             eglot-format-buffer))

(use-package magit
  :commands magit-status
  :bind ("C-x g" . magit-status))

;;; Terminal

(setq ghostel-module-directory
      (expand-file-name "var/ghostel/" user-emacs-directory)
      ghostel-module-auto-install 'download)

(use-package ghostel
  :commands (ghostel
             ghostel-project
             ghostel-project-list-buffers)
  :bind (("C-c t" . ghostel)
         :map project-prefix-map
         ("m" . ghostel-project)
         ("M" . ghostel-project-list-buffers))
  :init
  ;; Keep CJK fallback glyphs at their natural size instead of shrinking them
  ;; to Ghostel's strict terminal grid.
  (setq-default ghostel-glyph-scale-floor 1.0)
  (with-eval-after-load 'project
    (add-to-list 'project-switch-commands
                 '(ghostel-project "Ghostel") t)
    (add-to-list 'project-switch-commands
                 '(ghostel-project-list-buffers "Ghostel buffers") t)))

(provide 'post-init)
;;; post-init.el ends here
