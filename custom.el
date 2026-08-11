;;; custom.el --- user customization file    -*- lexical-binding: t no-byte-compile: t -*-
;;; Commentary:
;;;       Add or change the configurations in custom.el, then restart Emacs.
;;;       Put your own configurations in custom-post.el to override default configurations.
;;; Code:

;; (setq centaur-logo nil)                        ; Logo file or nil (official logo)
;; (setq centaur-full-name "user name")           ; User full name
;; (setq centaur-mail-address "user@email.com")   ; Email address
;; (setq centaur-proxy "127.0.0.1:7897")          ; HTTP/HTTPS proxy
;; (setq centaur-socks-proxy "127.0.0.1:7897")    ; SOCKS proxy

;; (setq centaur-use-exec-path-from-shell nil)    ; Use `exec-path-from-shell' or not. If using emacs-plus with path ejection, set to nil
;; (setq centaur-icon nil)                        ; Display icons or not: t or nil
(setq centaur-package-archives 'bfsu)         ; Package repo: melpa, bfsu, iscas, netease, sjtu, tencent, tuna or ustc
;; (setq centaur-theme 'auto)                     ; Color theme: auto, random, system, default, pro, dark, light, warm, cold, day or night
;; (setq centaur-completion-style 'minibuffer)    ; Completion display style: minibuffer or childframe
;; (setq centaur-frame-maximized-on-startup t)    ; Maximize frame on startup or not: t or nil
;; (setq centaur-dashboard nil)                   ; Display dashboard at startup or not: t or nil
;; (setq centaur-lsp nil)                         ; Enable lsp or not: t or nil
;; (setq centaur-tree-sitter nil)                 ; Enable tree-sitter or not: t or nil. Only available in 29+.
;; (setq centaur-chinese-calendar t)              ; Support Chinese calendar or not: t or nil
;; (setq centaur-player t)                        ; Enable players or not: t or nil
(setq centaur-prettify-symbols-alist nil)      ; Alist of symbol prettifications. Nil to use font supports ligatures.

;; For Emacs devel
;; (setq package-user-dir (locate-user-emacs-file (format "elpa-%s" emacs-major-version)))
;; (setq desktop-base-file-name (format ".emacs-%s.desktop" emacs-major-version))
;; (setq desktop-base-lock-name (format ".emacs-%s.desktop.lock" emacs-major-version))

;; Fonts
(defun centaur-setup-fonts ()
  "Setup fonts."
  (when (display-graphic-p)
    ;; Set default font
    (cl-loop for font in '("FiraCode Nerd Font" "CaskaydiaCove Nerd Font"
                           "Fira Code" "Cascadia Code" "Jetbrains Mono"
                           "SF Mono" "Menlo" "Hack" "Source Code Pro"
                           "Monaco" "DejaVu Sans Mono" "Consolas")
             when (font-available-p font)
             return (set-face-attribute 'default nil
                                        :family font
                                        :height (cond (sys/macp 130)
                                                      (sys/win32p 110)
                                                      (t 100))))

    ;; Set mode-line font
    (cl-loop for font in '("Arial" "Helvetica" "Times New Roman")
             when (font-available-p font)
             return (progn
                      (set-face-attribute 'mode-line nil :family font :inherit 'variable-pitch)
                      (set-face-attribute 'mode-line-inactive nil :family font :inherit 'variable-pitch)))

    ;; Specify font for all unicode characters
    (cl-loop for font in '("Apple Symbols" "Segoe UI Symbol" "Symbola" "Symbol")
             when (font-available-p font)
             return (set-fontset-font t 'symbol (font-spec :family font) nil 'prepend))

    ;; Specify font for Emoji characters
    (cl-loop for font in '("Noto Color Emoji" "Apple Color Emoji" "Segoe UI Emoji")
             when (font-available-p font)
             return (set-fontset-font t 'emoji (font-spec :family font) nil 'prepend))

    ;; Specify font for Chinese characters
    (cl-loop for font in '("Noto Sans Mono CJK SC" "LXGW Neo Xihei"
                           "LXGW WenKai Mono" "WenQuanYi Micro Hei Mono"
                           "PingFang SC" "Microsoft Yahei UI" "Simhei")
             when (font-available-p font)
             return (set-fontset-font t 'han (font-spec :family font)))
    ))

(centaur-setup-fonts)
(add-hook 'window-setup-hook #'centaur-setup-fonts)
(add-hook 'server-after-make-frame-hook #'centaur-setup-fonts)

;; Ghostel
(defun my/ghostel-scroll-backward ()
  "Enter copy mode and scroll backward in a Ghostel buffer."
  (interactive)
  (ghostel-copy-mode)
  (scroll-down-command))

(defun my/ghostel-freeze-before-wheel-scroll (event &rest _)
  "Enter copy mode before scrolling a main-screen Ghostel buffer."
  (when-let* ((window (and (eventp event)
                           (posn-window (event-start event))))
              ((windowp window))
              (buffer (window-buffer window)))
    (with-selected-window window
      (with-current-buffer buffer
        (when (and (derived-mode-p 'ghostel-mode)
                   (eq ghostel--input-mode 'semi-char)
                   (not (ghostel-alt-screen-p)))
          (ghostel-copy-mode))))))

(with-eval-after-load 'ghostel
  (setq-default ghostel-glyph-scale-floor 1.0)
  (define-key ghostel-semi-char-mode-map (kbd "M-v")
    #'my/ghostel-scroll-backward)
  (define-key ghostel-semi-char-mode-map (kbd "<prior>")
    #'my/ghostel-scroll-backward)
  (unless (advice-member-p #'my/ghostel-freeze-before-wheel-scroll
                           #'mwheel-scroll)
    (advice-add #'mwheel-scroll :before
                #'my/ghostel-freeze-before-wheel-scroll)))

;; Codex in Ghostel
(defvar-local my/codex-directory nil
  "Directory associated with the current Codex buffer.")

(defun my/codex-buffers ()
  "Return live Codex Ghostel buffers sorted by name."
  (sort (seq-filter
         (lambda (buffer)
           (buffer-local-value 'my/codex-ghostel-mode buffer))
         (buffer-list))
        (lambda (a b)
          (string< (buffer-name a) (buffer-name b)))))

(defun my/codex-display-buffer (buffer)
  "Display BUFFER in the selected window, even when it is dedicated."
  (let ((window (selected-window)))
    (when (window-dedicated-p window)
      (set-window-dedicated-p window nil))
    (set-window-buffer window buffer)
    (select-window window)
    buffer))

(defun my/codex-cycle-buffer (direction)
  "Switch to another Codex buffer in DIRECTION, wrapping at the ends."
  (let* ((buffers (my/codex-buffers))
         (count (length buffers))
         (index (cl-position (current-buffer) buffers))
         (target (cond
                  ((zerop count) nil)
                  ((null index) (if (> direction 0)
                                    (car buffers)
                                  (car (last buffers))))
                  (t (nth (mod (+ index direction) count) buffers)))))
    (cond
     ((null target)
      (user-error "No Codex buffers"))
     ((and (= count 1) (eq target (current-buffer)))
      (message "Only one Codex buffer"))
     (t
      (my/codex-display-buffer target)))))

(defun my/codex-next-buffer ()
  "Switch to the next Codex buffer."
  (interactive)
  (my/codex-cycle-buffer 1))

(defun my/codex-previous-buffer ()
  "Switch to the previous Codex buffer."
  (interactive)
  (my/codex-cycle-buffer -1))

(defvar my/codex-ghostel-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-n") #'my/codex-next-buffer)
    (define-key map (kbd "C-p") #'my/codex-previous-buffer)
    map)
  "Keymap active in Codex Ghostel buffers.")

(define-minor-mode my/codex-ghostel-mode
  "Minor mode for a Codex process running inside Ghostel."
  :lighter " Codex"
  :keymap my/codex-ghostel-mode-map)

(defun codex (directory)
  "Run Codex in DIRECTORY inside Ghostel in the selected window."
  (interactive
   (list (read-directory-name "Codex directory: " default-directory nil t)))
  (require 'ghostel)
  (let* ((directory (file-name-as-directory (expand-file-name directory)))
         (directory-name (file-name-nondirectory (directory-file-name directory)))
         (buffer-name (format "%s[codex]" directory-name))
         (existing (get-buffer buffer-name))
         (program (executable-find "codex")))
    (when (file-remote-p directory)
      (user-error "Codex directory must be local"))
    (unless program
      (user-error "Cannot find the codex executable"))
    (if existing
        (if (and (buffer-local-value 'my/codex-ghostel-mode existing)
                 (equal (buffer-local-value 'my/codex-directory existing)
                        directory))
            (my/codex-display-buffer existing)
          (user-error "Buffer %s already exists for another purpose" buffer-name))
      (let ((buffer (get-buffer-create buffer-name)))
        (condition-case err
            (progn
              (with-current-buffer buffer
                (setq default-directory directory)
                (ghostel-mode)
                (setq-local ghostel-buffer-name-function nil)
                (setq-local my/codex-directory directory))
              (my/codex-display-buffer buffer)
              (ghostel-exec buffer program '("--no-alt-screen"))
              (with-current-buffer buffer
                (my/codex-ghostel-mode 1))
              buffer)
          ((error quit)
           (when (buffer-live-p buffer)
             (kill-buffer buffer))
           (signal (car err) (cdr err))))))))

;; Mail
;; (setq message-send-mail-function 'smtpmail-send-it
;;       smtpmail-starttls-credentials '(("smtp.gmail.com" 587 nil nil))
;;       smtpmail-auth-credentials '(("smtp.gmail.com" 587
;;                                    user-mail-address nil))
;;       smtpmail-default-smtp-server "smtp.gmail.com"
;;       smtpmail-smtp-server "smtp.gmail.com"
;;       smtpmail-smtp-service 587)

;; Calendar
;; Set location , then press `S' can show the time of sunrise and sunset
;; (setq calendar-location-name "Chengdu"
;;       calendar-latitude 30.67
;;       calendar-longitude 104.07)

;; Misc.
;; (setq confirm-kill-emacs 'y-or-n-p)
;; (setq package-check-signature nil)
;; (setq trusted-content ':all)

;; Enable proxy
;; (enable-http-proxy)
;; (enable-socks-proxy)

;; Display on the specified monitor
;; (when (and (> (length (display-monitor-attributes-list)) 1)
;;            (> (display-pixel-width) 1920))
;;   (set-frame-parameter nil 'left 288))

;; (put 'cl-destructuring-bind 'lisp-indent-function 'defun)
;; (put 'pdf-view-create-image 'lisp-indent-function 'defun)
;; (put 'treemacs-create-theme 'lisp-indent-function 'defun)

;; For compat
;; (add-hook 'emacs-lisp-mode-hook
;;           (defun compat-add-to-imenu ()
;;             "Add to imenu list."
;;             (add-to-list
;;              'imenu-generic-expression
;;              '(nil
;;                "^\\s-*(\\(compat-def\\(?:un\\|macro\\|alias\\)\\)\\s-+\\(\\(?:\\w\\|\\s_\\|\\\\.\\)+\\)"
;;                2))
;;             (add-to-list
;;              'imenu-generic-expression
;;              '("Packages" "^\\s-*(\\(compat-require\\)\\s-+\\(\\(?:\\w\\|\\s_\\|\\\\.\\)+\\)" 2))
;;             (add-to-list
;;              'imenu-generic-expression
;;              '("Variables"
;;                "^\\s-*(\\(compat-def\\(?:var\\|const\\)\\)?\\s-+\\(\\(?:\\w\\|\\s_\\|\\\\.\\)+\\)[[:space:]\n]+[^)]"
;;                2))))

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-vc-selected-packages
   '((gptel-magit :url "https://github.com/roife/gptel-magit"))))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

;;; custom.el ends here
