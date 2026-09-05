;;; post-init.el --- Personal configuration -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:

;; Personal additions to minimal-emacs.d.  Keep the upstream init files
;; unchanged so they can be updated independently.
;; Keep baseline package settings here; personal features live in cyan/.

;;; Code:

;; Resolve personal modules relative to this configuration file.
(add-to-list 'load-path
             (expand-file-name "cyan"
                               (file-name-directory
                                (or load-file-name buffer-file-name))))

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

(require 'cyan-editing)
(require 'cyan-macos)

;;; Projects

(with-eval-after-load 'project
  ;; Treat Git submodules as projects in their own right.
  (setq project-vc-merge-submodules nil)
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

(defun my-minibuffer-font-scale ()
  "Increase the font size of minibuffer prompts and completion candidates."
  (face-remap-set-base 'default '(:height 1.6) 'default))

(add-hook 'minibuffer-setup-hook #'my-minibuffer-font-scale)

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

(require 'cyan-workspaces)

;;; In-buffer completion

(use-package corfu
  :custom
  (corfu-auto nil)
  (corfu-cycle t)
  (corfu-preselect 'prompt)
  :init
  (global-corfu-mode 1))

;;; Programming tools

(require 'cyan-hurl)

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

(require 'cyan-terminal)
(require 'cyan-codex)

(provide 'post-init)
;;; post-init.el ends here
