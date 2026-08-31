;;; -*- lexical-binding: t; -*-

;; customisation
(defun build-path (&rest parts)
  (cl-reduce (lambda (a b) (expand-file-name b a))
             parts
             :initial-value ""))

(defcustom my/dark-theme 'ef-bio
  "My default dark theme")
(defcustom my/light-theme 'ef-frost
  "My default light theme")

(defcustom my/org-location (expand-file-name "~/life")
  "My org root location")
(defcustom my/now-file (expand-file-name "now.org" my/org-location)
  "My one file")

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(require 'basic)
(require 'functions)
(require 'ui)
(require 'keybindings)
(require 'navigation)
;; I can feel at home right here
(require 'notes)
(require 'checker)
(require 'code)
(require 'use-eglot)
;; (require 'use-lsp)
;; (require 'use-lsp-bridge)
(require 'langs)
(require 'tools)
(require 'ai)
(require 'macos)
