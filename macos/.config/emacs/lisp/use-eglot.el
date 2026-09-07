;;; -*- lexical-binding: t; -*-

(defun my/eglot-ensure ()
  "Like `eglot-ensure', but never root a server at $HOME.
A stray file outside a project makes $HOME the project root, and the
server then asks to watch every file under it.  See
https://github.com/joaotavora/eglot/issues/1258"
  (let ((root (or (ignore-errors (project-root (project-current)))
                  default-directory)))
    (if (file-equal-p root "~/")
        (message "Eglot not started: %s is not in a project" buffer-file-name)
      (eglot-ensure))))

;; Eglot's default code-action indicator probes several Unicode glyphs while
;; it is first loaded.  On macOS, the first `internal-char-font' lookup can
;; take seconds, so do that work once after startup while Emacs is idle.
(defun my/eglot-warm-font-cache ()
  "Warm the graphical font cache used by Eglot's default indicator."
  (when (display-graphic-p)
    (char-displayable-p ?↯)))

(defun my/eglot-schedule-font-cache-warmup ()
  "Schedule Eglot's font-cache warm-up after startup."
  (run-with-idle-timer 0 nil #'my/eglot-warm-font-cache))

(add-hook 'after-init-hook #'my/eglot-schedule-font-cache-warmup)

(use-package eglot
  :ensure nil
  :hook
  ((
    typescript-mode
    tsx-ts-mode
    web-mode
    js2-mode
    js-mode
    yaml-mode
    python-mode
    js-ts-mode
    typescript-ts-mode
    yaml-ts-mode
    svelte-mode
    svelte-ts-mode
    c-ts-mode
    c++-ts-mode
    c-or-c++-ts-mode
    ) . my/eglot-ensure)
  :custom
  (eglot-confirm-server-initiated-edits nil)
  :config
	;; keybinds
	(evil-define-key 'normal 'global (kbd "M-.") 'eglot-code-action-quickfix)
	(define-key evil-normal-state-map "gi" 'eglot-find-implementation)

  (defun my/eglot-organize-imports ()
    (interactive)
    (if (derived-mode-p major-mode #'typescript-ts-base-mode)
        (seq-do
         (lambda (kind) (interactive)
           (ignore-errors
             (eglot-code-actions (buffer-end 0) (buffer-end 1) kind t)))
         ;; https://github.com/typescript-language-server/typescript-language-server#code-actions-on-save
         (list
          "source.addMissingImports.ts"
          "source.fixAll.ts"
          ;; "source.removeUnused.ts"
          "source.addMissingImports.ts"
          "source.removeUnusedImports.ts"
          ;; "source.sortImports.ts"
          ;; "source.organizeImports.ts"
          ))
      (funcall-interactively #'eglot-code-action-organize-imports)))

  (add-to-list
   'eglot-server-programs
   `(astro-mode . ("astro-ls" "--stdio")))

	(add-to-list 'eglot-server-programs '(svelte-ts-mode . ("svelteserver" "--stdio")))

  (add-to-list 'eglot-server-programs
               '(markdown-mode . ("remark-language-server" "--stdio")))

  ;; (defclass eglot-deno (eglot-lsp-server) ()
  ;;   :documentation "A custom class for deno lsp.")

  ;; (cl-defmethod eglot-initialization-options ((server eglot-deno))
  ;;   "Passes through required deno initialization options"
  ;;   (list :enable t
  ;;         :lint t :unstable t))

	;; deno.documentPreloadLimit
	;; (cl-defmethod eglot-initialization-options ((server eglot-deno))
  ;;   "Passes through required deno initialization options"
  ;;   (list
  ;;    :enable t
  ;;    :unstable t
	;; 	 :deno
	;; 	 (:documentPreloadLimit 10000)
  ;;    :typescript
  ;;    (:inlayHints
  ;;     (:variableTypes
  ;;      (:enabled t))
  ;;     (:parameterTypes
  ;;      (:enabled t)))))

  ;; (add-to-list
  ;;  'eglot-server-programs
  ;;  '((js-mode js-ts-mode tsx-ts-mode (typescript-ts-mode :language-id "typescript") typescript-mode jsx-mode) . (eglot-deno "deno" "lsp"))
  ;;  )

  ;; (add-to-list
  ;;  'eglot-server-programs
  ;;  '((js-mode js-ts-mode tsx-ts-mode typescript-ts-mode typescript-mode jsx-mode) "deno" "lsp")
  ;;  )

  (add-to-list
   'eglot-server-programs
   '(((js-mode :language-id "javascript")
      (js-ts-mode :language-id "javascript")
      (tsx-ts-mode :language-id "typescriptreact")
      (typescript-ts-mode :language-id "typescript")
      (typescript-mode :language-id "typescript")
      (jsx-mode :language-id "javascriptreact"))
     "sh" "-c" "exec \"$(mise where npm:typescript)\"/node_modules/.bin/tsc --lsp --stdio"
     :initializationOptions
     (:preferences
      (
       ;; https://github.com/microsoft/TypeScript/blob/main/src/server/protocol.ts#L3410-L3539
       :disableSuggestions                                    :json-false     ;; boolean
       :quotePreference                                       "single"        ;; "auto" | "double" | "single"
       :includeCompletionsForModuleExports                    t               ;; boolean
       :includeCompletionsForImportStatements                 t               ;; boolean
       :includeCompletionsWithSnippetText                     t               ;; boolean
       :includeCompletionsWithInsertText                      t               ;; boolean
       :includeAutomaticOptionalChainCompletions              t               ;; boolean
       :includeCompletionsWithClassMemberSnippets             t               ;; boolean
       :includeCompletionsWithObjectLiteralMethodSnippets     t               ;; boolean
       :useLabelDetailsInCompletionEntries                    t               ;; boolean
       :allowIncompleteCompletions                            t               ;; boolean
       :importModuleSpecifierPreference                       "shortest"      ;; "shortest" | "project-relative" | "relative" | "non-relative"
       :importModuleSpecifierEnding                           "minimal"       ;; "auto" | "minimal" | "index" | "js"
       :allowTextChangesInNewFiles                            t               ;; boolean
       ;; :lazyConfiguredProjectsFromExternalProject                          ;; boolean
       :providePrefixAndSuffixTextForRename                   t               ;; boolean
       :provideRefactorNotApplicableReason                    :json-false     ;; boolean
       :allowRenameOfImportPath                               t               ;; boolean
       ;; :includePackageJsonAutoImports                                      ;; "auto" | "on" | "off"
       :jsxAttributeCompletionStyle                           "auto"          ;; "auto" | "braces" | "none"
       :displayPartsForJSDoc                                  t               ;; boolean
       :generateReturnInDocTemplate                           t               ;; boolean
       :includeInlayParameterNameHints                        "none"           ;; "none" | "literals" | "all"
       ;; :includeInlayParameterNameHintsWhenArgumentMatchesName t               ;; boolean
       ;; :includeInlayFunctionParameterTypeHints                t               ;; boolean,
       ;; :includeInlayVariableTypeHints                         t               ;; boolean
       ;; :includeInlayVariableTypeHintsWhenTypeMatchesName      t               ;; boolean
       ;; :includeInlayPropertyDeclarationTypeHints              t               ;; boolean
       ;; :includeInlayFunctionLikeReturnTypeHints               t               ;; boolean
       :includeInlayEnumMemberValueHints                      t               ;; boolean
       ;; :autoImportFileExcludePatterns                                      ;; string[]
       ;; :organizeImportsIgnoreCase                                          ;; "auto" | boolean
       ;; :organizeImportsCollation                                           ;; "ordinal" | "unicode"
       ;; :organizeImportsCollationLocale                                     ;; string
       ;; :organizeImportsNumericCollation                                    ;; boolean
       ;; :organizeImportsAccentCollation                                     ;; boolean
       ;; :organizeImportsCaseFirst                                           ;; "upper" | "lower" | false
       :disableLineTextInReferences                           :json-false))
		 )
   )

  ;; File watching.  On macOS every watch costs a file descriptor (kqueue),
  ;; and a directory watch cannot even see edits to files inside it, so
  ;; Eglot-side watching is both expensive and half-blind.  typescript-go,
  ;; tsserver and pyright all fall back to their own native FSEvents
  ;; watching when the client doesn't advertise the capability.
  ;; https://github.com/joaotavora/eglot/issues/1258
  ;; https://github.com/joaotavora/eglot/issues/1568
  (cl-defmethod eglot-client-capabilities :around (_server)
    (let ((caps (cl-call-next-method)))
      (plist-put (plist-get caps :workspace)
                 :didChangeWatchedFiles '(:dynamicRegistration :json-false))
      caps))
  ;; Backstop for servers that register watchers anyway.  Both are defvars,
  ;; so `:custom' can't set them.  Upstream defaults are t and 10000.
  (setq eglot-watch-files-outside-project-root nil
        eglot-max-file-watches 2000)

  ;; `tsc --lsp' dynamically registers workspace/didChangeConfiguration, which
  ;; Eglot has no use for.  Accept it silently instead of warning on every file.
  (cl-defmethod eglot-register-capability
    (_server (_method (eql workspace/didChangeConfiguration)) _id &rest _params)
    nil)
  (cl-defmethod eglot-unregister-capability
    (_server (_method (eql workspace/didChangeConfiguration)) _id &rest _params)
    nil)

	(add-to-list 'eglot-server-programs '((c++-mode c-mode) "clangd"))
  (defhydra hydra-eglot (:hint nil)
    "language"
    ("a" eglot-code-actions "actions" :color blue)
    ("e" flymake-show-buffer-diagnostics "errors" :color blue)
    ("s" consult-imenu "symbols" :color blue)
    ("r" xref-find-references "reference" :color blue)
    ("R" eglot-reconnect "reconnect" :color blue)
    ("o" eglot-code-action-organize-imports "org imports" :color blue)
    ("j" flymake-goto-next-error "next error" :color red)
    ("k" flymake-goto-prev-error "next error" :color red)
    ("q" nil "quit"))

  ;; (general-nmap :keymaps 'eglot-mode-map "gR" 'eglot-rename)
  ;; (leader! :keymaps 'eglot-mode-map "." 'eglot-code-action-quickfix)
  ;; (leader! :keymaps 'eglot-mode-map "l" 'hydra-eglot/body)

  (evil-define-key 'normal 'eglot-mode-map
    "gR" 'eglot-rename
    ;; "." 'eglot-code-action-quickfix
		"K" 'eldoc-box-help-at-point
    ";" 'hydra-eglot/body)
  )

;; this makes eldoc less aggressive, fixes performance issues with large markdown-like docs
;; from language servers
(setq eldoc-echo-area-use-multiline-p nil)

(use-package eldoc-box
  ;; :hook (eglot-managed-mode . eldoc-box-hover-mode)
	:config
	;; (defun my/eldoc-box-setup-keys ()
	;; 	"Set up buffer-local keybindings in the eldoc-box buffer."
	;; 	;; `this-buffer` is the doc buffer of eldoc-box
	;; 	(local-set-key (kbd "j") #'eldoc-box-scroll-down)   ;; j scrolls *down* (because content moves up)
	;; 	(local-set-key (kbd "k") #'eldoc-box-scroll-up)
	;; 	(local-set-key (kbd "q") #'eldoc-box--hide-frame)
	;; 	;; Optionally <escape>
	;; 	(local-set-key (kbd "<escape>") #'eldoc-box--hide-frame))
	;; (add-hook 'eldoc-box-buffer-hook #'my/eldoc-box-setup-keys)

	(add-hook 'eldoc-box-buffer-hook
            (lambda ()
              (let ((map (make-sparse-keymap)))
                ;; Vim-style navigation
                (define-key map (kbd "j") #'eldoc-box-scroll-down)
                (define-key map (kbd "k") #'eldoc-box-scroll-up)
                (define-key map (kbd "q") #'eldoc-box-quit-frame)
                ;; assign to the local buffer
                (use-local-map (make-composed-keymap map (current-local-map))))))
	)

(use-package eglot-booster
  :vc (:url "https://github.com/jdtsmith/eglot-booster" :rev :newest)
	:after eglot
	:config	(eglot-booster-mode))

(use-package consult-eglot
  :after eglot)

(provide 'use-eglot)
