;;; cyan-hurl.el --- Hurl file association -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:

;; Personal configuration loaded from post-init.el.

;;; Code:

(require 'use-package)

(defun my/hurl-run-buffer ()
  "Run the current Hurl file and show its output in a compilation buffer."
  (interactive)
  (unless buffer-file-name
    (user-error "This buffer is not visiting a file"))
  (when (buffer-modified-p)
    (save-buffer))
  (let ((default-directory (file-name-directory buffer-file-name)))
    (compile (format "hurl --no-color %s | perl -pe 's/\\e\\[[0-9;]*m//g' | jq -M ."
                    (shell-quote-argument (file-name-nondirectory
                                           buffer-file-name))))))

(use-package hurl-mode
  :ensure nil
  :mode "\\.hurl\\'"
  :bind (:map hurl-mode-map
              ("C-c C-c" . my/hurl-run-buffer)))

(provide 'cyan-hurl)
;;; cyan-hurl.el ends here
