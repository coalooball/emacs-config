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

(require 'treesit nil t)

(use-package expand-region
  :bind
  ("C-=" . er/expand-region))

(use-package multiple-cursors
  :bind
  (("C-S-c C-S-c" . mc/edit-lines)
   ("C->" . mc/mark-next-like-this)
   ("C-<" . mc/mark-previous-like-this)
   ("C-c C-<" . mc/mark-all-like-this)))

(defun my/move-line-up ()
  "Move the current line up by one line."
  (interactive)
  (let ((column (current-column)))
    (if (= (line-beginning-position) (point-min))
        (user-error "Already on first line")
      (transpose-lines 1)
      (forward-line -2)
      (move-to-column column))))

(defun my/move-line-down ()
  "Move the current line down by one line."
  (interactive)
  (let ((column (current-column)))
    (forward-line 1)
    (if (eobp)
        (progn
          (forward-line -1)
          (user-error "Already on last line"))
      (transpose-lines 1)
      (forward-line -1)
      (move-to-column column))))

(defun my/duplicate-line-below ()
  "Duplicate the current line below the current line."
  (interactive)
  (let ((column (current-column))
        (line (buffer-substring (line-beginning-position)
                                (line-end-position))))
    (end-of-line)
    (newline)
    (insert line)
    (move-to-column column)))

(global-set-key (kbd "M-<up>") #'my/move-line-up)
(global-set-key (kbd "M-<down>") #'my/move-line-down)
(global-set-key (kbd "C-c D") #'my/duplicate-line-below)

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

(use-package which-key
  :ensure nil
  :custom
  (which-key-idle-delay 0.4)
  :init
  (which-key-mode))

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

;; Database connections.
;;
;; Emacs' built-in sql.el talks to the standard command-line clients:
;; psql, mysql, sqlite3, etc.  Keep passwords out of this file; use
;; ~/.pgpass, ~/.my.cnf, environment variables, or the client's password
;; prompt instead.
(use-package sql
  :ensure nil
  :mode
  (("\\.sql\\'" . sql-mode))
  :bind
  (("C-c d c" . sql-connect)
   ("C-c d p" . sql-set-product)
   :map sql-mode-map
   ("C-c C-c" . sql-send-paragraph)
   ("C-c C-b" . sql-send-buffer)
   ("C-c C-r" . sql-send-region)
   ("C-c C-z" . sql-show-sqli-buffer))
  :custom
  (sql-postgres-login-params
   '((user :default "postgres")
     (database :default "postgres")
     (server :default "localhost")
     (port :default 5432)))
  (sql-mysql-login-params
   '((user :default "root")
     (database :default "")
     (server :default "localhost")
     (port :default 3306)))
  (sql-connection-alist
   '(("local-postgres"
      (sql-product 'postgres)
      (sql-user "postgres")
      (sql-server "localhost")
      (sql-port 5432)
      (sql-database "postgres"))
     ("local-mysql"
      (sql-product 'mysql)
      (sql-user "root")
      (sql-server "localhost")
      (sql-port 3306)
      (sql-database ""))
     ("local-sqlite"
      (sql-product 'sqlite)
      (sql-database "~/database.sqlite3"))))
  :hook
  (sql-interactive-mode . toggle-truncate-lines)
  :config
  (add-hook 'sql-mode-hook
            (lambda ()
              (setq-local comment-start "-- "
                          comment-end ""))))

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
  (setq eat-minimum-latency 0.03
        eat-maximum-latency 0.18
        eat-kill-buffer-on-exit t
        eat-enable-shell-prompt-annotation nil
        eat-term-scrollback-size 20000
        eat-very-visible-cursor-type '(box nil nil)
        eat-very-visible-vertical-bar-cursor-type '(bar nil nil)
        eat-very-visible-horizontal-bar-cursor-type '(hbar nil nil))

  ;; Eat resizes the terminal and redisplays it synchronously on every
  ;; window-size change.  When a TUI such as Codex is streaming output,
  ;; dragging another split can create enough resize/redisplay work to
  ;; monopolize Emacs' single Lisp thread.  Coalesce repeated resize
  ;; requests and apply only the latest size shortly after dragging.
  (defvar my/eat-resize-timers (make-hash-table :weakness 'key))

  (defun my/eat-adjust-process-window-size-debounced
      (orig-fn process windows)
    (let ((buffer (process-buffer process)))
      (if (not (buffer-live-p buffer))
          (funcall orig-fn process windows)
        (when-let ((timer (gethash process my/eat-resize-timers)))
          (cancel-timer timer))
        (puthash
         process
         (run-with-timer
          0.12 nil
          (lambda (process buffer orig-fn)
            (remhash process my/eat-resize-timers)
            (when (and (process-live-p process)
                       (buffer-live-p buffer))
              (with-current-buffer buffer
                (funcall orig-fn
                         process
                         (get-buffer-window-list buffer nil t)))))
          process
          buffer
          orig-fn)
         my/eat-resize-timers)
        nil)))

  (advice-add 'eat--adjust-process-window-size
              :around #'my/eat-adjust-process-window-size-debounced))
