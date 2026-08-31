;;; -*- lexical-binding: t; -*-

(setq completion-cycle-threshold 3
      tab-always-indent 'complete
      set-mark-command-repeat-pop t)

(defun my/savehist-strip-kill-ring-properties ()
  "Save plain strings in `kill-ring' before persisting history."
  (setq kill-ring
        (mapcar #'substring-no-properties
                (cl-remove-if-not #'stringp kill-ring))))

(defun my/recenter-after-save-place (&rest _)
  "Recenter after `save-place-mode' restores point."
  (when buffer-file-name
    (ignore-errors (recenter))))

(use-package vertico
  :init
  (vertico-mode)
  :config
  ;; Enable vertico-multiform
  (vertico-multiform-mode)

  ;; Configure the display per command.
  ;; Use a buffer with indices for imenu
  ;; and a flat (Ido-like) menu for M-x.
  (setq vertico-multiform-commands
        '((consult-imenu buffer indexed)
          ;; (execute-extended-command unobtrusive)
          (consult-outline buffer ,(lambda (_) (text-scale-set -1)))
          ))

  ;; Configure the display per completion category.
  ;; Use the grid display for files and a buffer
  ;; for the consult-grep commands.
  (setq vertico-multiform-categories
        '((file grid)
          (consult-grep buffer)))
  )

(use-package vertico-directory
  :after vertico
  :ensure nil
  ;; More convenient directory navigation commands
  :bind (:map vertico-map
              ("RET" . vertico-directory-enter)
              ("DEL" . vertico-directory-delete-char)
              ("M-DEL" . vertico-directory-delete-word))
  ;;; Tidy shadowed file names
  :hook (rfn-eshadow-update-overlay . vertico-directory-tidy))

(use-package savehist
  :ensure nil
  :init
  (setq savehist-additional-variables
        '(search-ring regexp-search-ring kill-ring))
  (savehist-mode)
  :config
  (add-hook 'savehist-save-hook #'my/savehist-strip-kill-ring-properties))

(use-package saveplace
  :ensure nil
  :init
  (save-place-mode 1)
  :config
  (advice-add 'save-place-find-file-hook :after #'my/recenter-after-save-place))

(use-package re-builder
  :ensure nil
  :custom
  (reb-re-syntax 'string))

(use-package ffap
  :ensure nil
  :custom
  (ffap-machine-p-known 'reject))

(use-package orderless
  :init
  (setq completion-styles '(orderless partial-completion basic)))

(use-package marginalia
  :init
  (marginalia-mode))

;; TODO: add meaningful bindings
;; (with-eval-after-load 'isearch
;; 	(define-key isearch-mode-map (kbd "s-e") nil))
(use-package embark
  :bind
  ("s-." . embark-act)
  ("s-;" . embark-dwim)
  ("s-e" . embark-export)
  ("C-h B" . embark-bindings))

(use-package embark-consult
  :after (consult embark)
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

(use-package wgrep
  :ensure t
  :config
  (setq wgrep-auto-save-buffer t)
  (setq wgrep-enable-key "r"))

(use-package consult
  :config
  (setq consult-project-root-function #'projectile-project-root)
  (defhydra hydra-register (:hint nil)
    "Register"
    ("r" consult-register "list" :color blue)
    ("s" consult-register-store "store" :color blue)
    ("l" consult-register-load "load" :color blue)
    ("q" "quit" nil))
  (evil-define-key nil 'global
    (kbd "<leader> r") '("register" . hydra-register/body))

  (evil-define-key nil 'global
    ;; (kbd "M-r") 'consult-register
    (kbd "M-R") 'consult-register-store
    )
  )

;; Find config example [[https://github.com/minad/cape][here]].
(use-package cape
  :init
  ;; Add `completion-at-point-functions', used by `completion-at-point'.
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-history)
  (add-to-list 'completion-at-point-functions #'cape-emoji)
  )

(use-package corfu
	;; :disabled (featurep 'lsp-bridge)
  :custom
  (corfu-cycle t)
  (corfu-auto t)
  :init
  (global-corfu-mode)
  (corfu-history-mode)
  (corfu-popupinfo-mode) ; Popup completion info
  :bind (:map corfu-map
              ("M-SPC"      . corfu-insert-separator)
              ;; ("TAB"        . corfu-next)
              ;; ([tab]        . corfu-next)
              ;; ("S-TAB"      . corfu-previous)
              ;; ([backtab]    . corfu-previous)
              ("S-<return>" . corfu-insert)
              ("RET"        . corfu-insert))
  )

;; (evil-define-key 'insert corfu-map
;;   (kbd "TAB") 'corfu-next
;;   (kbd "[tab]") 'corfu-next
;;   (kbd "S-TAB") 'corfu-previous
;;   (kbd "[backtab]") 'corfu-previous)

(use-package corfu-popupinfo
  :after corfu
  :ensure nil
  :init
  (corfu-popupinfo-mode 1))

;; (use-package corfu-echo
;;   :after corfu
;;   :straight nil
;;   :init
;;   (corfu-echo-mode 1))

(use-package dabbrev
  :ensure nil
  ;; Swap M-/ and C-M-/
  :custom
  (dabbrev-ignored-buffer-regexps '("\\.\\(?:pdf\\|jpe?g\\|png\\)\\'")))

(evil-define-key 'normal 'global
  (kbd "M-/") 'dabbrev-completion
  (kbd "C-M-/") 'dabbrev-expand)

(use-package dired
  :ensure nil
  :init
  (setq
   dired-dwim-target t
   ;; don't prompt to revert, just do it
   dired-auto-revert-buffer #'dired-buffer-stale-p
   ;; Always copy/delete recursively
   dired-recursive-copies  'always
   dired-recursive-deletes 'top
   auto-revert-remote-files nil
   ;; Ask whether destination dirs should get created when copying/removing files.
   dired-create-destination-dirs 'ask
   dired-listing-switches "-alh")

  )

(with-eval-after-load 'dired
	(evil-collection-define-key 'normal 'dired-mode-map
		"a" '+macos-open-with))

(use-package casual-dired
  :disabled t
  :config
  (evil-define-key 'normal dired-mode-map (kbd "?") 'casual-dired-tmenu))

;; (use-package dired-preview
;;   :after dired
;;   :hook (dired-mode . dired-preview-mode)
;;   :custom (dired-preview-delay 0))

(use-package diredfl)

;; (general-define-key
;;    :keymaps '(wdired-mode-map local) "M-s" 'wdired-finish-edit)

(evil-define-key 'normal wdired-mode-map (kbd "M-s") 'wdired-finish-edit)

;; search
(use-package anzu
  :hook (after-init . global-anzu-mode))

(use-package evil-anzu
  :demand t
  :after evil
  :config
  (require 'evil-anzu))

;; remember notes
(setq initial-buffer-choice 'remember-notes
      remember-data-file my/now-file
      remember-notes-initial-major-mode 'org-mode
      remember-notes-auto-save-visited-file t)

;; find file TODO: assign keys
(use-package affe
  :config
  (consult-customize affe-grep :preview-key (kbd "M-."))
  ;; -*- lexical-binding: t -*-
  ;; (defun affe-orderless-regexp-compiler (input _type _ignorecase)
  ;;   (setq input (orderless-pattern-compiler input))
  ;;   (cons input (apply-partially #'orderless--highlight input)))
  ;; (setq affe-regexp-compiler #'affe-orderless-regexp-compiler)
  )

(use-package bufler
  :config
  (evil-define-key 'normal bufler-list-mode-map
    "," 'hydra:bufler/body
    "RET" 'bufler-list-buffer-switch
    "SPC" 'bufler-list-buffer-peek
    "d" 'bufler-list-buffer-kill)
  )

(use-package crux
  :commands crux-open-with)

(xterm-mouse-mode t)

;; (use-package persp-mode
;;   :config
;;   (persp-mode))

;; (use-package perspective
;;   :bind (("C-x C-b" . persp-list-buffers))
;;   :custom
;;   (persp-mode-prefix-key (kbd "C-c M-p"))
;;   :init
;;   (persp-mode))

;; (use-package tabspaces
;;   :vc (:fetcher github :repo mclear-tools/tabspaces)
;;   :hook (after-init . tabspaces-mode) ;; use this only if you want the minor-mode loaded at startup.
;;   :commands (tabspaces-switch-or-create-workspace
;;               tabspaces-open-or-create-project-and-workspace)
;;   :custom
;;   (tabspaces-use-filtered-buffers-as-default t)
;;   (tabspaces-default-tab "Default")
;;   (tabspaces-remove-to-default t)
;;   (tabspaces-include-buffers '("*scratch*"))
;;   (tabspaces-initialize-project-with-todo t)
;;   (tabspaces-todo-file-name "project-todo.org")
;;   ;; sessions
;;   (tabspaces-session t)
;;   (tabspaces-session-auto-restore t))

;; Filter Buffers for Consult-Buffer

;; (with-eval-after-load 'consult
;;   ;; hide full buffer list (still available with "b" prefix)
;;   (consult-customize consult--source-buffer :hidden t :default nil)
;;   ;; set consult-workspace buffer list
;;   (defvar consult--source-workspace
;;     (list :name     "Workspace Buffers"
;;       :narrow   ?w
;;       :history  'buffer-name-history
;;       :category 'buffer
;;       :state    #'consult--buffer-state
;;       :default  t
;;       :items    (lambda () (consult--buffer-query
;;                              :predicate #'tabspaces--local-buffer-p
;;                              :sort 'visibility
;;                              :as #'buffer-name)))

;;     "Set workspace buffer list for consult-buffer.")
;;   (add-to-list 'consult-buffer-sources 'consult--source-workspace))

(use-package treemacs
  :config
  ;; (set-face-background 'treemacs-window-background-face "#1e1e1e")
  ;; (set-face-background 'treemacs-hl-line-face "#535353")
  (treemacs-follow-mode t)
	(treemacs-project-follow-mode t)
	(setq treemacs-project-follow-cleanup t)
  ;; (setq treemacs-no-png-images t)
  )

(use-package treemacs-evil
  :after (treemacs evil))

(use-package treemacs-projectile
  :after (treemacs projectile))

(use-package treemacs-all-the-icons
  :after (treemacs all-the-icons)
  :config
  (treemacs-load-theme "all-the-icons"))


(use-package bookmark+
  :vc (:url "https://github.com/emacsmirror/bookmark-plus" :rev :newest)
  :config
  (defhydra hydra-bm (:hint nil)
    "Bookmarks"
    ("l" list-bookmarks "list bookmarks" :color blue)
    ("m" consult-bookmark "find bookmark" :color blue)
    ("s" bookmark-set "set bookmark" :color blue)
    ("L" bmkp-url-target-set "set link" :color blue)
    ("q" "quit" nil))
  (evil-define-key nil 'global
    (kbd "<leader> m") '("bookmarks" . hydra-bm/body))
  )

(use-package avy
	;; :disabled t
  :config
  (evil-define-key nil 'global
		(kbd "<leader> SPC") 'avy-goto-char-timer))

(use-package consult-omni
  :disabled t
  :vc (consult-omni :url "https://github.com/armindarvish/consult-omni"
                    :lisp-dir "sources")

  ;; :vc (:fetcher github :repo armindarvish/consult-omni)
  :load-path "~/.config/emacs/elpa/consult-omni/sources/"
  :after consult
  :config
  (require 'consult-omni-sources)
  (setq consult-omni-sources-modules-to-load '(consult-omni-github consult-omni-wikipedia))
  (consult-omni-sources-load-modules)
  ;; (consult-customize consult-omni :preview-key (kbd "M-."))
  )

(use-package vertico-posframe
  :disabled t
  :after vertico
  :custom
  (vertico-posframe-parameters '((left-fringe . 8) (right-fringe . 8)))
  :config
  (vertico-posframe-mode 1))

(use-package harpoon
  :config
  ;; TODO: add keybindings
  (evil-define-key nil 'global
    (kbd "<leader> j") 'harpoon-quick-menu-hydra
    (kbd "<leader> 1") 'harpoon-go-to-1
    (kbd "<leader> 2") 'harpoon-go-to-2
    (kbd "<leader> 3") 'harpoon-go-to-3
    (kbd "<leader> 4") 'harpoon-go-to-4
    (kbd "<leader> 5") 'harpoon-go-to-5)
  )

(defun my/tab-dwim ()
  "Do what I mean: yasnippet > completion > indent."
  (interactive)
  (cond
   ;; Expand snippet if possible
   ((bound-and-true-p yas-minor-mode)
    (or (yas-expand)
        (completion-at-point)
        (indent-for-tab-command)))
   (t
    (completion-at-point))))

(global-set-key (kbd "TAB") #'my/tab-dwim)

(provide 'navigation)
