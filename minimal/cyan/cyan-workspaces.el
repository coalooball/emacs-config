;;; cyan-workspaces.el --- Tabspaces and Consult integration -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:

;; Personal configuration loaded from post-init.el.

;;; Code:

(require 'use-package)
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
  ;; Do not restore sessions automatically at startup.  A saved Ghostel
  ;; window can respawn its PTY (and a Codex TUI) during startup; restoring
  ;; several such buffers at once can saturate the Emacs event loop and make
  ;; the NS frame appear frozen.  Sessions remain available through
  ;; `M-x tabspaces-restore-session' when an explicit restore is wanted.
  (tabspaces-session-auto-restore nil)
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

(provide 'cyan-workspaces)
;;; cyan-workspaces.el ends here
