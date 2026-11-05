;;; -*- lexical-binding: t; -*-

(defun xah-new-empty-buffer ()
  "Create a new empty buffer.
Returns the buffer object.
New buffer is named untitled, untitled<2>, etc.

Warning: new buffer is not prompted for save when killed, see `kill-buffer'.
Or manually `save-buffer'

URL `http://xahlee.info/emacs/emacs/emacs_new_empty_buffer.html'
Created: 2017-11-01
Version: 2022-04-05"
  (interactive)
  (let ((xbuf (generate-new-buffer "untitled")))
    (switch-to-buffer xbuf)
    (funcall initial-major-mode)
    xbuf
    ))

(defgroup shebang nil
  "Shebang."
  :group 'extensions)

(defcustom shebang-env-path "/usr/bin/env"
  "Path to the env executable."
  :type 'string
  :group 'shebang)

(defcustom shebang-interpretor-map
  '(("sh" . "bash")
    ("py" . "python3")
    ("js" . "deno run")
    ("mjs" . "deno run")
    ("ts" . "deno run")
    ("rb" . "ruby"))
  "Alist of interpretors and their paths."
  :type '(alist :key-type (string :tag "Extension")
								:value-type (string :tag "Interpreter"))
  :group 'shebang)

(defun guess-shebang-command ()
  "Guess the command to use for the shebang."
  (let ((ext (file-name-extension (buffer-file-name))))
    (or (cdr (assoc ext shebang-interpretor-map))
				ext)))

(defun insert-shebang ()
  "Insert shebang line at the top of the buffer."
  (interactive)
  (goto-char (point-min))
  (insert (format "#!%s %s" shebang-env-path (guess-shebang-command)))
  (newline))


(defgroup run nil
  "Run."
  :group 'extensions)

(defcustom run-ext-command-map
  '(("sh" . "bash")
    ("py" . "python3")
    ("js" . "deno run")
    ("ts" . "deno run")
    ("mjs" . "deno run")
    ("rb" . "ruby"))
  "Alist of interpretors and their paths."
  :type '(alist :key-type (string :tag "Extension")
								:value-type (string :tag "Command"))
  :group 'run)

(defun get-command (file)
  "Get command for executing FILE.

Return the FILE when the file is executable.
Return the command from the run-ext-command-map otherwise"
  (if (file-executable-p file)
			file
    (let ((ext (file-name-extension file)))
      (format "%s %s" (cdr (assoc ext run-ext-command-map)) file))))

(defun run-buffer ()
  "Run the current buffer."
  (interactive)
  (when (not (buffer-file-name)) (save-buffer))
  (when (buffer-modified-p) (save-buffer))
  (let* (
         ($outputb "*run output*")
         (resize-mini-windows nil)
         ($fname (buffer-file-name))
         ($cmd (get-command $fname))
         )
    (progn
      (message "Running %s" $cmd)
      (shell-command $cmd $outputb)
      )))

(defun yank-location ()
  "Copy the full path of the current buffer to the clipboard.
If a region is selected, append the line range to the path."
  (interactive)
  (let ((filepath (buffer-file-name)))
    (if filepath
        (let ((path-to-copy
               (if (use-region-p)
                   ;; Region is active - add line number or range
                   (let* ((start-pos (region-beginning))
                          (end-pos (region-end))
                          (start-line (line-number-at-pos start-pos))
                          ;; If end position is at beginning of line, use previous position
                          (adjusted-end-pos (if (save-excursion
																									(goto-char end-pos)
																									(bolp))
																								(1- end-pos)
																							end-pos))
                          (end-line (line-number-at-pos adjusted-end-pos)))
                     (if (= start-line end-line)
                         ;; Single line selected (possibly with newline)
                         (format "%s:%d" filepath start-line)
                       ;; Multiple lines selected
                       (format "%s:%d-%d" filepath start-line end-line)))
                 ;; No region - just the path
                 filepath)))
          (kill-new path-to-copy)
          (message "Copied path: %s" path-to-copy))
      (message "Buffer is not visiting a file"))))

;; Optional: Bind to a key combination
;; (global-set-key (kbd "C-c p") 'copy-buffer-path)
(defun my/treesit-goto-parent ()
  "Go to the start of the parent Tree-sitter node."
  (interactive)
  (let* ((node (treesit-node-at (point)))
         (parent (treesit-node-parent node)))
    (if parent
        (goto-char (treesit-node-start parent))
      (message "No parent node."))))

(defgroup my-scratch nil
  "Scratch projects for ad-hoc coding with LSP."
  :group 'tools)

;; ----- scratch code buffer -----
(defcustom my-scratch-projects
  '((typescript . "~/projects/scratch/js/index.ts"))
  "Mapping of scratch project names to entry files."
  :type '(alist :key-type symbol :value-type string)
  :group 'my-scratch)

(defun my-open-scratch (&optional lang)
  "Open a scratch project entry file.
If LANG is nil, prompt for it."
  (interactive)
  (let* ((choice
          (or lang
              (intern
               (completing-read
                "Scratch project: "
                (mapcar #'symbol-name (mapcar #'car my-scratch-projects))
                nil t))))
         (file (cdr (assq choice my-scratch-projects))))
    (unless file
      (user-error "No scratch project configured for %s" choice))
    (find-file (expand-file-name file))
    ;; Optional but usually what you want
    (when (fboundp 'eglot-ensure)
      (eglot-ensure))))

;; ----- render color correctly -----
(require 'ansi-color)

(defun my/colorize-compilation-buffer ()
  "Apply ANSI color codes in compilation buffer."
  (ansi-color-apply-on-region compilation-filter-start (point)))

(add-hook 'compilation-filter-hook #'my/colorize-compilation-buffer)

;; Bun test error format: at <anonymous> (/path/to/file.ts:12:17)
(with-eval-after-load 'compile
  (add-to-list 'compilation-error-regexp-alist-alist
               '(bun-test
                 "at [^(]*(\\([^:]+\\):\\([0-9]+\\):\\([0-9]+\\))"
                 1 2 3 2))
  (add-to-list 'compilation-error-regexp-alist 'bun-test))

(require 'json)
(require 'project)
(require 'subr-x)

(defun my/project-root ()
  "Return the current project root, or `default-directory'."
  (if-let* ((project (project-current nil)))
      (project-root project)
    default-directory))

(defun my/package-root ()
  "Return the nearest parent directory containing package.json."
  (locate-dominating-file default-directory "package.json"))

(defun my/read-json-file (file)
  "Read FILE as a hash-table JSON object."
  (if (fboundp 'json-parse-file)
      (json-parse-file file :object-type 'hash-table :array-type 'list)
    (let ((json-object-type 'hash-table)
          (json-array-type 'list)
          (json-key-type 'string))
      (json-read-file file))))

(defun my/package-json (root)
  "Read package.json under ROOT."
  (let ((file (expand-file-name "package.json" root)))
    (when (file-exists-p file)
      (ignore-errors (my/read-json-file file)))))

(defun my/package-scripts (root)
  "Return package.json script names under ROOT."
  (let* ((pkg (my/package-json root))
         (scripts (and pkg (gethash "scripts" pkg))))
    (when (hash-table-p scripts)
      (sort (hash-table-keys scripts) #'string<))))

(defun my/package-manager (root)
  "Guess the package manager for ROOT."
  (let* ((pkg (my/package-json root))
         (declared (and pkg (gethash "packageManager" pkg))))
    (or (and (stringp declared) (car (split-string declared "@")))
        (cond
         ((or (file-exists-p (expand-file-name "bun.lock" root))
              (file-exists-p (expand-file-name "bun.lockb" root))) "bun")
         ((file-exists-p (expand-file-name "pnpm-lock.yaml" root)) "pnpm")
         ((file-exists-p (expand-file-name "yarn.lock" root)) "yarn")
         (t "npm")))))

(defun my/package-script-command (root script)
  "Return shell command to run SCRIPT under ROOT."
  (format "%s run %s" (my/package-manager root) (shell-quote-argument script)))

(defun my/run-package-script ()
  "Run a package.json script with `compile'."
  (interactive)
  (let* ((root (or (my/package-root)
                   (user-error "No package.json found")))
         (scripts (or (my/package-scripts root)
                      (user-error "No scripts in package.json")))
         (script (completing-read "Script: " scripts nil t nil nil
                                  (or (car (member "build" scripts))
                                      (car scripts))))
         (default-directory root))
    (compile (read-shell-command "Compile command: "
                                 (my/package-script-command root script)))))

(defun my/project-compile ()
  "Run `compile' from the project root with a Make/JS-aware default."
  (interactive)
  (let* ((package-root (my/package-root))
         (root (or package-root (my/project-root)))
         (scripts (and package-root (my/package-scripts package-root)))
         (default-directory root)
         (cmd (cond
               ((file-exists-p (expand-file-name "Makefile" root)) "make -k")
               ((and package-root (member "build" scripts))
                (my/package-script-command package-root "build"))
               ((and package-root (member "test" scripts))
                (my/package-script-command package-root "test"))
               (t compile-command))))
    (compile (read-shell-command "Compile command: " cmd))))

(defvar my/runner-alist
  '(
		(("ts" "js") . "bun %f")
		(("c") . "cc %f && ./a.out")
		)
  "Alist mapping file extensions to run commands.

%f is replaced with the absolute file name.")

(defun my--test-file-p (file)
  "Return non-nil if FILE is a test file."
  (string-match-p "\\(?:[._]\\(?:test\\|spec\\)\\)\\.\\(?:ts\\|js\\)\\'" file))

(defcustom my/test-runner-command "bun test %f"
  "Command template for running test files.
%f is replaced with the absolute file name."
  :type 'string
  :group 'my-scratch)

(defun my--runner-for-file (file)
  "Return run command for FILE based on extension."
  (if (my--test-file-p file)
      my/test-runner-command
    (let ((ext (file-name-extension file)))
      (cl-loop for (exts . cmd) in my/runner-alist
               when (member ext exts)
               return cmd))))

(defun my/run-current-buffer ()
  "Run current buffer using an appropriate runner."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer is not visiting a file"))

  (save-buffer)

  (let* ((file (buffer-file-name))
         (cmd-template (my--runner-for-file file)))
    (unless cmd-template
      (user-error "No runner configured for %s" file))

    (compile
     (replace-regexp-in-string
      "%f"
      (shell-quote-argument file)
      cmd-template
      t t))))

(defun my/bun-debug-current-buffer (&optional wait)
  "Start debugging the current JS/TS buffer with Bun inspector.
If WAIT is non-nil, use --inspect-wait so Bun waits for the debugger to attach."
  (interactive "P")
  (unless (buffer-file-name)
    (user-error "Buffer is not visiting a file"))

  (save-buffer)
  (let* ((file (buffer-file-name))
         (flag (if wait "--inspect-wait" "--inspect-brk"))
         (cmd (format "bun %s %s"
                      flag
                      (shell-quote-argument file))))
    (compilation-start cmd 'compilation-mode
                       (lambda (_mode) "*bun debug*"))))

(defun xah-title-case-region-or-line (&optional Begin End)
  "Title case text between nearest brackets, or current line or selection.
Capitalize first letter of each word, except words like {to, of, the, a, in, or, and}. If a word already contains cap letters such as HTTP, URL, they are left as is.

When called in a elisp program, Begin End are region boundaries.

URL `http://xahlee.info/emacs/emacs/elisp_title_case_text.html'
Version: 2017-01-11 2021-03-30 2021-09-19"
  (interactive)
  (let* ((xskipChars "^\"<>(){}[]“”‘’‹›«»「」『』【】〖〗《》〈〉〔〕")
         (xp0 (point))
         (xp1 (if Begin
                  Begin
                (if (region-active-p)
                    (region-beginning)
                  (progn
                    (skip-chars-backward xskipChars (line-beginning-position)) (point)))))
         (xp2 (if End
                  End
                (if (region-active-p)
                    (region-end)
                  (progn (goto-char xp0)
                         (skip-chars-forward xskipChars (line-end-position)) (point)))))
         (xstrPairs [
                     [" A " " a "]
                     [" An " " an "]
                     [" And " " and "]
                     [" At " " at "]
                     [" As " " as "]
                     [" By " " by "]
                     [" Be " " be "]
                     [" Into " " into "]
                     [" In " " in "]
                     [" Is " " is "]
                     [" It " " it "]
                     [" For " " for "]
                     [" Of " " of "]
                     [" Or " " or "]
                     [" On " " on "]
                     [" Via " " via "]
                     [" The " " the "]
                     [" That " " that "]
                     [" To " " to "]
                     [" Vs " " vs "]
                     [" With " " with "]
                     [" From " " from "]
                     ["'S " "'s "]
                     ["'T " "'t "]
                     ]))
    (save-excursion
      (save-restriction
        (narrow-to-region xp1 xp2)
        (upcase-initials-region (point-min) (point-max))
        (let ((case-fold-search nil))
          (mapc
           (lambda (xx)
             (goto-char (point-min))
             (while
                 (search-forward (aref xx 0) nil t)
               (replace-match (aref xx 1) t t)))
           xstrPairs))))))

(provide 'functions)
