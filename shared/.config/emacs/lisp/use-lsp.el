;;; -*- lexical-binding: t; -*-

;; inspired by this article
;; https://www.ovistoica.com/blog/2024-7-05-modern-emacs-typescript-web-tsx-config

(use-package lsp-mode
  :diminish "LSP"
  ;; :commands lsp
  :hook ((lsp-mode . lsp-diagnostics-mode)
         (lsp-mode . lsp-enable-which-key-integration)
         ((tsx-ts-mode
           typescript-ts-mode
           svelte-mode
           svelte-ts-mode
           js-ts-mode) . lsp-deferred))
  ;; :disabled t
  :custom
  (lsp-keymap-prefix "C-c l")           ; Prefix for LSP actions
  (lsp-completion-provider :none)       ; Using Corfu as the provider
  ;; (lsp-diagnostics-provider :flymake)
  (lsp-session-file (locate-user-emacs-file ".lsp-session"))
  (lsp-log-io nil)                      ; IMPORTANT! Use only for debugging! Drastically affects performance
  (lsp-keep-workspace-alive nil)        ; Close LSP server if all project buffers are closed
  (lsp-idle-delay 0.5)                  ; Debounce timer for `after-change-function'
  ;; core
  (lsp-enable-xref t)                   ; Use xref to find references
  (lsp-auto-configure t)                ; Used to decide between current active servers
  (lsp-eldoc-enable-hover t)            ; Display signature information in the echo area
  (lsp-enable-dap-auto-configure t)     ; Debug support
  (lsp-enable-file-watchers nil)
  (lsp-enable-folding nil)              ; I disable folding since I use origami
  (lsp-enable-imenu t)
  (lsp-enable-indentation nil)          ; I use prettier
  (lsp-enable-links nil)                ; No need since we have `browse-url'
  (lsp-enable-on-type-formatting nil)   ; Prettier handles this
  (lsp-enable-suggest-server-download t) ; Useful prompt to download LSP providers
  (lsp-enable-symbol-highlighting t)     ; Shows usages of symbol at point in the current buffer
  (lsp-enable-text-document-color nil)   ; This is Treesitter's job

  (lsp-ui-sideline-show-hover nil)      ; Sideline used only for diagnostics
  (lsp-ui-sideline-diagnostic-max-lines 20) ; 20 lines since typescript errors can be quite big
  ;; completion
  (lsp-completion-enable t)
  (lsp-completion-enable-additional-text-edit t) ; Ex: auto-insert an import for a completion candidate
  (lsp-enable-snippet t)                         ; Important to provide full JSX completion
  (lsp-completion-show-kind t)                   ; Optional
  ;; headerline
  (lsp-headerline-breadcrumb-enable nil)  ; Optional, I like the breadcrumbs
  (lsp-headerline-breadcrumb-enable-diagnostics nil) ; Don't make them red, too noisy
  (lsp-headerline-breadcrumb-enable-symbol-numbers nil)
  (lsp-headerline-breadcrumb-icons-enable nil)
  ;; modeline
  (lsp-modeline-code-actions-enable nil) ; Modeline should be relatively clean
  (lsp-modeline-diagnostics-enable nil)  ; Already supported through `flycheck'
  (lsp-modeline-workspace-status-enable nil) ; Modeline displays "LSP" when lsp-mode is enabled
  (lsp-signature-doc-lines 1)                ; Don't raise the echo area. It's distracting
  (lsp-ui-doc-use-childframe t)              ; Show docs for symbol at point
  (lsp-eldoc-render-all nil)            ; This would be very useful if it would respect `lsp-signature-doc-lines', currently it's distracting
  ;; lens
  (lsp-lens-enable nil)                 ; Optional, I don't need it
  ;; semantic
  (lsp-semantic-tokens-enable nil)      ; Related to highlighting, and we defer to treesitter


  :init
  (setq lsp-use-plists t)
	(setq lsp-session-file (no-littering-expand-var-file-name "lsp-session"))

  (advice-add (if (progn (require 'json)
												 (fboundp 'json-parse-buffer))
									'json-parse-buffer
                'json-read)
							:around
							#'lsp-booster--advice-json-parse)

  (advice-add 'lsp-resolve-final-command :around #'lsp-booster--advice-final-command)

  ;; (setq lsp-keymap-prefix "C-c l")
  (defun my/lsp-mode-setup-completion ()
    (setf (alist-get 'styles (alist-get 'lsp-capf completion-category-defaults))
					'(orderless))) ;; Configure orderless
  (setq read-process-output-max (* 4 1024 1024)) ;; 4mb
  ;; https://github.com/emacs-lsp/lsp-mode/issues/2255#issuecomment-1786355147
  ;;   (defface lsp-flycheck-info-unnecessary
  ;;     '((t))
  ;;     "Face which apply to side line for symbols not used.
  ;; Possibly erroneously redundant of lsp-flycheck-info-unnecessary-face."
  ;;     :group 'lsp-ui-sideline)

  ;; :hook
  ;; ((typescript-mode . lsp)
  ;;  (web-mode . lsp)
  ;;  (typescript-ts-mode . lsp)
  ;;  (js2-mode . lsp)
  ;;  (js-mode . lsp)
  ;;  (js-ts-mode . lsp)
  ;;  (jsx-mode . lsp)
  ;;  (tsx-mode . lsp)
  ;;  (tsx-ts-mode . lsp)
  ;;  (yaml-mode . lsp)
  ;;  (yaml-ts-mode . lsp)
  ;;  (lsp-mode . lsp-enable-which-key-integration)
  ;;  (lsp-completion-mode . my/lsp-mode-setup-completion))

  :config
  (evil-define-key 'normal 'global "gD" 'lsp-find-type-definition)
  (evil-define-key 'normal 'global "gr" 'lsp-find-references)
  (evil-define-key 'normal 'global "K" 'lsp-ui-doc-glance)
  ;; (evil-define-key 'normal 'global "gR" 'lsp-rename)
  (evil-define-key 'normal 'global (kbd "M-.") 'lsp-execute-code-action)
  (evil-define-key 'normal 'lsp-mode-map
    "gR" 'lsp-rename
    ;; "." 'eglot-code-action-quickfix
    ";" 'hydra-lsp/body)

  (defhydra hydra-lsp-flymake (:hint nil)
    "lsp"
    ("s" consult-lsp-file-symbols "symbols" :color blue)
    ("e" flymake-show-buffer-diagnostics "errors" :color blue)
    ;; ("e" consult-lsp-diagnostics "errors" :color blue)
    ("r" lsp-find-references "reference" :color blue)
    ("R" lsp-rename "rename" :color blue)
    ("o" lsp-organize-imports "org imports" :color blue)
    ("j" flymake-goto-next-error "next error" :color red)
    ("k" flymake-goto-prev-error "prev error" :color red)
    ("q" nil "quit"))

  (defhydra hydra-lsp (:hint nil)
    "lsp"
    ("s" consult-lsp-file-symbols "symbols" :color blue)
    ("e" list-flycheck-errors "errors" :color blue)
    ;; ("e" consult-lsp-diagnostics "errors" :color blue)
    ("r" lsp-find-references "reference" :color blue)
    ("R" lsp-rename "rename" :color blue)
    ("o" lsp-organize-imports "org imports" :color blue)
    ("j" flycheck-next-error "next error" :color red)
    ("k" flycheck-previous-error "prev error" :color red)
    ("q" nil "quit"))


  (evil-define-minor-mode-key 'normal lsp-mode (kbd "SPC l") lsp-command-map)
  ;; (general-def 'normal lsp-mode :definer 'minor-mode
  ;;              "M-l" 'hydra-lsp/body)

  (evil-define-minor-mode-key 'normal 'lsp-mode-map
    (kbd "M-l") 'hydra-lsp/body)

  :preface
  ;; booster
  (defun lsp-booster--advice-json-parse (old-fn &rest args)
    "Try to parse bytecode instead of json."
    (or
     (when (equal (following-char) ?#)
       (let ((bytecode (read (current-buffer))))
         (when (byte-code-function-p bytecode)
           (funcall bytecode))))
     (apply old-fn args)))


  (defun lsp-booster--advice-final-command (old-fn cmd &optional test?)
    "Prepend emacs-lsp-booster command to lsp CMD."
    (let ((orig-result (funcall old-fn cmd test?)))
      (if (and (not test?)                             ;; for check lsp-server-present?
							 (not (file-remote-p default-directory)) ;; see lsp-resolve-final-command, it would add extra shell wrapper
							 lsp-use-plists
							 (not (functionp 'json-rpc-connection))  ;; native json-rpc
							 (executable-find "emacs-lsp-booster"))
					(progn
						(when-let* ((command-from-exec-path (executable-find (car orig-result))))  ;; resolve command from exec-path (in case not found in $PATH)
							(setcar orig-result command-from-exec-path))
						(message "Using emacs-lsp-booster for %s!" orig-result)
						(cons "emacs-lsp-booster" orig-result))
        orig-result)))
  )



;; (with-eval-after-load 'lsp-mode
;;   (add-hook 'lsp-mode-hook #'lsp-enable-which-key-integration))

;; (use-package lsp-completion
;;   :no-require
;;   :hook ((lsp-mode . lsp-completion-mode)))

(use-package lsp-ui
  ;; :bind
  ;; (:map lsp-ui-doc-mode-map
  ;;   ("<tab>" . lsp-ui-doc-focus-frame)
  ;;   ("<esc>" . lsp-ui-doc-hide)
  ;;   )
  :config
  (setq lsp-ui-doc-enable t
				evil-lookup-func #'lsp-ui-doc-glance ; Makes K in evil-mode toggle the doc for symbol at point
				lsp-ui-doc-show-with-cursor nil      ; Don't show doc when cursor is over symbol - too distracting
				lsp-ui-doc-include-signature t       ; Show signature
				lsp-ui-doc-position 'at-point)
  )

(use-package consult-lsp
  :after (lsp-mode))

;; (use-package lsp-eslint
;;   :demand t
;;   :after lsp-mode)

;; booster



(provide 'use-lsp)
