;;; ai.el --- AI assistant configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Configuration for various AI assistants and code completion tools in Emacs.

;;; Code:

(defun my/ai-api-key (host)
  "Return the API key for HOST from auth-source."
  (auth-source-pick-first-password :host host :user "api-key"))

;;; gptel - Primary AI interface
(use-package gptel
  :config
  ;; API key configuration
  (setq gptel-api-key (lambda () (my/ai-api-key "openai")))

  ;; Configure Claude backend
  (setq gptel-backend
        (gptel-make-anthropic "Claude"
          :key (lambda () (my/ai-api-key "claude"))))

  ;; Default settings
  (setq gptel-default-mode #'org-mode)

  ;; Custom directives for different use cases
  (setq gptel-directives
        '((rewrite . gptel--rewrite-directive-default)
          (default
           . "You are a large language model living in Emacs and a helpful assistant. Respond concisely.")
          (programming
           . "You are a large language model and a careful programmer. Provide code and only code as output without any additional text, prompt or note.")
          (writing
           . "You are a large language model and a writing assistant. Respond concisely.")
          (proofread
           . "You are a writing assistant. Respond concisely.")
          (chat
           . "You are a large language model and a conversation partner. Respond concisely.")))


  )

;; Hydra menu for quick access
(defhydra hydra-ai (:hint nil)
  "AI Commands"
  ("c" gptel "chat" :color blue)
  ("r" gptel-rewrite "rewrite" :color blue)
  ("s" gptel-send "send" :color blue)
  ("a" gptel-add "add" :color blue)
  ("?" +ai/translate "translate" :color blue)
  ("m" gptel-menu "menu" :color blue)
  ("q" nil "quit" :color blue))

;; Global keybinding for AI menu
(evil-define-key 'normal 'global
  (kbd "M-i") 'hydra-ai/body)

;;; Custom translation function
(defun +ai/translate (prompt)
  "Translate PROMPT to Chinese with explanation using gptel."
  (interactive (list (read-string "Ask: " nil)))
  (when (string= prompt "")
    (user-error "A prompt is required"))
  (unless (featurep 'gptel)
    (user-error "gptel is not available"))
  (gptel-request
	 prompt
	 :system "translate the following text into Chinese, write a one sentence explanation of the text, in Chinese"
	 :callback
	 (lambda (response info)
		 (if (not response)
				 (message "gptel-lookup failed with message: %s" (plist-get info :status))
			 (with-current-buffer (get-buffer-create "*gptel-lookup*")
				 (let ((inhibit-read-only t))
					 (erase-buffer)
					 (insert response))
				 (special-mode)
				 (display-buffer (current-buffer)
												 `((display-buffer-in-side-window)
													 (side . bottom)
													 (window-height . ,#'fit-window-to-buffer))))))))

;;; gptel-quick - Quick AI queries
(use-package gptel-quick
  :vc (:url "https://github.com/karthink/gptel-quick" :rev :newest)
  :config
  (setq gptel-quick-display nil))

;;; chatgpt-shell - Alternative AI shell interface
(use-package chatgpt-shell
  :custom
  (chatgpt-shell-streaming nil)
  (chatgpt-shell-openai-key
   (lambda ()
     (auth-source-pick-first-password :host "openai" :user "api-key")))
  (shell-maker-root-path no-littering-var-directory)

  :config
  ;; Evil mode keybindings for visual mode
  (with-eval-after-load 'evil
    (evil-define-key 'visual 'global
      (kbd "M-.") 'chatgpt-shell-proofread-region
      (kbd "M-/") 'chatgpt-shell-explain-code
      (kbd "M-RET") 'chatgpt-shell-send-region)

    (evil-define-key 'normal 'global
      (kbd "<leader> ar") 'chatgpt-shell-proofread-region)))

;;; monet - AI code editing tool
(use-package monet
  :vc (:url "https://github.com/stevemolitor/monet" :rev :newest)
  :config
  (setq monet-diff-tool #'monet-ediff-tool))

;;; eca - Editor Code Assistant
(use-package eca
  :vc (:url "https://github.com/editor-code-assistant/eca-emacs" :rev :newest))

;;; agent-shell - AI agent interaction
(use-package agent-shell
  :config
  (setq agent-shell-anthropic-claude-environment
        (agent-shell-make-environment-variables
         "ANTHROPIC_API_KEY" (auth-source-pick-first-password :host "api.anthropic.com"))))

;;; UI Configuration
(set-face-foreground 'vertical-border "gold")

;; document the config of minuet
(use-package minuet
	:init
  ;; if you want to enable auto suggestion.
  ;; Note that you can manually invoke completions without enable minuet-auto-suggestion-mode
  (add-hook 'prog-mode-hook #'minuet-auto-suggestion-mode)
	(add-hook 'minuet-active-mode-hook #'evil-normalize-keymaps)
	:bind
  (("M-y" . minuet-complete-with-minibuffer)
   ("M-i" . minuet-show-suggestion)
   ;; ("C-c m" . minuet-configure-provider)
   :map minuet-active-mode-map
   ("<tab>" . minuet-accept-suggestion)
   ("TAB" . minuet-accept-suggestion)
   ("C-<tab>" . minuet-accept-suggestion-line)
   ("M-]" . minuet-next-suggestion)
   ("M-[" . minuet-previous-suggestion)
   ("<escape>" . minuet-dismiss-suggestion))
	:config
	;; (setq minuet-provider 'openai-compatible)
	(setq minuet-provider 'openai-fim-compatible)
	(setq minuet-n-completions 1) ; recommended for Local LLM for resource saving
	(setq minuet-context-window 512)
	(plist-put minuet-openai-fim-compatible-options :end-point "http://localhost:1234/v1/completions")
	(setq minuet-provider 'gemini)
	(setf (plist-get minuet-gemini-options :api-key)
				(lambda () (my/ai-api-key "gemini")))
	(plist-put minuet-openai-compatible-options
             :model "gemini-2.0-flash")
	;; (plist-put minuet-openai-fim-compatible-options
  ;;            :model "qwen/qwen3-4b-2507")
  ;; (plist-put minuet-openai-fim-compatible-options
  ;;            :api-key "TERM")

  ;; Local endpoint for chat completions
  ;; (plist-put minuet-openai-compatible-options
  ;;            :end-point "http://localhost:1234/v1/chat/completions")

  ;; LM Studio does not require authentication.
  ;; Minuet requires a NON-EMPTY env var name, so "TERM" works.
  ;; (plist-put minuet-openai-compatible-options
  ;;            :api-key "TERM")
	;; Performance optimizations
	(setq minuet-request-timeout 10)  ; Reduced from 60 for faster failure detection
	(setq minuet-auto-suggestion-debounce-delay 0.3)  ; Wait 300ms after typing stops
	(setq minuet-auto-suggestion-throttle-delay 1.0)  ; At most one request per second

	(minuet-set-optional-options minuet-openai-compatible-options
                               :max_tokens 128)  ; Reduced from 256 for faster generation

	(minuet-set-optional-options minuet-openai-compatible-options :stream t)  ; Enable streaming


	;; (setq minuet-openai-options
	;; 			(plist-put minuet-openai-options
	;; 								 :api-key
	;; 								 (lambda ()
	;; 									 (auth-source-pick-first-password
	;; 										:host "openai"
	;; 										:user "api-key"))))
	;; (setq minuet-request-timeout 2)
	;; (setq minuet-auto-suggestion-debounce-delay 0.5)
	;; (setq minuet-auto-suggestion-throttle-delay 1.5)
	;; (minuet-set-optional-options minuet-openai-compatible-options :provider '(:sort "throughput"))
	;; (dolist (provider (list minuet-openai-options
  ;;                         minuet-codestral-options
  ;;                         minuet-openai-compatible-options
  ;;                         minuet-openai-fim-compatible-options))
  ;;   (minuet-set-optional-options provider :max_tokens 128)
  ;;   (minuet-set-optional-options provider :top_p 0.9))

	)


(provide 'ai)
