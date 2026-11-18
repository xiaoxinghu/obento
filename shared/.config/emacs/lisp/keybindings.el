;;; -*- lexical-binding: t; -*-

(global-set-key (kbd "M-c") nil)

(use-package evil
  :demand t
  :init
  ;; (setq evil-want-C-u-scroll t)
  :custom
  (evil-want-keybinding nil)
  ;; (evil-want-minibuffer t)

  :config
  (evil-mode 1)
	(evil-set-leader 'normal (kbd "SPC"))
	(evil-set-leader 'normal (kbd ",") t)
  (evil-set-undo-system 'undo-redo)
  (define-key evil-motion-state-map (kbd "C-i") 'evil-jump-forward)
  )

;; (with-eval-after-load 'evil-maps
;;   (define-key evil-motion-state-map (kbd "RET") nil))

(use-package evil-collection
  ;; once idle: it sets up every mode already loaded, so nothing is missed
  :defer 1
  :init
  (setq forge-add-default-bindings nil)
  :config
  (evil-collection-init))

(use-package evil-surround
  :demand t
  :after evil
  :config
  (global-evil-surround-mode 1))

(use-package evil-commentary
  :demand t
  :after evil
  :config
  (evil-commentary-mode 1)
  ;; Keep gc for comments; don't claim the desktop's Super shortcut.
  (keymap-unset evil-commentary-mode-map "s-/" t))

(use-package evil-snipe
  :demand t
  :after evil
	:config
  (evil-snipe-mode 1)
  (evil-snipe-override-mode 1)
	(add-hook 'magit-mode-hook 'turn-off-evil-snipe-override-mode))


(use-package which-key
  :ensure nil
  :defer 1
  :config
  (which-key-mode 1))

(use-package hydra
  :demand t)

(evil-define-key 'normal 'global
  (kbd "<leader> :") #'execute-extended-command
  (kbd "<leader> z") '("global zoom" . (keymap))
  (kbd "<leader> z =") #'global-text-scale-adjust
  (kbd "<leader> z -") #'global-text-scale-adjust
  (kbd "<leader> z 0") #'global-text-scale-adjust)

(evil-define-key 'normal 'global
  (kbd "<leader>h") '("help" . (keymap))
  (kbd "<leader>hf") '("help" . describe-function)
  (kbd "<leader>hv") '("help" . describe-variable)
  (kbd "<leader>hk") '("help" . describe-key)
  (kbd "<leader>hc") '("help" . what-cursor-position)
  (kbd "<leader>hh") '("help" . help-for-help))

(defhydra hydra-file (:hint nil)
  "Files"
  ("f" find-file "find file" :color blue)
  ("d" dired-jump "file directory" :color blue)
  ("y" yank-location "yank location" :color blue)
  ("r" consult-recent-file "recent files" :color blue)
  ("c" (find-file (expand-file-name "init.el" user-emacs-directory)) "open config" :color blue)
  ("R" restart-emacs "restart emacs" :color blue)
  ("q" nil))

(evil-define-key 'normal 'global
  (kbd "<leader>f") 'hydra-file/body)

(defhydra hydra-buffer (:hint nil)
  "
Buffers
"
  ("b" consult-buffer "buffers" :color blue)
  ("R" revert-buffer-quick "revert" :color blue)
  ("r" my/run-current-buffer "run" :color blue)
  ("l" bufler "list" :color blue)
  ("k" kill-current-buffer "kill buffer" :color blue)
  ("s" save-some-buffers "save all buffers" :color blue)
  ("q" nil))

(evil-define-key 'normal 'global
  (kbd "<leader>b") 'hydra-buffer/body)

(evil-define-key 'normal 'global
  (kbd "<leader>s") '("search" . (keymap))
  (kbd "<leader>sm") '("jump to bookmark" . bookmark-jump)
  (kbd "<leader>sb") '("search buffer" . consult-line)
  (kbd "<leader>sB") '("search all open buffer" . consult-line-multi)
  (kbd "<leader>sp") '("search project" . consult-ripgrep))

(evil-define-key 'normal 'global
  (kbd "<leader>u") '("universal argument" . universal-argument)
  (kbd "<leader>`") '("switch" . evil-switch-to-windows-last-buffer)
  (kbd "<leader>x") '("eval" . (keymap))
  (kbd "<leader>xx") '("eval" . elisp-eval-region-or-buffer))

(evil-define-key 'normal 'global
  (kbd "<leader>st") '("TypeScript scratch" . (lambda ()
																				(interactive)
																				(my-open-scratch 'typescript))))

(defhydra hydra-toggle (:hint nil)
  "git"
  ("t" treemacs "tree" :color blue)
  ("m" toggle-frame-maximized "max" :color blue)
  ("q" nil "quit"))

(evil-define-key 'normal 'global (kbd "SPC t") 'hydra-toggle/body)

;; --- open ---
(defhydra hydra-open (:hint nil)
  "Open"
  ("o" +macos/reveal-in-finder "reveal in finder" :color blue)
  ("a" +macos-open-with "open with app" :color blue)
  ("q" nil))

(evil-define-key 'normal 'global (kbd "SPC o") '("Open" . hydra-open/body))
(evil-define-key 'normal prog-mode-map (kbd "SPC i b") '("insert shebang" . insert-shebang))

(defvar doom-escape-hook nil
  "A hook run when C-g is pressed (or ESC in normal mode, for evil users).

More specifically, when `doom/escape' is pressed. If any hook returns non-nil,
all hooks after it are ignored.")

(defun doom/escape (&optional interactive)
  "Run `doom-escape-hook'."
  (interactive (list 'interactive))
  (let ((inhibit-quit t))
    (cond ((minibuffer-window-active-p (minibuffer-window))
           ;; quit the minibuffer if open.
           (when interactive
             (setq this-command 'abort-recursive-edit))
           (abort-recursive-edit))
					;; Run all escape hooks. If any returns non-nil, then stop there.
					((run-hook-with-args-until-success 'doom-escape-hook))
					;; don't abort macros
					((or defining-kbd-macro executing-kbd-macro) nil)
					;; Back to the default
					((unwind-protect (keyboard-quit)
						 (when interactive
							 (setq this-command 'keyboard-quit)))))))

(global-set-key [remap keyboard-quit] #'doom/escape)

(with-eval-after-load 'eldoc
  (eldoc-add-command 'doom/escape))

(provide 'keybindings)
