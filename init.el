(require 'package)

(setq package-archives
      '(("gnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
        ("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
        ("melpa" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))

(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(require 'use-package)
(setq use-package-always-ensure t)

(load-theme 'modus-vivendi t)

;; Basic editing.
(electric-pair-mode 1)
(delete-selection-mode 1)
(savehist-mode 1)
(recentf-mode 1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

(setq-default indent-tabs-mode nil
              tab-width 4)
(setq tab-always-indent 'complete)

;; Window resizing.
(global-set-key (kbd "C-M-<left>")  #'shrink-window-horizontally)
(global-set-key (kbd "C-M-<right>") #'enlarge-window-horizontally)
(global-set-key (kbd "C-M-<down>")  #'shrink-window)
(global-set-key (kbd "C-M-<up>")    #'enlarge-window)

(use-package exec-path-from-shell
  :if (memq system-type '(darwin gnu/linux))
  :config
  (exec-path-from-shell-initialize))

;; Minibuffer completion.
(use-package vertico
  :init
  (vertico-mode))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides
   '((file (styles partial-completion)))))

(use-package marginalia
  :init
  (marginalia-mode))

;; Search and navigation.
(use-package consult
  :bind
  (("C-s" . consult-line)
   ("C-x b" . consult-buffer)
   ("M-s r" . consult-ripgrep)
   ("M-g i" . consult-imenu)))

;; Completion inside source buffers.
(use-package corfu
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.2)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  :init
  (global-corfu-mode))

(use-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-file))

;; Install and enable Tree-sitter modes for the languages used here.
(use-package treesit-auto
  :custom
  (treesit-auto-langs
   '(javascript typescript tsx python rust c cpp))
  (treesit-auto-install 'prompt)
  :config
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))

;; Language Server Protocol support.
(use-package eglot
  :ensure nil
  :custom
  (eglot-autoshutdown t)
  (eglot-send-changes-idle-time 0.5)
  :config
  ;; Eglot in Emacs 30.2 does not register a JS/TS server by default.
  (add-to-list
   'eglot-server-programs
   '((js-mode js-ts-mode typescript-ts-mode tsx-ts-mode)
     . ("typescript-language-server" "--stdio")))

  (dolist (hook '(js-ts-mode-hook
                  typescript-ts-mode-hook
                  tsx-ts-mode-hook
                  python-ts-mode-hook
                  rust-ts-mode-hook
                  c-ts-mode-hook
                  c++-ts-mode-hook))
    (add-hook hook #'eglot-ensure)))

;; Format source files after saving without moving point unnecessarily.
(use-package apheleia
  :config
  (setf (alist-get 'ruff apheleia-formatters)
        '("ruff" "format" "--stdin-filename" filepath "-")
        (alist-get 'clang-format apheleia-formatters)
        '("clang-format" "--assume-filename" filepath))

  (dolist (mode '(js-ts-mode typescript-ts-mode tsx-ts-mode))
    (setf (alist-get mode apheleia-mode-alist) 'prettier))

  (setf (alist-get 'python-ts-mode apheleia-mode-alist) 'ruff
        (alist-get 'rust-ts-mode apheleia-mode-alist) 'rustfmt
        (alist-get 'c-ts-mode apheleia-mode-alist) 'clang-format
        (alist-get 'c++-ts-mode apheleia-mode-alist) 'clang-format)

  (apheleia-global-mode 1))

(use-package magit
  :bind
  ("C-x g" . magit-status))

;; Show Git changes in the fringe, similar to VS Code's gutter markers.
(use-package diff-hl
  :hook
  (magit-post-refresh . diff-hl-magit-post-refresh)
  :init
  (global-diff-hl-mode)
  :config
  (diff-hl-flydiff-mode)
  (unless (display-graphic-p)
    (diff-hl-margin-mode)))

;; Notes, tasks, and agenda.
(use-package org
  :ensure nil
  :demand t
  :bind
  (("C-c a" . org-agenda)
   ("C-c c" . org-capture)
   ("C-c l" . org-store-link))
  :hook
  ((org-mode . visual-line-mode)
   (org-mode . org-indent-mode))
  :custom
  (org-directory (expand-file-name "org" user-emacs-directory))
  (org-default-notes-file (expand-file-name "inbox.org" org-directory))
  (org-agenda-files (list org-directory))
  (org-log-done 'time)
  (org-startup-folded 'content)
  (org-startup-indented t)
  (org-hide-emphasis-markers t)
  (org-pretty-entities t)
  (org-src-fontify-natively t)
  (org-src-tab-acts-natively t)
  (org-todo-keywords
   '((sequence "TODO(t)" "NEXT(n)" "WAIT(w@/!)" "|" "DONE(d!)" "CANCELLED(c@)")))
  (org-capture-templates
   `(("t" "Task" entry
      (file+headline ,(expand-file-name "inbox.org" org-directory) "Tasks")
      "* TODO %?\n  %U\n  %a")
     ("n" "Note" entry
      (file+headline ,(expand-file-name "notes.org" org-directory) "Notes")
      "* %?\n  %U\n  %a")))
  :config
  (make-directory org-directory t))

(with-eval-after-load 'eat
  (setq eat-minimum-latency 0.02
        eat-maximum-latency 0.1
        eat-very-visible-cursor-type '(box nil nil)
        eat-very-visible-vertical-bar-cursor-type '(bar nil nil)
        eat-very-visible-horizontal-bar-cursor-type '(hbar nil nil)))
