;;; cyan-hurl.el --- Hurl file association -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:

;; Personal configuration loaded from post-init.el.

;;; Code:

(require 'use-package)
(use-package hurl-mode
  :ensure nil
  :mode "\\.hurl\\'")

(provide 'cyan-hurl)
;;; cyan-hurl.el ends here
