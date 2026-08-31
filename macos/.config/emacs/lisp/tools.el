;;; -*- lexical-binding: t; -*-

(use-package vterm
  :custom
  (vterm-module-cmake-args "-DCMAKE_PREFIX_PATH=/opt/homebrew")
  )

(use-package eat)

(use-package pdf-tools
	:disabled t
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :config
  (pdf-tools-install))

(setq
 user-mail-address "hi@huxiaoxing.com"
 user-full-name "Xiaoxing Hu")

(use-package mu4e
	:disabled t
	:ensure nil
	:config
	(setq mail-user-agent 'mu4e-user-agent)

	(evil-define-key 'normal 'global
		(kbd "<leader>e") '("help" . mu4e))

	;; https://pragmaticemacs.wordpress.com/2016/03/22/fixing-duplicate-uid-errors-when-using-mbsync-and-mu4e/
	(setq mu4e-change-filenames-when-moving t)

	(setq
	 mu4e-maildir (expand-file-name "~/Mail")
	 mu4e-refile-folder "/Archive"
	 mu4e-sent-folder "/Sent"
	 mu4e-drafts-folder "/Drafts"
	 mu4e-trash-folder "/Trash")
	(setq mu4e-attachment-dir (expand-file-name "~/Downloads"))
	(setq mu4e-get-mail-command "mbsync fastmail")
	(setq mu4e-update-interval (* 10 60)) ;; update every 10 minutes
	(setq mu4e-maildir-shortcuts
				'(
					("/Inbox" . ?i)
					("/Drafts" . ?d)
					("/Sent" . ?s)
					))
	(setq
	 smtpmail-servers-requiring-authorization "fastmail"
   message-send-mail-function   'smtpmail-send-it
	 smtpmail-smtp-service 465
	 smtpmail-stream-type 'ssl
   smtpmail-default-smtp-server "smtp.fastmail.com"
   smtpmail-smtp-server         "smtp.fastmail.com")

	(setq mu4e-bookmarks
				'(
					("flag:unread AND NOT flag:trashed" "Unread" ?u)
					("flag:flagged AND NOT flag:trashed" "Flagged" ?f)
					("date:today..now" "Today" ?t)
					("date:7d..now AND NOT flag:trashed" "Last 7 days" ?w)
					)))

(use-package mu4e-views
	:after mu4e
	:defer nil
  :vc (:url "https://github.com/lordpretzel/mu4e-views" :rev :newest)
  :bind (:map mu4e-headers-mode-map
							("v" . mu4e-views-mu4e-select-view-msg-method) ;; choose view method
							("M-n" . mu4e-views-cursor-msg-view-window-down)
							("M-p" . mu4e-views-cursor-msg-view-window-up)
							("f" . mu4e-views-toggle-auto-view-selected-message)
							("i" . mu4e-views-mu4e-view-as-nonblocked-html))
  :config
  (setq mu4e-views-default-view-method "html-nonblock")
  (mu4e-views-mu4e-use-view-msg-method "html-nonblock")
  (setq mu4e-views-next-previous-message-behaviour 'stick-to-current-window)
  (setq mu4e-views-auto-view-selected-message t))

(use-package notmuch
	:disabled t
	;; :config
	;; (setq notmuch-hello-sections
	;; 			'(
	;; 				notmuch-hello-insert-header
	;; 				notmuch-hello-insert-saved-searches
	;; 				notmuch-hello-insert-alltags
	;; 				notmuch-hello-insert-recent-messages
	;; 				))
	;; (setq notmuch-saved-searches
	;; 			'(
	;; 				("inbox" . "tag:inbox AND tag:unread")
	;; 				("unread" . "tag:unread")
	;; 				("flagged" . "tag:flagged")
	;; 				("today" . "date:today..now")
	;; 				("last 7 days" . "date:7d..now")
	;; 				))
	)

(use-package org-msg
	:disabled t
	:config
	(setq org-msg-options "html-postamble:nil H:5 num:nil ^:{} toc:nil author:nil email:nil \\n:t"
				org-msg-startup "hidestars indent inlineimages"
				org-msg-greeting-fmt "\nHi%s,\n\n"
				org-msg-greeting-name-limit 3
				org-msg-default-alternatives '((new	. (text html))
																			 (reply-to-html	. (text html))
																			 (reply-to-text	. (text)))
				org-msg-convert-citation t
				org-msg-signature "
 Regards,

 #+begin_signature
 --
 *Xiaoxing Hu*
 #+end_signature")
	(org-msg-mode))


(use-package eaf
  :vc (:fetcher github :repo emacs-eaf/emacs-application-framework)
	:disabled t
	:custom
  (eaf-browser-continue-where-left-off t)
  (eaf-browser-enable-adblocker t)
  (browse-url-browser-function 'eaf-open-browser)
  :config
  (defalias 'browse-web #'eaf-open-browser)
	(require 'eaf-pdf-viewer)
	(require 'eaf-browser)
	)

;; (use-package pass
;; 	:custom
;; 	(auth-source-pass-filename "~/.password-store")
;; 	:config
;; 	(auth-source-pass-enable))

(use-package password-store)
;; (use-package doing
;; 	:vc (:url "https://github.com/xiaoxinghu/doing.el" :rev :newest))

(use-package doing
  :load-path "~/workspace/doing.el"
	:custom
	(doing-directory my/org-location)
	(evil-define-key 'normal 'global
		(kbd "<leader>d") doing-command-map)
	)

(use-package links
  :load-path "~/workspace/links.el")

(provide 'tools)
