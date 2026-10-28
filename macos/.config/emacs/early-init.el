;;; -*- lexical-binding: t; -*-

(setenv "LSP_USE_PLISTS" "true")

(setq enable-local-variables :safe
      bidi-inhibit-bpa t
      redisplay-skip-fontification-on-input t
      read-process-output-max (* 4 1024 1024))

(setq-default bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)

(defvar my/env-path (expand-file-name "~/.env.el"))
(when (file-exists-p my/env-path)
  (load my/env-path))

;; No file name handlers while init loads files; restored, with any added
;; meanwhile, once init is done.
(let ((handlers file-name-handler-alist))
  (setq file-name-handler-alist nil)
  (add-hook 'after-init-hook
            (lambda ()
              (setq file-name-handler-alist
                    (delete-dups (append file-name-handler-alist handlers))))
            -100))

;; The first frame is made with these, rather than changed (and resized) by
;; ui.el after it is drawn.  The font is from the Brewfile.
(setq frame-inhibit-implied-resize t
      tool-bar-mode nil
      scroll-bar-mode nil)
(dolist (param '((tool-bar-lines . 0)
                 (vertical-scroll-bars)
                 (ns-transparent-titlebar . t)
                 (ns-appearance . dark)
                 (alpha-background . 85)
                 (font . "JetBrainsMono Nerd Font-17")))
  (push param default-frame-alist))

;; one autoloads file instead of activating each package; where no-littering
;; puts it, which loads too late for this.  M-x package-quickstart-refresh
;; after changing packages by hand.
(setq package-quickstart t
      package-quickstart-file
      (expand-file-name "var/package-quickstart.el" user-emacs-directory))

;; this is for speed up the start up, will be reset by gcmh later
(setq gc-cons-threshold most-positive-fixnum)

(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (convert-standard-filename
    (expand-file-name  "var/eln-cache/" user-emacs-directory))))

;; UX: Suppress compiler warnings and don't inundate users with their popups.
;;   They are rarely more than warnings, so are safe to ignore.
(setq native-comp-async-report-warnings-errors nil
      native-comp-warning-on-missing-source nil)
