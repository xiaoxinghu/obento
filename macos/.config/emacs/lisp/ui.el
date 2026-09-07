;;; -*- lexical-binding: t; -*-

(add-to-list 'default-frame-alist '(ns-transparent-titlebar . t))
(add-to-list 'default-frame-alist '(ns-appearance . dark))

(scroll-bar-mode -1)
;; (menu-bar-mode -1)
(tool-bar-mode -1)
(blink-cursor-mode -1)
(fset 'yes-or-no-p 'y-or-n-p)
;; (global-display-line-numbers-mode 1)
(add-hook 'prog-mode-hook (lambda() (display-line-numbers-mode 1)))
(setq display-line-numbers-type 'relative)
(setq inhibit-startup-screen t)
(setq backup-by-copying t)
(setq ring-bell-function 'ignore)
(setq-default tab-width 2)
;; https://emacs.stackexchange.com/questions/41886/html-mail-background-has-same-color-as-text
(setq shr-color-visible-luminance-min 80)

;; set transparency
;; (set-frame-parameter nil 'alpha-background 85) ; Adjust 85 to your desired opacity (0-100)
;; (add-to-list 'default-frame-alist '(alpha-background . 85)) ; Adjust 85 to your desired opacity

(set-frame-parameter (selected-frame) 'alpha-background 85)
(add-to-list 'default-frame-alist '(alpha-background . 85))
;; (set-frame-parameter (selected-frame) 'alpha '(55 55))
;; (add-to-list 'default-frame-alist '(alpha 55 55))

;; ediff
(setq ediff-split-window-function 'split-window-horizontally)
(setq ediff-window-setup-function 'ediff-setup-windows-plain)

;; (setq pixel-scroll-precision-large-scroll-height 5.0)

;; tab-bar
(setq
 tab-bar-close-button-show nil
 tab-bar-show 1
 tab-bar-new-tab-choice "*scratch*"
 )
(tab-bar-mode t)

;; (setq tab-bar-auto-width nil)
;; (setq tab-bar-tab-name-function 'tab-bar-tab-name-truncated)
;; (global-tab-line-mode -1)
;; (tab-line-mode -1)

(let* ((candidates '("JetBrainsMono Nerd Font-17" "Hack Nerd Font-17" "Fira Code-17"))
       (chosen (seq-find (lambda (n) (member n (font-family-list))) candidates "JetBrainsMono Nerd Font-17")))
  (cl-pushnew
   (cons 'font chosen)
   default-frame-alist
   :key #'car :test #'eq))

(use-package all-the-icons
  :if (display-graphic-p))

(use-package mixed-pitch
  :hook
  ((org-mode md-mode) . mixed-pitch-mode)
  :config
  (dolist (face '(md-render-inline-code md-render-source-block
																				md-render-source-block-language))
    (add-to-list 'mixed-pitch-fixed-pitch-faces face)))


(defun my/prose-mode ()
  "Set comfortable display defaults for prose buffers only."
  (visual-line-mode 1)
  (setq-local line-spacing 0.2))

(defun my/prose-heading-faces ()
  "Give Org and Markdown headings a publication-like hierarchy."
  (dolist (heading '((1 . 1.6) (2 . 1.35) (3 . 1.2)
                     (4 . 1.1) (5 . 1.05) (6 . 1.0)))
    (dolist (face (list (intern (format "org-level-%d" (car heading)))
                        (intern (format "md-render-header-%d" (car heading)))))
      (when (facep face)
        (set-face-attribute face nil
                            :family "SF Pro Text"
                            :height (cdr heading)
                            :weight 'bold)))))

(add-hook 'org-mode-hook #'my/prose-mode)
(add-hook 'md-mode-hook #'my/prose-mode)
(add-hook 'org-mode-hook #'my/prose-heading-faces)
(add-hook 'md-mode-hook #'my/prose-heading-faces)

;; Keep prose readable while preserving alignment for code and tables.
(set-face-attribute 'variable-pitch nil :family "SF Pro Text" :height 1.1)
(set-face-attribute 'fixed-pitch nil :family "JetBrainsMono Nerd Font")

(use-package doom-modeline
	;; :disabled t
  :init (doom-modeline-mode 1)
  :custom ((doom-modeline-workspace-name t))
  )

(use-package nyan-mode
  :vc (:url "https://github.com/TeMPOraL/nyan-mode" :rev :newest)
  :demand t
  :config
  (nyan-mode 1))

(use-package hl-line ; built in
  :ensure nil
  :hook ((prog-mode text-mode conf-mode) . hl-line-mode)
  :config
  ;;; I don't need hl-line showing in other windows. This also offers a small
  ;;; speed boost when buffer is displayed in multiple windows.
  (setq hl-line-sticky-flag nil
        global-hl-line-sticky-flag nil))

(use-package modus-themes
  ;; :disabled t
  :init
  ;; Set theme vars immediately so the appearance-change hook works
  ;; even before modus-themes is explicitly loaded.
  (setq my/dark-theme 'modus-vivendi-tinted
        my/light-theme 'modus-operandi)

	:config
	(setq
	 modus-themes-custom-auto-reload nil
	 modus-themes-to-toggle '(modus-operandi modus-vivendi)
	 modus-themes-to-rotate modus-themes-items
	 modus-themes-mixed-fonts t
	 modus-themes-variable-pitch-ui t
	 modus-themes-italic-constructs t
	 modus-themes-bold-constructs t
	 modus-themes-completions '((t . (bold)))
	 modus-themes-prompts '(bold)
	 ;; modus-themes-headings
	 ;; '((agenda-structure . (variable-pitch light 2.2))
	 ;; 	 (agenda-date . (variable-pitch regular 1.3))
	 ;; 	 (t . (regular 1.15)))
	 )
	)

(use-package ef-themes
  :disabled t
  :config
  (setq ef-themes-to-toggle '(ef-frost ef-bio))
  (load-theme 'ef-bio :no-confirm))

(use-package year-1984-theme
  :disabled t
  :config
  ;; (load-theme 'year-1984 t)
	(setq my/light-theme 'year-1984)
	)

(use-package doric-themes
  :disabled t
  :demand t
  :config
  ;; These are the default values.
  (setq doric-themes-to-toggle '(doric-light doric-obsidian))
  (setq doric-themes-to-rotate doric-themes-collection)

  (doric-themes-select 'doric-light)

  ;; ;; To load a random theme instead, use something like one of these:
  ;;
  ;; (doric-themes-load-random)
  ;; (doric-themes-load-random 'light)
  ;; (doric-themes-load-random 'dark)

  ;; ;; For optimal results, also define your preferred font family (or use my `fontaine' package):
  ;;
  ;; (set-face-attribute 'default nil :family "Aporetic Sans Mono" :height 160)
  ;; (set-face-attribute 'variable-pitch nil :family "Aporetic Sans" :height 1.0)
  ;; (set-face-attribute 'fixed-pitch nil :family "Aporetic Sans Mono" :height 1.0)

  :bind
  (("<f5>" . doric-themes-toggle)
   ("C-<f5>" . doric-themes-select)
   ("M-<f5>" . doric-themes-rotate)))

(use-package catppuccin-theme
  :disabled t
  :config
  (setq catppuccin-flavor 'mocha) ;; frappe or 'latte, 'macchiato, or 'mocha
  (load-theme 'catppuccin t))

(use-package gruvbox-theme
	:disabled t
	:config
	(load-theme 'gruvbox-dark-medium t))

(use-package nord-theme
	:disabled t
	:config
	(load-theme 'nord t))

(use-package zenburn-theme
	:disabled t
  :config
  (load-theme 'zenburn t))

(use-package doom-themes
  :disabled t
  :config
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t
        doom-themes-padded-modeline nil)
  (load-theme 'doom-zenburn t)
  ;; Enable flashing mode-line on errors
  (doom-themes-visual-bell-config)
  ;; Enable custom neotree theme (all-the-icons must be installed!)
  (doom-themes-neotree-config)
  ;; or for treemacs users
  (setq doom-themes-treemacs-theme "doom-atom") ; use "doom-colors" for less minimal icon theme
  (doom-themes-treemacs-config)
  ;; Corrects (and improves) org-mode's native fontification.
  (doom-themes-org-config))

(use-package solaire-mode
  :requires doom-themes
  :config
  (solaire-global-mode +1))

(defun my/toggle-theme ()
  "Load theme, taking current system APPEARANCE into consideration."
  (mapc #'disable-theme custom-enabled-themes)
  (let ((appearance (plist-get (mac-application-state) :appearance)))
    (cond ((equal appearance "NSAppearanceNameAqua")
           (load-theme my/light-theme :no-confirm))
          ((equal appearance "NSAppearanceNameDarkAqua")
           (load-theme my/dark-theme :no-confirm)))))

;; (add-hook 'after-init-hook 'my/toggle-theme)
;; (add-hook 'mac-effective-appearance-change-hook 'my/toggle-theme)

(defun my/apply-theme (appearance)
  "Load theme, taking current system APPEARANCE into consideration."
  (mapc #'disable-theme custom-enabled-themes)
  (pcase appearance
    ('light (load-theme my/light-theme t))
    ('dark (load-theme my/dark-theme t))))

(add-hook 'ns-system-appearance-change-functions #'my/apply-theme)

;; scrolling
(setq mac-redisplay-dont-reset-vscroll t
      mac-mouse-wheel-smooth-scroll nil)

(use-package spacious-padding
	:disabled t
  :hook (after-init . spacious-padding-mode)
  :config
  (setq spacious-padding-widths
        '( :internal-border-width 20
           :header-line-width 4
           :mode-line-width 8
           :tab-width 4
           :right-divider-width 1
           :scroll-bar-width 8
           :fringe-width 10))
  ;; Subtle mode line for modern appearance
  (setq spacious-padding-subtle-mode-line
        `( :mode-line-active 'default
           :mode-line-inactive vertical-border)))

(use-package nerd-icons)

(provide 'ui)
