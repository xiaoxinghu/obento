;;; -*- lexical-binding: t; -*-

;;;###autoload
(defvar doom-fallback-buffer-name "*scratch*"
  "The name of the buffer to fall back to if no other buffers exist (will create
it if it doesn't exist).")

(defvar +org-capture-fn #'org-capture
  "Command to use to initiate org-capture.")

;;;###autoload
(defun doom-fallback-buffer ()
  "Returns the fallback buffer, creating it if necessary. By default this is the
scratch buffer. See `doom-fallback-buffer-name' to change this."
  (let (buffer-list-update-hook)
    (get-buffer-create doom-fallback-buffer-name)))

;;;###autoload
(defun +org-capture-frame-p (&rest _)
  "Return t if the current frame is an org-capture frame opened by
`+org-capture/open-frame'."
  (and (equal (alist-get 'name +org-capture-frame-parameters)
              (frame-parameter nil 'name))
       (frame-parameter nil 'transient)))

;;;###autoload
(defvar +org-capture-frame-parameters
  `((name . "doom-capture")
    (width . 70)
    (height . 25)
    (transient . t)
    ,@(when (featurep :system 'linux)
        `((window-system . ,(if (boundp 'pgtk-initialized) 'pgtk 'x))
          (display . ,(or (getenv "WAYLAND_DISPLAY")
                          (getenv "DISPLAY")
                          ":0"))))
    ,(if (featurep :system 'macos) '(menu-bar-lines . 1)))
  "TODO")

;;;###autoload
(defun +org-capture/open-frame (&optional initial-input key)
  "Opens the org-capture window in a floating frame that cleans itself up once
you're done. This can be called from an external shell script."
  (interactive)
  (when (and initial-input (string-empty-p initial-input))
    (setq initial-input nil))
  (when (and key (string-empty-p key))
    (setq key nil))
  (let* ((frame-title-format "")
         (frame (if (+org-capture-frame-p)
                    (selected-frame)
                  (make-frame +org-capture-frame-parameters))))
    (select-frame-set-input-focus frame)  ; fix MacOS not focusing new frames
    (with-selected-frame frame
			(require 'org-capture)
			(condition-case nil
					(letf! ((#'pop-to-buffer #'switch-to-buffer))
						(switch-to-buffer (doom-fallback-buffer))
						(let ((org-capture-initial initial-input)
									org-capture-entry)
							(when (and key (not (string-empty-p key)))
								(setq org-capture-entry (org-capture-select-template key)))
							(call-interactively +org-capture-fn)
							))
				((quit error user-error)
				 (message "org-capture: %s" (error-message-string ex))
				 (delete-frame frame))))))

(defun +org-capture/delete-capture-frame (&rest _)
  "Kill selected selected frame if it has parameter `prot-window-popup-frame'.
Use this function via a hook."
  (when (+org-capture-frame-p)
    (delete-frame)))

(add-hook 'org-capture-after-finalize-hook #'+org-capture/delete-capture-frame)

(defmacro letf! (bindings &rest body)
  "Temporarily rebind function, macros, and advice in BODY.

Intended as syntax sugar for `cl-letf', `cl-labels', `cl-macrolet', and
temporary advice (`define-advice').

BINDINGS is either:

  A list of (PLACE VALUE) bindings as `cl-letf*' would accept.
  A list of, or a single, `defun', `defun*', `defmacro', or `defadvice' forms.

The def* forms accepted are:

  (defun NAME (ARGS...) &rest BODY)
    Defines a temporary function with `cl-letf'
  (defun* NAME (ARGS...) &rest BODY)
    Defines a temporary function with `cl-labels' (allows recursive
    definitions).
  (defmacro NAME (ARGS...) &rest BODY)
    Uses `cl-macrolet'.
  (defadvice FUNCTION WHERE ADVICE)
    Uses `advice-add' (then `advice-remove' afterwards).
  (defadvice FUNCTION (HOW LAMBDA-LIST &optional NAME DEPTH) &rest BODY)
    Defines temporary advice with `define-advice'."
  (declare (indent defun))
  (setq body (macroexp-progn body))
  (when (memq (car bindings) '(defun defun* defmacro defadvice))
    (setq bindings (list bindings)))
  (dolist (binding (reverse bindings) body)
    (let ((type (car binding))
          (rest (cdr binding)))
      (setq
       body (pcase type
              (`defmacro `(cl-macrolet ((,@rest)) ,body))
              (`defadvice
									(if (keywordp (cadr rest))
											(cl-destructuring-bind (target where fn) rest
												`(when-let* ((fn ,fn))
													 (advice-add ,target ,where fn)
													 (unwind-protect ,body (advice-remove ,target fn))))
										(let* ((fn (pop rest))
													 (argspec (pop rest)))
											(when (< (length argspec) 3)
												(setq argspec
															(list (nth 0 argspec)
																		(nth 1 argspec)
																		(or (nth 2 argspec) (gensym (format "%s-a" (symbol-name fn)))))))
											(let ((name (nth 2 argspec)))
												`(progn
													 (define-advice ,fn ,argspec ,@rest)
													 (unwind-protect ,body
														 (advice-remove #',fn #',name)
														 ,(if name `(fmakunbound ',name))))))))
              (`defun
									`(cl-letf ((,(car rest) (symbol-function #',(car rest))))
										 (ignore ,(car rest))
										 (cl-letf (((symbol-function #',(car rest))
																(lambda! ,(cadr rest) ,@(cddr rest))))
											 ,body)))
              (`defun*
									`(cl-labels ((,@rest)) ,body))
              (_
               (when (eq (car-safe type) 'function)
                 (setq type (list 'symbol-function type)))
               (list 'cl-letf (list (cons type rest)) body)))))))

(provide 'notes+)
