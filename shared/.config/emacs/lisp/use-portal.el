;;; -*- lexical-binding: t; -*-

;; Portal's views: WebKit and AppKit on macOS, Ghostty terminals on Linux (pgtk)
(use-package portal
  :local ("~/files/workspace/.repos/github.com/xiaoxinghu/portal"   ; macOS
          "~/workspace/.repos/github.com/xiaoxinghu/portal")        ; Linux
  :vc (:url "https://github.com/xiaoxinghu/portal" :rev :newest)
  ;; Load after the frame: portal-web loads url and browse-url.
  :defer 1
	:custom
	(portal-terminal-theme "Catppuccin Mocha")
	:config
	;; A view's buffer is in normal state while Emacs has the keyboard, so SPC
	;; leads there; i enters the app, as insert state.
	(with-eval-after-load 'portal-input
	  (evil-define-key 'normal portal-input-mode-map "i" #'portal-input-focus))
	;; Each kind of view gets its own icon, lit while the view has the keyboard.
	(with-eval-after-load 'nerd-icons
	  (dolist (icon '((portal-terminal-mode nerd-icons-devicon "nf-dev-terminal")
	                  (portal-web-mode nerd-icons-mdicon "nf-md-web")
	                  (portal-excalidraw-mode nerd-icons-mdicon "nf-md-draw")))
	    (add-to-list 'nerd-icons-mode-icon-alist
	                 (append icon '(:face portal-mode-line-focus)))))
  (with-eval-after-load 'portal-terminal-consult
    (consult-customize
     portal-terminal-consult-source
     portal-terminal-consult-project-source
     :preview-key 'any))
  (defhydra hydra-portal (:color blue :hint nil)
    "Portal"
    ("RET" my/terminal "go to terminal")
    ("T" portal-terminal-toggle "toggle quick terminal")
    ("p" portal-terminal-choose-project "project terminal")
    ("t" portal-terminal-choose "all terminals")
    ("n" portal-terminal-new "new terminal")
    ("r" portal-terminal-rename "rename terminal")
    ("z" portal-terminal-zoom "zoom terminal")
    ("i" flow-implement "implement task in herdr")
    ("m" portal-render-markdown "markdown preview")
    ("h" portal-render-html "html preview")
    ("e" portal-excalidraw "excalidraw")
    ("u" portal-open-url "open URL")
    ("q" nil "quit"))

  (defun my/terminal ()
    "Start the first terminal, jump to the only one, or choose among several.
From inside the only terminal, choose too, so a new one is a key away."
    (interactive)
    (let ((buffers (portal-terminal-buffers)))
      (cond ((null buffers) (portal-terminal-new))
            ((and (null (cdr buffers)) (not (eq (car buffers) (current-buffer))))
             (portal-terminal-select (car buffers)))
            (t (portal-terminal-choose)))))

  ;; Return focus to Emacs before using the leader.
  (evil-define-key 'normal 'global (kbd "<leader> P") #'hydra-portal/body))

(provide 'use-portal)
