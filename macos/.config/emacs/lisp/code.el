;;; -*- lexical-binding: t; -*-

(setq sgml-basic-offset 'tab)

(setopt treesit-enabled-modes t
        treesit-auto-install-grammar 'always)

(add-hook 'python-mode-hook
					(lambda ()
						(setq indent-tabs-mode nil)
						;; (setq tab-width 4)
						(setq py-indent-tabs-mode nil)))

(use-package combobulate
  :disabled t
  :vc (:url "https://github.com/mickeynp/combobulate" :rev :newest)
  :custom
  ;; You can customize Combobulate's key prefix here.
  ;; Note that you may have to restart Emacs for this to take effect!
  (combobulate-key-prefix "C-c o")
  :hook (
         (prog-mode . combobulate-mode)
         (typescript-ts-mode . combobulate-mode)
         (html-ts-mode . combobulate-mode)
         )
  ;; :load-path ("~/.config/emacs/packages/combobulate")
  )

(use-package evil-textobj-tree-sitter
  :demand t
  :after evil
  :config
  ;; bind `function.outer`(entire function block) to `f` for use in things like `vaf`, `yaf`
  (define-key evil-outer-text-objects-map "f" (evil-textobj-tree-sitter-get-textobj "function.outer"))
  (define-key evil-outer-text-objects-map "v" (evil-textobj-tree-sitter-get-textobj "parameter.outer"))
  ;; bind `function.inner`(function block without name and args) to `f` for use in things like `vif`, `yif`
  (define-key evil-inner-text-objects-map "f" (evil-textobj-tree-sitter-get-textobj "function.inner"))

  ;; You can also bind multiple items and we will match the first one we can find
  (define-key evil-outer-text-objects-map "a" (evil-textobj-tree-sitter-get-textobj ("conditional.outer" "loop.outer")))
  ;; Goto start of next function
  (define-key evil-normal-state-map
              (kbd "]f")
              (lambda ()
                (interactive)
                (evil-textobj-tree-sitter-goto-textobj "function.outer")))

  ;; Goto start of previous function
  (define-key evil-normal-state-map
              (kbd "[f")
              (lambda ()
                (interactive)
                (evil-textobj-tree-sitter-goto-textobj "function.outer" t)))

  ;; Goto end of next function
  (define-key evil-normal-state-map
              (kbd "]F")
              (lambda ()
                (interactive)
                (evil-textobj-tree-sitter-goto-textobj "function.outer" nil t)))

  ;; Goto end of previous function
  (define-key evil-normal-state-map
              (kbd "[F")
              (lambda ()
                (interactive)
                (evil-textobj-tree-sitter-goto-textobj "function.outer" t t)))
  )

(use-package projectile
  :custom
  (projectile-project-search-path '(("~/projects/" . 2)))
  :hook (after-init . projectile-mode)
  :config
  (setq projectile-completion-system 'default)

  (defhydra hydra-project (:hint nil)
    "Project"
    ("p" projectile-switch-project "find project" :color blue)
    ("f" projectile-find-file "file file" :color blue)
    ("b" consult-project-buffer "find buffer" :color blue)
    ("c" my/project-compile "compile" :color blue)
    ("C" recompile "recompile" :color blue)
    ("s" my/run-package-script "npm script" :color blue)
    ("t" ghostel-project "terminal" :color blue)
    ("r" forge-browse-repository "repos" :color blue)
    ("q" nil))

  (evil-define-key nil 'global
    (kbd "M-p") 'projectile-find-file
    (kbd "M-P") 'projectile-switch-project
    (kbd "M-B") 'consult-project-buffer
    )

  (evil-define-key 'normal 'global
    (kbd "<leader>p") 'hydra-project/body))

;; project
;; (require 'project)

;; capture project todo
(defun my/org-capture-project-todo-file ()
  "Return the path to the TODO.org file in the current project's root directory."
  (let ((project (project-current)))
    (if project
        (concat (project-root project) "TODO.org")
      (user-error "Not in a project"))))

(with-eval-after-load 'org-capture
  (add-to-list 'org-capture-templates
               '("p" "Project TODO" entry (file my/org-capture-project-todo-file)
                 "* TODO %?\n  %i\n  %a")))

(defun jump-to-project-todo ()
  "Jump to the TODO.org file in the current project's root directory, or show an error if it doesn't exist."
  (interactive)
  (let* ((project (project-current))
         (project-root (when project (project-root project)))
         (todo-file-path (concat project-root "TODO.org")))
    (if (and project-root (file-exists-p todo-file-path))
        (find-file todo-file-path)
      (message "TODO.org file does not exist in the current project."))))

(use-package magit
  :commands (magit-status magit-blame)
  :init
  ;; Have magit-status go full screen and quit to previous
  ;; configuration.  Taken from
  ;; http://whattheemacsd.com/setup-magit.el-01.html#comment-748135498
  ;; and http://irreal.org/blog/?p=2253
  (define-advice magit-status (:around (fn &rest args) fullscreen)
    (window-configuration-to-register :magit-fullscreen)
    (prog1 (apply fn args)
      (delete-other-windows)))
  (define-advice magit-quit-window (:after (&rest _) restore-screen)
    (jump-to-register :magit-fullscreen))
  :custom
  (magit-diff-refine-hunk 'all)
  (magit-git-executable "/opt/homebrew/bin/git")
	(magit-diff-arguments '("--ignore-all-space"))
  :config
  ;; (remove-hook 'magit-status-sections-hook 'magit-insert-tags-header)
  ;; (remove-hook 'magit-status-sections-hook 'magit-insert-status-headers)
  (remove-hook 'magit-status-sections-hook 'magit-insert-unpushed-to-pushremote)
  (remove-hook 'magit-status-sections-hook 'magit-insert-unpulled-from-pushremote)
  (remove-hook 'magit-status-sections-hook 'magit-insert-unpulled-from-upstream)
  (remove-hook 'magit-status-sections-hook 'magit-insert-unpushed-to-upstream-or-recent)
  )

(defhydra hydra-merge (:color blue :hint nil)
  "
  ^Navigation^           ^Actions^
  ----------------------------------------
  _n_: next conflict     _a_: keep all
  _p_: previous conflict _b_: keep base
  _j_: next line         _m_: keep mine
  _k_: previous line     _r_: resolve
  _C_: combine with next _RET_: keep current
  _E_: ediff             _q_: quit
  _R_: refine
  "
  ("n" smerge-next :color red)
  ("p" smerge-prev :color red)
  ("j" evil-next-line :color red)
  ("k" evil-previous-line :color red)
  ("C" smerge-combine-with-next)
  ("E" smerge-ediff)
  ("R" smerge-refine)
  ("a" smerge-keep-all)
  ("b" smerge-keep-base)
  ("m" smerge-keep-mine)
  ("r" smerge-resolve)
  ("RET" smerge-keep-current)
  ("q" nil :color blue))

(evil-define-key 'normal smerge-mode-map (kbd "SPC m") 'hydra-merge/body)


(use-package git-gutter
  :after magit
  :init
  (global-git-gutter-mode +1))

(use-package git-gutter-fringe
  :after git-gutter
  :config
  (define-fringe-bitmap 'git-gutter-fr:added [224] nil nil '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:modified [224] nil nil '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:deleted [128 192 224 240] nil nil 'bottom))

;; it's slow: https://github.com/dandavison/magit-delta/issues/9
;; (use-package magit-delta
;;   :after magit
;;   :hook (magit-mode . magit-delta-mode))
;; (setq magit-refresh-status-buffer nil)

(use-package browse-at-remote
  :after magit
  :config
  (let ((keymaps (list dired-mode-map magit-log-mode-map magit-status-mode-map)))
    (dolist (keymap keymaps)
      (evil-define-key 'normal keymap (kbd "gb") 'browse-at-remote)))
  )

(use-package forge
  :after magit
  :config
  (kbd "<leader>pr") '("browse repo" . forge-browse-repository))

;; (use-package consult-gh
;;   :after consult
;;   :config
;;   (setq consult-gh-default-orgs-list '("xiaoxinghu" "orgapp" "nib-group"))
;;   (setq consult-gh-default-clone-directory "~/Projects"))

(defhydra hydra-git (:hint nil)
  "git"
  ("g" magit-status "status" :color blue)
  ("b" browse-at-remote "browse" :color blue)
  ("s" magit-stage-buffer-file "stage" :color blue)
  ("S" consult-gh-search-repos "stage" :color blue)
  ("c" magit-commit "commit" :color blue)
  ("p" magit-push "push" :color blue)
  ("l" magit-log "log" :color blue)
  ("f" magit-log-buffer-file "log" :color blue)
  ;; ("b" magit-blame "blame" :color blue)
  ("q" nil "quit"))

(evil-define-key 'normal 'global (kbd "SPC g") 'hydra-git/body)

(use-package apheleia
  :hook (after-init . apheleia-global-mode)
  :config
  ;; Run the globally available, mise-managed Biome directly.
  ;; Keep formatting working with temporary syntax errors during edits.
  (setf (alist-get 'biome apheleia-formatters)
        '("biome" "format"
          "--format-with-errors=true"
          "--stdin-file-path" filepath))
	(dolist (mode '(css-mode
                  css-ts-mode
                  js-json-mode
                  js-mode
                  json-mode
                  json-ts-mode
                  js-ts-mode
                  tsx-ts-mode
                  typescript-mode
                  typescript-ts-mode))
    (setf (alist-get mode apheleia-mode-alist) '(biome))))

;; Automatically make file executable when =shebang= is found.
(add-hook 'after-save-hook
					'executable-make-buffer-file-executable-if-script-p)

(use-package editorconfig
  :custom
  (editorconfig-exclude-modes '(org-mode))
  :hook (after-init . editorconfig-mode))

(with-eval-after-load 'editorconfig
  (add-to-list 'editorconfig-indentation-alist
               '(svelte-ts-mode-indent-offset . svelte-ts-mode-indent-offset)))

;; (use-package smartparens
;;   :config
;;   (require 'smartparens-config)
;;   (add-hook 'prog-mode-hook #'smartparens-mode))

(use-package electric
  :ensure nil
  :hook (prog-mode . electric-pair-mode)
  ;; :custom
  ;; (electric-pair-pairs
  ;;  '((?\( . ?\))
  ;;    (?\[ . ?\])
  ;;    (?\{ . ?\})
  ;;    (?\" . ?\")
  ;;    (?\' . ?\')))
	)

;; Code folding. TBH, I don't fold my code.
(use-package origami
  :hook (prog-mode . origami-mode))

(use-package eldoc
  :ensure nil
  :config
  ;; Wait for a pause in typing/movement before requesting documentation.
  (setq eldoc-idle-delay 0.5
        eldoc-echo-area-use-multiline-p nil))

;; Better indentation.
(use-package aggressive-indent
	:disabled t
  :config
  (global-aggressive-indent-mode 1))

(use-package eldoc-box
  :disabled t
  :config
  (evil-define-key 'normal 'eglot-mode-map
    "K" 'eldoc-box-help-at-point)
  )


(defun my/yas-typescript-snippets ()
  "Make JavaScript snippets available in native TypeScript modes."
  (require 'yasnippet)
  (yas-activate-extra-mode 'js-mode))

(use-package yasnippet
  :custom
  (yas-snippet-dirs `(,(expand-file-name "snippets" user-emacs-directory)))
  ;; (yas-snippet-dirs '("~/.config/emacs/snippets"))
	:hook ((prog-mode . yas-minor-mode)
	       ((typescript-ts-mode tsx-ts-mode) . my/yas-typescript-snippets))
	:config
	(yas-reload-all t))

(use-package yasnippet-capf
  :after yasnippet
  :init
  (add-to-list 'completion-at-point-functions #'yasnippet-capf))

(use-package dockerfile-mode
  :mode "Dockerfile\\'")


;; Major mode for driving just files.
(use-package justl)

(use-package consult-gh
	:after consult)

(use-package dape
  :preface
  ;; By default dape shares the same keybinding prefix as `gud'
  ;; If you do not want to use any prefix, set it to nil.
  ;; (setq dape-key-prefix "\C-x\C-a")

  :hook
  ;; Save breakpoints on quit
  (kill-emacs . dape-breakpoint-save)
  ;; Load breakpoints on startup
  (after-init . dape-breakpoint-load)

  :custom
  ;; Turn on global bindings for setting breakpoints with mouse
  (dape-breakpoint-global-mode +1)

  ;; Info buffers to the right
  ;; (dape-buffer-window-arrangement 'right)
  ;; Info buffers like gud (gdb-mi)
  ;; (dape-buffer-window-arrangement 'gud)
  ;; (dape-info-hide-mode-line nil)

  ;; Projectile users
  (dape-cwd-function #'projectile-project-root)

  :config

	(defhydra hydra-debug (:color pink :hint nil)
		"
^Stepping^        ^Breakpoints^        ^Session^
--------------------------------------------------
_n_: next         _b_: toggle          _d_: debug
_i_: step in      _B_: delete all      _r_: restart
_o_: step out     _C_: condition       _K_: kill
_c_: continue     _L_: log message     _D_: disconnect
"
		;; stepping
		("n" dape-next)
		("i" dape-step-in)
		("o" dape-step-out)
		("c" dape-continue)

		;; breakpoints
		("b" dape-breakpoint-toggle)
		("B" dape-breakpoint-remove-all)
		("C" dape-breakpoint-condition)
		("L" dape-breakpoint-log-message)

		;; session
		("d" dape)
		("r" dape-restart)
		("K" dape-kill :color red)
		("D" dape-disconnect :color red)

		;; exit hydra only
		("<escape>" nil "quit" :color blue))

	;; 	(defhydra hydra-debug (:color pink :hint nil)
	;; 		"
	;; ^Stepping^        ^Breakpoints^       ^Session^         ^Eval/Watch^
	;; ^^^^^^^^----------------------------------------------------------------
	;; _n_: Next         _b_: Toggle         _d_: Debug        _e_: Watch expr
	;; _i_: Step in      _B_: Remove all     _r_: Restart      _E_: Eval region
	;; _o_: Step out     _l_: Log message    _q_: Quit/Stop
	;; _c_: Continue
	;; "
	;; 		;; stepping
	;; 		("n" dape-next)
	;; 		("i" dape-step-in)
	;; 		("o" dape-step-out)
	;; 		("c" dape-continue)

	;; 		;; breakpoints
	;; 		("b" dape-breakpoint-toggle)
	;; 		("B" dape-breakpoint-remove-all)
	;; 		("l" dape-breakpoint-log-message)

	;; 		;; session control
	;; 		("d" dape)
	;; 		("r" dape-restart)
	;; 		("q" dape-disconnect :color red)

	;; 		;; eval/watch
	;; 		("e" dape-watch-add :exit nil)
	;; 		("E" dape-eval-region)
	;; 		;; exit
	;; 		("<escape>" nil "quit" :color blue)
	;; 		("q" nil "quit" :color blue))

	;; (evil-define-key 'normal 'global
	;; 	(kbd "<leader> d") 'hydra-debug/body)

  ;; Pulse source line (performance hit)
  (add-hook 'dape-display-source-hook #'pulse-momentary-highlight-one-line)

  ;; Save buffers on startup, useful for interpreted languages
  (add-hook 'dape-start-hook (lambda () (save-some-buffers t t)))

  ;; Kill compile buffer on build success
  ;; (add-hook 'dape-compile-hook #'kill-buffer)
  )

;; For a more ergonomic Emacs and `dape' experience
;; (use-package repeat
;;   :custom
;;   (repeat-mode +1))

;; Left and right side windows occupy full frame height
(use-package emacs
  :custom
  (window-sides-vertical t))

(provide 'code)
