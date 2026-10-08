;;; task.el --- Emacs front end for the task CLI -*- lexical-binding: t; -*-

;;; Commentary:

;; Lists, adds, claims and completes the tasks of a git repository by
;; running the task CLI, which keeps every rule: which tasks are ready, how
;; claiming works and where task files live.  Run `task help' for its
;; manual.
;;
;; `task-list' shows the tasks of the repository `default-directory' is in.
;; `task-add', `task-claim', `task-done' and `task-visit' act on the task at
;; point there, or else ask the CLI what to act on.  `task-claim' and
;; `task-path' return what they print, so other code can build on them, for
;; example to start an agent in a claimed task's worktree.

;;; Code:

(require 'seq)
(require 'subr-x)
(require 'tabulated-list)

(defgroup task nil
  "Front end for the task CLI."
  :group 'tools
  :prefix "task-")

(defcustom task-program "task"
  "The task CLI: a program name on the variable `exec-path', or a file name."
  :type 'string)

(defun task--run (&rest args)
  "Run the task CLI with ARGS in `default-directory'; return its output.
Trailing newlines are removed.  When the CLI fails, signal a `user-error'
with its message."
  (when (file-remote-p default-directory)
    (user-error "The task CLI works in local repositories only"))
  (let ((stderr (make-temp-file "task-stderr")))
    (unwind-protect
        (with-temp-buffer
          (let ((status (apply #'call-process task-program nil (list t stderr) nil args)))
            (unless (eq status 0)
              (user-error "%s" (task--error stderr)))
            (string-trim-right (buffer-string) "\n+")))
      (delete-file stderr))))

(defun task--error (file)
  "Return the error the CLI wrote to FILE.
That is its last \"task: \" line, as the CLI may also print its manual or
the task list."
  (let* ((text (with-temp-buffer
                 (insert-file-contents file)
                 (string-trim (buffer-string))))
         (lines (seq-filter (lambda (line) (string-prefix-p "task: " line))
                            (split-string text "\n"))))
    (or (car (last lines)) text)))

;;; Reading tasks

(defun task-tasks ()
  "Return the tasks of the repository `default-directory' is in, in order.
Each task is a plist of the columns of `task list --tsv': :state, :id,
:title, :blockers (a list of IDs), :branch, :worktree, :worktree-state and
:note.  Empty columns are nil."
  (mapcar (lambda (line)
            (pcase-let ((`(,state ,id ,title ,blockers ,branch ,worktree ,worktree-state ,note)
                         (mapcar (lambda (column) (and (not (string-empty-p column)) column))
                                 (split-string line "\t"))))
              (list :state state :id id :title title
                    :blockers (and blockers (split-string blockers " " t))
                    :branch branch :worktree worktree :worktree-state worktree-state
                    :note note)))
          (split-string (task--run "list" "--tsv") "\n" t)))

(defun task-path (&optional id)
  "Return the files of task ID in this worktree.
The first is the task file; the rest are the README.md of each folder above
it, from the top down.  Without ID, use the task of the current task/<id>
branch."
  (split-string (apply #'task--run "path" (and id (list id))) "\n" t))

(defun task--read (prompt &optional any)
  "Read a task ID with PROMPT, offering every task.
With ANY non-nil, accept text that is not a task's ID, such as a folder."
  (completing-read prompt (mapcar (lambda (task) (plist-get task :id)) (task-tasks))
                   nil (not any)))

(defun task--at-point ()
  "Return the ID of the task on this line of a task list, or nil."
  (and (derived-mode-p 'task-list-mode) (tabulated-list-get-id)))

;;; Commands

;;;###autoload
(defun task-visit (id)
  "Visit the file of task ID.
Interactively, the task on this line of a task list, or else one read in
the minibuffer."
  (interactive (list (or (task--at-point) (task--read "Visit task: "))))
  (find-file (car (task-path id))))

;;;###autoload
(defun task-visit-worktree (id)
  "Visit the worktree of task ID, as the task list shows it.
Interactively, the task on this line of a task list."
  (interactive (list (or (task--at-point) (user-error "No task on this line"))))
  (let ((worktree (plist-get (seq-find (lambda (task) (equal (plist-get task :id) id))
                                       (task-tasks))
                             :worktree)))
    (unless worktree (user-error "Task %s has no worktree" id))
    (find-file worktree)))

;;;###autoload
(defun task-add (title &optional parent)
  "Add a task called TITLE, under the task or folder PARENT if non-nil.
Visit the new task's file to write its body, and return its ID.
Interactively, with a prefix argument, read PARENT too."
  (interactive
   (list (read-string "New task: ")
         (and current-prefix-arg (task--read "Under task or folder: " t))))
  (when (string-empty-p (string-trim title))
    (user-error "A task needs a title"))
  (let ((id (apply #'task--run "add" (append (and parent (list "-p" parent)) (list title)))))
    (task--refresh-lists)
    (when (called-interactively-p 'any)
      (task-visit id))
    id))

;;;###autoload
(defun task-claim (&optional id)
  "Claim task ID, or the next ready task; return its worktree.
Claiming creates the branch task/<id> and its worktree.  Interactively, claim
the task on this line of a task list, or else the next ready one."
  (interactive (list (task--at-point)))
  (let ((worktree (file-name-as-directory (apply #'task--run "claim" (and id (list id))))))
    (task--refresh-lists)
    (when (called-interactively-p 'any)
      (message "Claimed; its worktree is %s" (abbreviate-file-name worktree)))
    worktree))

;;;###autoload
(defun task-done (&optional id)
  "Mark task ID done in this worktree, and return its ID.
Without ID, use the task of the current task/<id> branch.  Interactively,
the task on this line of a task list, or else the current branch's task."
  (interactive (list (task--at-point)))
  (let ((done (apply #'task--run "done" (and id (list id)))))
    (task--refresh-lists)
    (when (called-interactively-p 'any)
      (message "Marked %s done" done))
    done))

;;;###autoload
(defun task-finish (id &optional force)
  "Clean up after task ID's merge: remove its worktree and delete its branch.
With FORCE, drop work that isn't merged too.  Return what the CLI printed.
Interactively, the task on this line of a task list, or else one read in the
minibuffer; a prefix argument forces, after asking."
  (interactive
   (list (or (task--at-point) (task--read "Finish task: "))
         current-prefix-arg))
  (when (and force (called-interactively-p 'any)
             (not (y-or-n-p (format "Drop any unmerged work and changes of %s? " id))))
    (user-error "Finished nothing"))
  (let ((output (apply #'task--run "finish" (append (and force (list "--force")) (list id)))))
    (task--refresh-lists)
    (when (called-interactively-p 'any) (message "%s" output))
    output))

;;;###autoload
(defun task-finish-all ()
  "Finish every task whose branch is merged and whose worktree is clean.
Return what the CLI printed."
  (interactive)
  (let ((output (task--run "finish" "--all")))
    (task--refresh-lists)
    (when (called-interactively-p 'any)
      (message "%s" (if (string-empty-p output) "Nothing to finish" output)))
    output))

;;; The task list

(defcustom task-list-title-width 60
  "The widest the title column of a task list gets; longer titles are cut."
  :type 'natnum)

(defvar-local task--list-tasks nil "The tasks this list shows, as `task-tasks' read them.")
(defvar-local task--list-described nil "The ID of the task the echo area last described.")

(defface task-ready '((t :inherit success))
  "Face for the state of a ready task.")

(defface task-claimed '((t :inherit warning))
  "Face for the state of a claimed task.")

(defface task-inactive '((t :inherit shadow))
  "Face for the state of a blocked, done or wontfix task.")

(defvar-keymap task-list-mode-map
  :doc "Keymap for `task-list-mode'."
  "RET" #'task-visit
  "a" #'task-add
  "c" #'task-claim
  "d" #'task-done
  "w" #'task-visit-worktree
  "x" #'task-finish
  "X" #'task-finish-all)

(define-derived-mode task-list-mode tabulated-list-mode "Tasks"
  "Major mode for the tasks of a repository, in the CLI's order.
\\<task-list-mode-map>\\[task-visit] visits a task and \\[task-add] adds one.
\\[task-claim] claims a task and \\[task-done] marks it done.
\\[task-visit-worktree] visits its worktree.
\\[task-finish] cleans up after its merge; with a prefix argument, it drops unmerged
work too.  \\[task-finish-all] finishes every merged task.
The note column says what may need you; see `task help'.
Moving to a task shows its ID, blockers, worktree and note in the echo area.
\\<tabulated-list-mode-map>\\[revert-buffer] reloads the list.

\\{task-list-mode-map}"
  (setq tabulated-list-format (task--list-format 5))
  (setq tabulated-list-padding 1)
  (add-hook 'tabulated-list-revert-hook #'task--list-entries nil t)
  (add-hook 'post-command-hook #'task--list-describe nil t)
  (tabulated-list-init-header))

(defun task--list-format (title-width)
  "Return the task list's columns, with a title column TITLE-WIDTH wide."
  (vector '("State" 8 nil) (list "Title" title-width nil) '("Branch" 15 nil) '("Note" 0 nil)))

(defun task--list-entries ()
  "Read this buffer's tasks into `tabulated-list-entries'.
The title column fits the longest title, up to `task-list-title-width'."
  (setq task--list-tasks (task-tasks)
        task--list-described nil)
  (setq tabulated-list-format
        (task--list-format
         (min task-list-title-width
              (apply #'max 5 (mapcar (lambda (task) (string-width (or (plist-get task :title) "")))
                                     task--list-tasks)))))
  (tabulated-list-init-header)
  (setq tabulated-list-entries
        (mapcar (lambda (task)
                  (let ((state (plist-get task :state)))
                    (list (plist-get task :id)
                          (vector (propertize state 'face
                                              (pcase state
                                                ("ready" 'task-ready)
                                                ("claimed" 'task-claimed)
                                                (_ 'task-inactive)))
                                  (or (plist-get task :title) "")
                                  (string-join (delq nil (list (plist-get task :branch)
                                                               (plist-get task :worktree-state)))
                                               " · ")
                                  (propertize (or (plist-get task :note) "") 'face 'warning)))))
                task--list-tasks)))

(defun task--list-describe ()
  "Describe the task at point in the echo area, once each time point reaches it."
  (let ((id (tabulated-list-get-id)))
    (unless (or (null id) (equal id task--list-described) (active-minibuffer-window))
      (setq task--list-described id)
      (let ((task (seq-find (lambda (task) (equal (plist-get task :id) id)) task--list-tasks)))
        (message "%s" (string-join
                       (delq nil (list id
                                       (and (plist-get task :blockers)
                                            (concat "blocked by "
                                                    (string-join (plist-get task :blockers) ", ")))
                                       (and (plist-get task :worktree)
                                            (abbreviate-file-name (plist-get task :worktree)))
                                       (plist-get task :note)))
                       "  ·  "))))))

(defun task--repository ()
  "Return the root of the repository `default-directory' is in, or it."
  (expand-file-name (or (locate-dominating-file default-directory ".git")
                        default-directory)))

;;;###autoload
(defun task-list ()
  "List the tasks of the repository `default-directory' is in.
Each repository has one list buffer; listing it again reloads it."
  (interactive)
  (let* ((root (task--repository))
         (buffer (get-buffer-create (format "*tasks: %s*" (abbreviate-file-name root)))))
    (with-current-buffer buffer
      (unless (derived-mode-p 'task-list-mode) (task-list-mode))
      (setq default-directory root)
      (revert-buffer))
    (pop-to-buffer buffer)))

(defun task--refresh-lists ()
  "Reload every task list buffer, as a command changed its tasks."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'task-list-mode)
        (with-demoted-errors "Could not reload the task list: %S"
          (revert-buffer))))))

(provide 'task)
;;; task.el ends here
