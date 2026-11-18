;;; -*- lexical-binding: t; -*-

(defun +macos-defaults (action &rest args)
  (apply #'doom-call-process "defaults" action args))

(defun +macos-open-with (&optional app-name path)
  "Send PATH to APP-NAME on OSX."
  (interactive)
  (let* ((path (expand-file-name
                (replace-regexp-in-string
                 "'" "\\'"
                 (or path (if (derived-mode-p 'dired-mode)
                              (dired-get-file-for-visit)
                            (buffer-file-name)))
                 nil t)))
         (command (format "open %s"
                          (if app-name
                              (format "-a %s '%s'" (shell-quote-argument app-name) path)
                            (format "'%s'" path)))))
    (message "Running: %s" command)
    (shell-command command)))

(defmacro +macos--open-with (id &optional app dir)
  `(defun ,(intern (format "+macos/%s" id)) ()
     (interactive)
     (+macos-open-with ,app ,dir)))

(defmacro +macos--open-with-iterm (id &optional dir newwindow?)
  `(defun ,(intern (format "+macos/%s" id)) ()
     (interactive)
     (letf! ((defun read-newwindows ()
               (cdr (+macos-defaults
                     "read" "com.googlecode.iterm2" "OpenFileInNewWindows")))
             (defun write-newwindows (bool)
               (+macos-defaults
                "write" "com.googlecode.iterm2" "OpenFileInNewWindows"
                "-bool" (if bool "true" "false"))))
       (let ((newwindow?
              (if ,newwindow? (not (equal (read-newwindows) "1")))))
         (when newwindow?
           (write-newwindows t))
         (unwind-protect (+macos-open-with "iTerm" ,dir)
           (when newwindow?
             (write-newwindows nil)))))))

;;;###autoload (autoload '+macos/open-in-default-program "os/macos/autoload" nil t)
(+macos--open-with open-in-default-program)

;;;###autoload (autoload '+macos/reveal-in-finder "os/macos/autoload" nil t)
(+macos--open-with reveal-in-finder "Finder" default-directory)

;;;###autoload (autoload '+macos/reveal-project-in-finder "os/macos/autoload" nil t)
(+macos--open-with reveal-project-in-finder "Finder"
                   (or (doom-project-root) default-directory))

(use-package emacs-everywhere)

(use-package osx-dictionary)

(use-package take
  :local "~/files/workspace/.repos/github.com/xiaoxinghu/take/emacs"
  :commands (take-prepare)
  :hook (take-prepare . my/keycast-mode)   ; show the keys in the recording frame
  :custom
  (take-default-preset 'youtube))

(use-package launcher
  :local "~/workspace/launcher.el/"
  :commands (launcher launcher-buffer launcher-refresh)
  :config
  (require 'launcher-osx-dictionary)
  (setq launcher-tools
        '(("d" :name "Dictionary" :prompt "Word: "
           :function launcher-osx-dictionary-lookup))))

;; Option-h hides Emacs
(global-set-key (kbd "M-h") 'ns-do-hide-emacs)

;; Homebrew's git
(setq magit-git-executable "/opt/homebrew/bin/git")

;; the theme follows the system's appearance, at startup too
(add-hook 'ns-system-appearance-change-functions #'my/apply-theme)

;; scrolling
(setq mac-redisplay-dont-reset-vscroll t
      mac-mouse-wheel-smooth-scroll nil)

;; frosted-glass frames, a package of its own in frost/ until it has a repo
(use-package frost
	:disabled t
  :ensure nil
  :load-path "frost"
  :hook (after-init . frost-mode)
  :init
  ;; Portal's terminals and Markdown previews are glass with the frame. The
  ;; dark glass is close to their dark backgrounds, so 0.85 shows no
  ;; difference; 0.3 does.
  (defvar portal-terminal-opacity)
  (defvar portal-web-preview-opacity)
  (add-hook 'frost-mode-hook
            (lambda ()
              (setq portal-terminal-opacity (if frost-mode 0.3 1)
                    portal-web-preview-opacity (if frost-mode 0.3 1)))))

;; Portal's views are WebKit and AppKit
(use-package portal
  :local "~/files/workspace/.repos/github.com/xiaoxinghu/portal"
  :vc (:url "https://github.com/xiaoxinghu/portal" :rev :newest)
  ;; Load after the frame: portal-web loads url and browse-url.
  :defer 1
	:custom
	(portal-terminal-theme "Catppuccin Mocha")
	;; Escape twice returns from a view's app to Emacs, as Escape leaves insert state.
	(portal-input-double-escape 0.3)
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

  ;; When the native view has focus, Escape twice before using the leader.
  (evil-define-key 'normal 'global (kbd "<leader> P") #'hydra-portal/body)

  (require 'portal-launcher)

  (defun my/app-launcher ()
    "Launch apps, search the web, or query tools in Portal's panel.
With a prefix argument, rebuild the application index first."
    (interactive)
    (let ((vertico-count 6)
          (portal-launcher-size '(720 auto))
          (portal-launcher-height-limits '(content 480)))
      (portal-launcher-present #'launcher-buffer
                               :kind 'buffer
                               :mode-line nil))))

(provide 'macos)
