;;; cyan-ghostel-ns-ime.el --- macOS preedit in Ghostel -*- lexical-binding: t; -*-

;;; Commentary:

;; Keep native IME preedit overlays out of Ghostel's renderer-owned text.
;; Committed characters continue through Ghostel's normal input handling.

;;; Code:

(declare-function ns-echo-working-text "term/ns-win")

(defun my/ghostel-ns-insert-working-text (original &rest args)
  "Display native preedit in the echo area when editing a Ghostel buffer.
Call ORIGINAL with ARGS for other buffers.  In particular, avoid placing
an `after-string' overlay between terminal glyphs with display properties."
  (if (derived-mode-p 'ghostel-mode)
      (ns-echo-working-text)
    (apply original args)))

(when (eq system-type 'darwin)
  (with-eval-after-load 'ns-win
    (advice-add 'ns-insert-working-text :around
                #'my/ghostel-ns-insert-working-text)))

(provide 'cyan-ghostel-ns-ime)
;;; cyan-ghostel-ns-ime.el ends here
