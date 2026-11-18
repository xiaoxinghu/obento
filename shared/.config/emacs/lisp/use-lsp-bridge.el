;;; -*- lexical-binding: t; -*-

(use-package lsp-bridge
	:vc (:url "https://github.com/manateelazycat/lsp-bridge" :rev :newest)
  :init
  (global-lsp-bridge-mode)
	:config
	(evil-define-key 'normal 'global "K" 'lsp-bridge-popup-documentation)
	(evil-define-key 'normal 'global (kbd "M-.") 'lsp-bridge-code-action)
	(define-key evil-normal-state-map "gd" 'lsp-bridge-find-def)
	(define-key evil-normal-state-map "gi" 'lsp-bridge-find-impl)
	(define-key evil-normal-state-map "gr" 'lsp-bridge-find-references)

  (evil-define-key 'normal 'lsp-bridge-mode-map
    "gR" 'lsp-bridge-rename
    ;; "." 'eglot-code-action-quickfix
    ";" 'hydra-lsp/body)

  (defhydra hydra-lsp (:hint nil)
    "lsp"
    ("s" consult-lsp-file-symbols "symbols" :color blue)
    ("e" lsp-bridge-diagnostic-list "errors" :color blue)
    ("j" lsp-bridge-diagnostic-jump-next "next error" :color red)
    ("k" lsp-bridge-diagnostic-jump-prev "prev error" :color red)
    ("q" nil "quit"))

	)

(provide 'use-lsp-bridge)
