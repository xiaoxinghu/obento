;;; -*- lexical-binding: t; -*-

(use-package org
	:ensure nil
	:custom
	(org-directory my/org-location)
	(org-src-preserve-indentation t)
	(org-pretty-entities-include-sub-superscripts nil)
	(org-goto-interface 'outline-path-completion)
	(org-outline-path-complete-in-steps nil)
	(org-preview-latex-default-process 'dvisvgm)
	(org-agenda-window-setup 'only-window)
	(org-hide-emphasis-markers t)
	(org-return-follows-link t)
	(org-default-notes-file my/now-file)
	;; Edit settings
	(org-auto-align-tags nil)
	(org-tags-column 0)
	(org-catch-invisible-edits 'show-and-error)
	(org-special-ctrl-a/e t)
	(org-insert-heading-respect-content t)
	(org-agenda-start-on-weekday nil)
	;; Org styling, hide markup etc.
	(org-hide-emphasis-markers t)
	(org-pretty-entities t)
	(org-ellipsis "…")
	;; Agenda styling
	(org-agenda-tags-column 0)
	(org-agenda-current-time-string "⭠ now ─────────────────────────────────────────────────")
	(org-todo-keywords
	 '((sequence
			"TODO(t)"   ; a task
			"WAIT(w)"   ; waiting for something
			"|"
			"DONE(d)"   ; task is done
			"KILL(k)"))) ; task is cancelled
	(org-todo-keyword-faces
	 '(("TODO" . org-todo)
		 ("TO-READ" . org-todo)
		 ("READING" . (:foreground "chartreuse3" :weight bold))
		 ("WAITING" . (:foreground "orange" :weight bold))
		 ("IDEA" . (:foreground "cyan3" :weight bold))
		 ("DONE" . org-done)
		 ("NO" . (:foreground "yellow" :weight bold))
		 ("CANCELLED" . (:foreground "yellow" :weight bold))
		 ))
	;; capture
	(org-capture-templates
	 `(("t" "Todo" entry (file+headline org-default-notes-file "Inbox")
			"* TODO %?\n %i\n %a\n")
		 ("n" "Note" entry (file+headline org-default-notes-file "Notes")
			"* %?\n %i\n")
		 ("L" "Link" entry (file+headline org-default-notes-file "Inbox")
			"* TODO %?[[%:link][%:description]] %U\n%i\n")
		 ("l" "Links"
      entry
      (file ,(expand-file-name "links.org" my/org-location))
      "* TODO [[%:link][%:description]]\n\
:PROPERTIES:\n\
:CREATED:  %U\n\
:END:\n\n\
%?\n"
      :empty-lines 1)
		 ;; ("j" "Journal" entry
		 ;;  (file+olp+datetree ,(expand-file-name "journal.org" my/org-location))
		 ;;  "* %<%Y-%m-%d %H:%M> \n\n%?"
		 ;;  ;; :tree-type week
		 ;;  )
		 ;; ("J" "Journal on a date" entry
		 ;;  (file+olp+datetree ,(expand-file-name "journal.org" my/org-location))
		 ;;  "* %<%Y-%m-%d %H:%M> \n\n%?"
		 ;;  ;; :tree-type week
		 ;;  :time-prompt t
		 ;;  )
		 ))

  :config
	(setq org-link-frame-setup
				'((file . find-file)))
  (setq org-format-latex-options (plist-put org-format-latex-options :scale 1.5))
  (require 'org-protocol)
  (require 'org-archive)

  ;; templates

  ;; insert mode when capture
  (add-hook 'org-capture-mode-hook 'evil-insert-state)

  ;; babel
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((python . t) (shell . t) (C . t) (ditaa . t)))
  (setq org-babel-python-command "python3"
				org-confirm-babel-evaluate nil)

  ;; fix org-mode table with org-modern
  ;; (set-face-attribute 'org-table nil :inherit 'fixed-pitch)
  (custom-set-variables '(org-modern-table nil))

  ;; keybindings
  ;; (define-key org-mode-map (kbd "<leader> v") verb-command-map)

  (defhydra hydra-verb (:hint nil)
    "
_SPC_ send        _q_ quit
"
    ("SPC" verb-send-request-on-point :color blue)
    ("q" nil))

  (evil-define-key nil org-mode-map
    (kbd "<leader> v") '("verb" . hydra-verb/body))


  ;; (evil-define-key 'normal org-mode-map (kbd "<leader> SPC") '("find heading" . org-goto))

  ;; (general-define-key
  ;;  :keymaps 'org-agenda-mode-map
  ;;  :states 'motion
  ;;  "j" 'org-agenda-next-item
  ;;  "k" 'org-agenda-previous-item
  ;;  )

  (evil-define-key 'motion org-agenda-mode-map
    "j" 'org-agenda-next-item
    "k" 'org-agenda-previous-item)


  ;; (general-define-key
  ;;  :keymaps 'org-mode-map
  ;;  :states 'motion
  ;;  "RET" 'org-open-at-point
  ;;  )

  (evil-define-key nil org-mode-map
    (kbd "<localleader> l") '("link" . org-toggle-link-display)
    (kbd "<localleader> t") '("todo" . org-todo)
    (kbd "<localleader> a") '("archive" . org-archive-subtree))

  (evil-define-key 'normal 'global
    (kbd "<leader> a a") '("agenda" . my/agenda)
    (kbd "<leader> c") '("capture" . org-capture))

  (evil-define-key 'motion org-mode-map
    (kbd "RET") '+org/dwim-at-point)
  )

(use-package org-modern
  :hook
  (org-mode . global-org-modern-mode))

(setq-default line-spacing 2)

;; look and feel
;; (use-package olivetti)

(defun my/org-mode ()
  ;; (olivetti-mode)
  ;; (olivetti-set-width 80)
  ;; turn off line numbers
	(setq tab-width 8)
  (display-line-numbers-mode -1))

(add-hook 'org-mode-hook 'my/org-mode)

;; --- agenda ---
;; Detecting Agenda Files
;; Got this from [[https://wohanley.com/posts/org-setup/][this post]].

;; (setq my/org-agenda-directory (expand-file-name "todo" org-directory))
(require 'find-lisp)

(defun my/find-org-files (directory)
  (find-lisp-find-files directory "\.org$"))

(defun who-org/agenda-files-update (&rest _)
  (let ((todo-zettels (->> (format "rg --files-with-matches '(TODO)|(NEXT)|(HOLD)|(WAITING)' %s" org-directory)
													 (shell-command-to-string)
													 (s-lines)
													 (-filter (lambda (line) (not (s-blank? line)))))))
    (setq org-agenda-files todo-zettels)))

(setq org-agenda-files (list my/now-file))

;; (advice-add 'org-agenda :before #'who-org/agenda-files-update)

;; Faces and Colors
(with-no-warnings
  (custom-declare-face '+org-todo-active  '((t (:inherit (bold font-lock-constant-face org-todo)))) "")
  (custom-declare-face '+org-todo-idea '((t (:inherit (bold font-lock-doc-face org-todo)))) "")
  (custom-declare-face '+org-todo-onhold  '((t (:inherit (bold warning org-todo)))) "")
  (custom-declare-face '+org-todo-cancel  '((t (:inherit (bold error org-todo)))) ""))

(setq org-todo-keyword-faces
      '(("[-]"  . +org-todo-active)
				;; ("TODO"  . +org-todo-active)
				("[?]"  . +org-todo-onhold)
				("IDEA" . +org-todo-idea)
				;; ("HOLD" . +org-todo-onhold)
				("NO"   . +org-todo-cancel)))

;;;###autoload
(defun my/agenda ()
  (interactive)
  (org-agenda "a" "a")
  ;; (let ((org-agenda-span 'day)
  ;; (org-super-agenda-groups
  ;;  '(
  ;;    (:name "Today"
  ;; 	  :time-grid t
  ;; 	  :date today
  ;; 	  :scheduled today
  ;; 	  :todo "TODO"
  ;; 	  :order 1
  ;; 	  )
  ;;    ;; (:name "Today"
  ;;    ;; 	  :scheduled today)
  ;;    (:name "Important"
  ;; 	  ;; Single arguments given alone
  ;; 	  :priority "A")
  ;;    (:name "Tasks" :and (:todo "TODO" :not (:category "inbox")))
  ;;    )))
  ;;   (org-todo-list "TODO"))
  )

(use-package org-ql
  :after org
  :config
  (setq org-ql-views
				'(("TODO" :buffers-files org-agenda-files
					 :query (todo)
					 :super-groups '((:auto-category t)))))
  (setq org-agenda-custom-commands
				'(("a" "Agenda"
					 (
						(agenda)

						(org-ql-block '(and (todo)
																(deadline auto))
													((org-ql-block-header "DUE")))

						(org-ql-block '(and (todo)
																(scheduled :on today))
													((org-ql-block-header "TODAY")))

						(org-ql-block '(and (todo)
																(priority "A"))
													((org-ql-block-header "IMPORTANT")))

						(org-ql-block '(and (todo "TODO") (not (habit)) (not (category "inbox")) (not (scheduled)))
													((org-ql-block-header "TASKS")))

						(org-ql-block '(and (todo "TODO") (tags "book"))
													((org-ql-block-header "INPUT")))

						(org-ql-block '(and (todo "IDEA"))
													((org-ql-block-header "IDEAS")))

						))))
  )

;; --- notes ----
(use-package denote
  :custom
  (denote-directory my/org-location)
  (denote-prompts '(title keywords))
	;; (denote-file-type 'text)
  ;; (denote-journal-extras-title-format 'day-date-month-year)
  ;; (denote-j

  ;; (require 'denote-journal-extras)
  )

(use-package denote-journal
	:commands ( denote-journal-new-entry
              denote-journal-new-or-existing-entry
              denote-journal-link-or-create-entry )
	:config
  ;; Use the "journal" subdirectory of the `denote-directory'.  Set this
  ;; to nil to use the `denote-directory' instead.
  (setq denote-journal-directory
        (expand-file-name "journal" denote-directory))
	;; Default keyword for new journal entries. It can also be a list of
  ;; strings.
  (setq denote-journal-keyword "journal")
  ;; Read the doc string of `denote-journal-title-format'.
  (setq denote-journal-title-format 'day-date-month-year))

(use-package denote-org
	:after (denote))

(defhydra hydra-notes (:hint nil)
  "
_n_ notes      _SPC_ now        _q_ quit
_f_ find       _s_ search
_j_ journal    _a_ agenda
"
  ("n" consult-notes :color blue)
  ("SPC" (find-file my/now-file) :color blue)
  ("a" org-agenda :color blue)
  ("f" (affe-find my/org-location) :color blue)
  ("s" (affe-grep my/org-location) :color blue)
  ("j" denote-journal-extras-new-or-existing-entry :color blue)
  ("l" denote-insert-link :color blue)
  ;; ("t" org-roam-dailies-goto-today "Today" :color blue)
  ("q" nil))

(evil-define-key nil 'global
  (kbd "<leader> n") '("notes" . hydra-notes/body))

(defun my-denote-dired-mode-hook()
  (denote-dired-mode-in-directories)
  (if denote-dired-mode
      (dired-hide-details-mode +1)
    (diredfl-mode +1)))

(add-hook 'dired-mode-hook #'my-denote-dired-mode-hook)

(use-package consult-notes
  :config
  ;; (setq consult-notes-file-dir-sources `(("Notes" ?n ,my/org-location)))
  (when (locate-library "denote")
    (consult-notes-denote-mode))
	;; search only for text files in denote dir
	;; (setq consult-notes-denote-files-function (function denote-directory-text-only-files))
  )

(use-package evil-org
  :after org
  :hook (org-mode . evil-org-mode)
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys))

(add-hook 'org-mode-hook
					#'(lambda ()
							(visual-line-mode)
							(org-indent-mode)
              ))


(setq org-image-actual-width nil)
(use-package org-download)
(use-package org-cliplink)

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "M-}") nil)
  (define-key org-mode-map (kbd "M-{") nil))

;; (use-package edraw-mode
;;   :after org
;;   :vc (:fetcher github :repo misohena/el-easydraw)
;;   :config
;;   (with-eval-after-load 'org
;;     (require 'edraw-org)
;;     (edraw-org-setup-default))
;;   ;; When using the org-export-in-background option (when using the
;;   ;; asynchronous export function), the following settings are
;;   ;; required. This is because Emacs started in a separate process does
;;   ;; not load org.el but only ox.el.
;;   (with-eval-after-load "ox"
;;     (require 'edraw-org)
;;     (edraw-org-setup-exporter)))

;;;###autoload
(defun +org/dwim-at-point (&optional arg)
  "Do-what-I-mean at point.

If on a:
- checkbox list item or todo heading: toggle it.
- citation: follow it
- headline: cycle ARCHIVE subtrees, toggle latex fragments and inline images in
  subtree; update statistics cookies/checkboxes and ToCs.
- clock: update its time.
- footnote reference: jump to the footnote's definition
- footnote definition: jump to the first reference of this footnote
- timestamp: open an agenda view for the time-stamp date/range at point.
- table-row or a TBLFM: recalculate the table's formulas
- table-cell: clear it and go into insert mode. If this is a formula cell,
  recaluclate it instead.
- babel-call: execute the source block
- statistics-cookie: update it.
- src block: execute it
- latex fragment: toggle it.
- link: follow it
- otherwise, refresh all inline images in current tree."
  (interactive "P")
  (if (button-at (point))
      (call-interactively #'push-button)
    (let* ((context (org-element-context))
           (type (org-element-type context)))
      ;; skip over unimportant contexts
      (while (and context (memq type '(verbatim code bold italic underline strike-through subscript superscript)))
        (setq context (org-element-property :parent context)
              type (org-element-type context)))
      (pcase type
        ((or `citation `citation-reference)
         (org-cite-follow context arg))

        (`headline
         (cond ((memq (bound-and-true-p org-goto-map)
                      (current-active-maps))
                (org-goto-ret))
               ((and (fboundp 'toc-org-insert-toc)
                     (member "TOC" (org-get-tags)))
                (toc-org-insert-toc)
                (message "Updating table of contents"))
               ((string= "ARCHIVE" (car-safe (org-get-tags)))
                (org-force-cycle-archived))
               ((or (org-element-property :todo-type context)
                    (org-element-property :scheduled context))
                (org-todo
                 (if (eq (org-element-property :todo-type context) 'done)
                     (or (car (+org-get-todo-keywords-for (org-element-property :todo-keyword context)))
                         'todo)
                   'done))))
         ;; Update any metadata or inline previews in this subtree
         (org-update-checkbox-count)
         (org-update-parent-todo-statistics)
         (when (and (fboundp 'toc-org-insert-toc)
                    (member "TOC" (org-get-tags)))
           (toc-org-insert-toc)
           (message "Updating table of contents"))
         (let* ((beg (if (org-before-first-heading-p)
                         (line-beginning-position)
                       (save-excursion (org-back-to-heading) (point))))
                (end (if (org-before-first-heading-p)
                         (line-end-position)
                       (save-excursion (org-end-of-subtree) (point))))
                (overlays (ignore-errors (overlays-in beg end)))
                (latex-overlays
                 (cl-find-if (lambda (o) (eq (overlay-get o 'org-overlay-type) 'org-latex-overlay))
                             overlays))
                (image-overlays
                 (cl-find-if (lambda (o) (overlay-get o 'org-image-overlay))
                             overlays)))
           (+org--toggle-inline-images-in-subtree beg end)
           (if (or image-overlays latex-overlays)
               (org-clear-latex-preview beg end)
             (org--latex-preview-region beg end))))

        (`clock (org-clock-update-time-maybe))

        (`footnote-reference
         (org-footnote-goto-definition (org-element-property :label context)))

        (`footnote-definition
         (org-footnote-goto-previous-reference (org-element-property :label context)))

        ((or `planning `timestamp)
         (org-follow-timestamp-link))

        ((or `table `table-row)
         (if (org-at-TBLFM-p)
             (org-table-calc-current-TBLFM)
           (ignore-errors
             (save-excursion
               (goto-char (org-element-property :contents-begin context))
               (org-call-with-arg 'org-table-recalculate (or arg t))))))

        (`table-cell
         (org-table-blank-field)
         (org-table-recalculate arg)
         (when (and (string-empty-p (string-trim (org-table-get-field)))
                    (bound-and-true-p evil-local-mode))
           (evil-change-state 'insert)))

        (`babel-call
         (org-babel-lob-execute-maybe))

        (`statistics-cookie
         (save-excursion (org-update-statistics-cookies arg)))

        ((or `src-block `inline-src-block)
         (org-babel-execute-src-block arg))

        ((or `latex-fragment `latex-environment)
         (org-latex-preview arg))

        (`link
         (let* ((lineage (org-element-lineage context '(link) t))
                (path (org-element-property :path lineage)))
           (if (or (equal (org-element-property :type lineage) "img")
                   (and path (image-type-from-file-name path)))
               (+org--toggle-inline-images-in-subtree
                (org-element-property :begin lineage)
                (org-element-property :end lineage))
             (org-open-at-point arg))))

        ((guard (org-element-property :checkbox (org-element-lineage context '(item) t)))
         (org-toggle-checkbox))

        (`paragraph
         (+org--toggle-inline-images-in-subtree))

        (_
         (if (or (org-in-regexp org-ts-regexp-both nil t)
                 (org-in-regexp org-tsr-regexp-both nil  t)
                 (org-in-regexp org-link-any-re nil t))
             (call-interactively #'org-open-at-point)
           (+org--toggle-inline-images-in-subtree
            (org-element-property :begin context)
            (org-element-property :end context))))))))

;;;###autoload
(defun +org-get-todo-keywords-for (&optional keyword)
  "Returns the list of todo keywords that KEYWORD belongs to."
  (when keyword
    (cl-loop for (type . keyword-spec)
             in (cl-remove-if-not #'listp org-todo-keywords)
             for keywords =
             (mapcar (lambda (x) (if (string-match "^\\([^(]+\\)(" x)
                                     (match-string 1 x)
                                   x))
                     keyword-spec)
             if (eq type 'sequence)
             if (member keyword keywords)
             return keywords)))

(defun +org--toggle-inline-images-in-subtree (&optional beg end refresh)
  "Refresh inline image previews in the current heading/tree."
  (let* ((beg (or beg
                  (if (org-before-first-heading-p)
                      (save-excursion (point-min))
                    (save-excursion (org-back-to-heading) (point)))))
         (end (or end
                  (if (org-before-first-heading-p)
                      (save-excursion (org-next-visible-heading 1) (point))
                    (save-excursion (org-end-of-subtree) (point)))))
         (overlays (cl-remove-if-not (lambda (ov) (overlay-get ov 'org-image-overlay))
                                     (ignore-errors (overlays-in beg end)))))
    (dolist (ov overlays nil)
      (delete-overlay ov)
      (setq org-inline-image-overlays (delete ov org-inline-image-overlays)))
    (when (or refresh (not overlays))
      (org-display-inline-images t t beg end)
      t)))

(require 'notes+)

;; popup capture
(defun prot-window-delete-popup-frame (&rest _)
  "Kill selected selected frame if it has parameter `prot-window-popup-frame'.
Use this function via a hook."
  (when (frame-parameter nil 'prot-window-popup-frame)
    (delete-frame)))

(defmacro prot-window-define-with-popup-frame (command)
  "Define interactive function which calls COMMAND in a new frame.
Make the new frame have the `prot-window-popup-frame' parameter."
  `(defun ,(intern (format "prot-window-popup-%s" command)) ()
     ,(format "Run `%s' in a popup frame with `prot-window-popup-frame' parameter.
Also see `prot-window-delete-popup-frame'." command)
     (interactive)
     (let ((frame (make-frame '((prot-window-popup-frame . t)))))
       (select-frame frame)
       (switch-to-buffer " prot-window-hidden-buffer-for-popup-frame")
       (condition-case nil
           (call-interactively ',command)
         ((quit error user-error)
          (delete-frame frame))))))

(declare-function org-capture "org-capture" (&optional goto keys))
(defvar org-capture-after-finalize-hook)

;;;###autoload (autoload 'prot-window-popup-org-capture "prot-window")
(prot-window-define-with-popup-frame org-capture)

(add-hook 'org-capture-after-finalize-hook #'prot-window-delete-popup-frame)

(provide 'notes)
