;;; frost.el --- Frosted-glass frames on macOS -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Xiaoxing Hu

;; Author: Xiaoxing Hu <hi@xiaoxing.dev>
;; URL: https://github.com/xiaoxinghu/frost
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: faces, frames
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; `frost-mode' makes every top-level frame see-through, with what is
;; behind it blurred: frosted glass.  Text keeps its colours; the
;; theme's background becomes a tint over the glass.  Child frames stay
;; opaque.
;;
;; It needs macOS, Emacs built with the NS (Cocoa) port and with
;; modules, and the Command Line Tools: a small native module, frost.m,
;; is built with clang into this package's folder the first time the
;; mode is turned on.  Elsewhere the mode does nothing.
;;
;; The module puts a system material (an NSVisualEffectView) behind the
;; frame's view and lets it through with a blend mode on the view's
;; layer: screen for a dark theme, multiply for a light one.

;;; Code:

(require 'color)
(require 'seq)
(require 'subr-x)

(defgroup frost nil
  "Frosted-glass frames on macOS."
  :group 'frames
  :prefix "frost-")

(defconst frost--materials
  '((hud-window . 13) (under-window-background . 21) (window-background . 12)
    (full-screen-ui . 15) (sidebar . 7) (popover . 6) (menu . 5) (titlebar . 3))
  "The materials of NSVisualEffectView, by their values in AppKit.")

(defvar frost-mode)

(defun frost--set (symbol value)
  "Set SYMBOL to VALUE and frost the frames again."
  (set-default-toplevel-value symbol value)
  (when (bound-and-true-p frost-mode)
    (frost--update)))

(defcustom frost-tint-opacity 65
  "Opacity of the tint over the glass, from 0 to 100.
Higher keeps the theme's background, lower lets more of the backdrop
show through."
  :type 'natnum
  :set #'frost--set)

(defcustom frost-tint-color nil
  "Colour of the tint over the glass, or nil for the default background."
  :type '(choice (const :tag "Default face's background" nil) color)
  :set #'frost--set)

(defcustom frost-material 'hud-window
  "The system material behind the frame, as NSVisualEffectView names it."
  :type `(choice ,@(mapcar (lambda (m) (list 'const (car m))) frost--materials))
  :set #'frost--set)

(defconst frost--directory
  (file-name-directory (or load-file-name buffer-file-name (locate-library "frost")))
  "This package's folder, which holds frost.m and the module built from it.")

(declare-function frost--apply "frost-module" (mode material red green blue alpha))

(defvar frost--failed nil
  "Non-nil once the module failed to build or load.
It is tried again when `frost-mode' is next turned on.")

(defun frost--module ()
  "Load the native module, building it when missing or older than frost.m.
Return non-nil when it is loaded.  A failure is a message, not an error."
  (or (fboundp 'frost--apply)
      (and module-file-suffix (not frost--failed)
           (let ((default-directory frost--directory)
                 (dylib (expand-file-name "frost-module.dylib" frost--directory)))
             (condition-case err
                 (progn
                   ;; A module once loaded stays loaded: a rebuilt one takes
                   ;; effect at the next start of Emacs.
                   (when (file-newer-than-file-p "frost.m" dylib)
                     (message "frost: building %s" dylib)
                     (with-temp-buffer
                       (unless (eql 0 (call-process
                                       "clang" nil t nil "-shared" "-fobjc-arc"
                                       "-framework" "Cocoa" "-framework" "QuartzCore"
                                       "-I." "frost.m" "-o" dylib))
                         (error "Building the module failed: %s"
                                (string-trim (buffer-string))))))
                   (module-load dylib)
                   (fboundp 'frost--apply))
               (error (setq frost--failed t)
                      (message "frost: %s" (error-message-string err))
                      nil))))))

(defun frost--frame ()
  "A live top-level NS frame, the selected one first, or nil."
  (seq-find (lambda (frame) (and (eq (framep frame) 'ns) (not (frame-parent frame))))
            (cons (selected-frame) (frame-list))))

(defun frost--update (&rest _)
  "Frost every top-level NS frame for the current theme.
With `frost-mode' off, take the frost off them."
  (when-let* ((frame (frost--frame))
              ((if frost-mode (frost--module) (fboundp 'frost--apply))))
    (let ((rgb (or (color-name-to-rgb
                    (or frost-tint-color (face-background 'default frame)) frame)
                   '(0.0 0.0 0.0))))
      (apply #'frost--apply
             (and frost-mode (frame-parameter frame 'background-mode))
             (alist-get frost-material frost--materials 13)
             (append rgb (list (/ (min frost-tint-opacity 100) 100.0)))))))

;;;###autoload
(define-minor-mode frost-mode
  "Show every top-level frame as frosted glass.
The frame's background becomes a tint over a blur of what is behind it,
following the theme.  Needs macOS and the NS port; elsewhere it does
nothing."
  :global t
  :group 'frost
  (setq frost--failed nil)
  (dolist (hook '(after-make-frame-functions enable-theme-functions
                  disable-theme-functions))
    (if frost-mode
        (add-hook hook #'frost--update)
      (remove-hook hook #'frost--update)))
  (frost--update))

(provide 'frost)
;;; frost.el ends here
