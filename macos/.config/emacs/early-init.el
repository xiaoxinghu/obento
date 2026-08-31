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
