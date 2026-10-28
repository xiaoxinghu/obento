;;; -*- lexical-binding: t; -*-

(setq ad-redefinition-action 'accept)
(setq vc-follow-symlinks t)
(setq package-check-signature nil)
(setq help-window-select t)
(setq save-interprogram-paste-before-kill t)
(setq kill-do-not-save-duplicates t)
(setq use-package-always-defer t)

;; (setenv "GPG_TTY" "$(tty)")
(require 'epa-file)
(epa-file-enable)
(setenv "GPG_AGENT_INFO" nil)
(setq epg-gpg-program "/run/current-system/sw/bin/gpg")
(setq epg-pinentry-mode 'loopback)
;; (desktop-save-mode 1)

(use-package server
  :ensure nil
  :defer 1
  :config
  (unless (server-running-p)
    (server-start)))

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)

(require 'use-package)
(require 'use-package-ensure)
(setq use-package-always-ensure t)

;; `:local DIR' loads a package from my checkout when DIR exists, in place
;; of `:vc' or `:ensure'.  Without DIR and without `:vc', the package is skipped.
;; Its `;;;###autoload' cookies are honoured, as for an installed package.
(add-to-list 'use-package-keywords :local)

(defun +use-package--local-autoloads (name dir)
  "Load the autoloads of package NAME from DIR, regenerated when stale."
  (let ((file (expand-file-name (format "var/autoloads/%s-autoloads.el" name)
                                user-emacs-directory)))
    (make-directory (file-name-directory file) t)
    (loaddefs-generate dir file)
    (load file nil t)))

(defun use-package-normalize/:local (_name keyword args)
  (use-package-only-one (symbol-name keyword) args
    (lambda (_label arg)
      (if (stringp arg) arg (use-package-error ":local wants a directory")))))

(defun use-package-handler/:local (name _keyword dir rest state)
  (cond
   ((file-directory-p dir)
    (dolist (kw '(:pin :ensure :vc))
      (setq rest (use-package-plist-delete rest kw)))
    (use-package-concat
     `((add-to-list 'load-path ,(expand-file-name dir))
       (+use-package--local-autoloads ',name ,(expand-file-name dir)))
     (use-package-process-keywords name rest state)))
   ((plist-member rest :vc)
    (use-package-process-keywords name rest state))))

;; PATH and the shell's variables come from ~/.env.el, written by env.sh and
;; loaded in early-init.el, so no shell runs at startup.
(if (and (fboundp 'native-comp-available-p)
					 (native-comp-available-p))
      (progn
				(message "Native comp is available")
	  ;;; Using Emacs.app/Contents/MacOS/bin since it was compiled with
	  ;;; ./configure --prefix="$PWD/nextstep/Emacs.app/Contents/MacOS"
	  ;;; Append to path to give priority to values from ~/.env.el.
				(add-to-list 'exec-path (concat invocation-directory (file-name-as-directory "bin")) t)
				(setenv "LIBRARY_PATH" (concat (getenv "LIBRARY_PATH")
																			 (when (getenv "LIBRARY_PATH")
																				 ":")
					 ;;; This is where Homebrew puts libgccjit libraries.
																			 (car (file-expand-wildcards
																						 (expand-file-name "/opt/homebrew/opt/libgccjit/lib/gcc/*")))))
	  ;;; Only set after LIBRARY_PATH can find gcc libraries.
				(setq comp-deferred-compilation t)
				(setq comp-speed 3))
    (message "Native comp is *not* available"))


(use-package no-littering
	:demand t
	:config
	(no-littering-theme-backups)
	;; sha1 keeps names short; flattening with `!' exceeds macOS NAME_MAX on deep pnpm paths
	(setq auto-save-file-name-transforms
				`((".*" ,(no-littering-expand-var-file-name "auto-save/") sha1)))
	(let ((dir (no-littering-expand-var-file-name "lock-files/")))
		(make-directory dir t)
		(setq lock-file-name-transforms `((".*" ,dir sha1))))
	(require 'recentf)
	(add-to-list 'recentf-exclude
							 (recentf-expand-file-name no-littering-var-directory))
	(add-to-list 'recentf-exclude
							 (recentf-expand-file-name no-littering-etc-directory))
	(setq custom-file (no-littering-expand-etc-file-name "custom.el"))
	)

(recentf-mode 1)

;; this is merged into Emacs, check back when Emacs 30 is released
;; (unless (package-installed-p 'vc-use-package)
;;   (package-vc-install "https://github.com/slotThe/vc-use-package"))
;; (require 'vc-use-package)

(use-package gcmh
  :vc (:url "https://github.com/emacsmirror/gcmh" :rev :newest)
  :hook (after-init . gcmh-mode))

(use-package direnv
  :custom
  (direnv-always-show-summary nil)
  :defer 1
  :config
  (direnv-mode 1))

(use-package auth-source
	:ensure nil
	:config
	(auth-source-pass-enable)
	;; (require 'auth-source-1password)
	;; empty auth-sources
	;; (setq auth-sources nil)
	;; (auth-source-1password-enable)
	;; (add-to-list 'auth-sources 'macos-keychain-internet)
	;; (add-to-list 'auth-sources 'macos-keychain-generic)
	)

(use-package ultra-scroll
	:disabled t
  :vc (:url "https://github.com/jdtsmith/ultra-scroll" :rev :newest)
	:init
  (setq scroll-conservatively 101 ; important!
        scroll-margin 0)
  :config
  (ultra-scroll-mode 1))

(provide 'basic)
