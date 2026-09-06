;;; -*- lexical-binding: t; -*-

(setq js-indent-level 2)
(add-to-list 'auto-mode-alist '("\\.[cm]js\\'" . javascript-mode))

(defun my/web-mode-hook ()
  "Hooks for Web mode."
	(web-mode-use-tabs)
  (setq web-mode-markup-indent-offset 2
        web-mode-attr-indent-offset 2
        web-mode-css-indent-offset 2
        web-mode-script-padding 2
        web-mode-code-indent-offset 2))

(use-package web-mode
  :mode (("\\.html?\\'" . web-mode)
         ("\\.css\\'"   . web-mode)
         ;; ("\\.[t|j]sx\\'"  . jsx-mode)
         )
  :custom
  (web-mode-markup-indent-offset 2)
  (web-mode-css-indent-offset 2)
  (web-mode-code-indent-offset 2)
  (web-mode-script-padding 2)
  (css-indent-offset 2)
	:hook (web-mode . my/web-mode-hook)
  :config
	;; (web-mode-use-tabs)
  ;; https://github.com/emacs-typescript/typescript.el/issues/4#issuecomment-947866123
  (define-derived-mode jsx-mode web-mode "jsx")
  (setq web-mode-content-types-alist '(("jsx" . "\\.js[x]?\\'")))
  (with-eval-after-load 'lsp-mode
    (add-to-list 'lsp--formatting-indent-alist '(jsx-mode . js-indent-level)))
	)


;; (use-package javascript-mode
;;   :ensure nil
;;   :mode (("\\.[m|c]?js\\'" . javascript-mode))
;;   :config
;;   (setq js-indent-level 2))

(define-derived-mode astro-mode web-mode "astro")
(setq auto-mode-alist
      (append '((".*\\.astro\\'" . astro-mode))
              auto-mode-alist))

(use-package svelte-ts-mode
	;; :after eglot
	:mode "\\.svelte\\'"
	:vc (:url "https://github.com/leafOfTree/svelte-ts-mode" :rev :newest)
  :init
  (add-to-list 'treesit-language-source-alist
               '(svelte "https://github.com/tree-sitter-grammars/tree-sitter-svelte"))
  :config
  (treesit-ensure-installed 'svelte))

(use-package json-ts-mode
  :ensure nil
  :mode "\\.js\\(?:on\\|[hl]int\\(?:rc\\)?\\)\\'")

(add-to-list 'auto-mode-alist '("\\.jsonc\\'" . jsonc-mode))

(use-package yaml-mode)

(use-package csv-mode)

(use-package markdown-mode
  :mode "\\.md\\'"
  :config
  (setq markdown-command "multimarkdown")
  (unbind-key "M-p" markdown-mode-map))

(use-package mermaid-mode
  :mode "\\.mmd\\'"
  :config
  (setq mermaid-mmdc-location "docker")
  (setq mermaid-flags "run -u 1000 -v /tmp:/tmp ghcr.io/mermaid-js/mermaid-cli/mermaid-cli:9.1.6")
  )

(use-package terraform-mode
  :custom (terraform-indent-level 4))

(use-package verb)

(use-package nix-mode
  :mode "\\.nix\\'")

(use-package lua-mode
  :init
  ;; lua-indent-level defaults to 3 otherwise. Madness.
  (setq lua-indent-level 2)
  )

(use-package rustic
  :mode ("\\.rs\\'" . rustic-mode)
  :config
  (setq rustic-lsp-server 'rust-analyzer))

(provide 'langs)
