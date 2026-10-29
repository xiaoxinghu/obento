#!/bin/sh
# Time Emacs startup against a throwaway copy of the live config, so the real
# one is never written to.  Prints one line per run and the median:
#   init      wall seconds from launch to the end of init.el
#   after     ... to the end of after-init-hook
#   startup   ... to the end of emacs-startup-hook (initial buffer chosen)
#   idle      ... to the first idle moment (frame redisplayed; "usable")
#   init-time Emacs's own `emacs-init-time`, for comparing with other configs
# The copy is $TMPDIR/emacs-bench; run.out.features there lists what the last run
# loaded, run.out.messages its *Messages* (look there for startup errors).
# Delete the copy after installing or removing packages.
# usage: bench.sh [runs] [config-dir]   (3 runs, this script's directory)
set -e
runs=${1:-3}
src=$(cd "${2:-$(dirname "$0")}" && pwd)
live=$(cd ~/.config/emacs && pwd -P)
dir=${TMPDIR:-/tmp}/emacs-bench
mkdir -p "$dir"
# packages, caches and state come from the live config, copied once
# ...except the quickstart file, which names the live package directories
[ -d "$dir/elpa" ] || {
  rsync -a --exclude /lisp --exclude '/var/package-quickstart.*' "$live/" "$dir/"
  emacs -Q --batch --init-directory "$dir" --eval '(progn (package-initialize t)
    (setq package-quickstart-file (expand-file-name "var/package-quickstart.el" user-emacs-directory))
    (package-quickstart-refresh))' >"$dir/run.log" 2>&1
}
rm -rf "$dir/lisp"; cp -R "$src/lisp" "$dir/lisp"
# early-init.el: the clock, started before anything else, after the cookie line
{ head -1 "$src/early-init.el"; cat <<'EL'
(defvar bench/t0 (string-to-number (getenv "BENCH_T0")))
(defvar bench/marks nil)
(defun bench/mark (label) (push (cons label (- (float-time) bench/t0)) bench/marks))
(add-hook 'after-init-hook (lambda () (bench/mark "init")) -100)
(add-hook 'after-init-hook (lambda () (bench/mark "after")) 100)
(add-hook 'emacs-startup-hook (lambda () (bench/mark "startup")) 100)
(add-hook 'emacs-startup-hook
          (lambda ()
            (run-with-idle-timer
             0 nil
             (lambda ()
               (bench/mark "idle")
               (with-temp-file (getenv "BENCH_OUT")
                 (dolist (m (reverse bench/marks)) (insert (format "%s=%.2f " (car m) (cdr m))))
                 (insert (format "init-time=%s features=%d\n" (emacs-init-time "%.2f") (length features))))
               (with-temp-file (concat (getenv "BENCH_OUT") ".features")
                 (dolist (f (reverse features)) (insert (symbol-name f) "\n")))
               (with-current-buffer "*Messages*"
                 (write-region nil nil (concat (getenv "BENCH_OUT") ".messages")))
               (let ((kill-emacs-hook nil)) (kill-emacs)))))
          101)
;; the live Emacs owns the server socket and the global shortcut
(advice-add 'server-start :override #'ignore)
(advice-add 'portal-global-shortcut-set :override #'ignore)
EL
tail -n +2 "$src/early-init.el"; } > "$dir/early-init.el"
cp "$src/init.el" "$dir/init.el"
out="$dir/run.out"
i=0
while [ "$i" -lt "$runs" ]; do
  rm -f "$out"
  BENCH_OUT="$out" BENCH_T0=$(perl -MTime::HiRes=time -e 'print time') \
    emacs --init-directory "$dir" >"$dir/run.log" 2>&1 &
  pid=$!
  n=0; while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 60 ]; do perl -e 'select undef,undef,undef,1'; n=$((n+1)); done
  kill "$pid" 2>/dev/null || true
  [ -f "$out" ] && cat "$out" >>"$dir/runs.txt" && cat "$out" || { echo "run failed, see $dir/run.log"; exit 1; }
  i=$((i+1))
done
median() {
  for k in init after startup idle init-time; do
    printf "%s=%s " "$k" "$(tail -n "$runs" "$dir/runs.txt" | grep -o "$k=[0-9.]*" | cut -d= -f2 | sort -n | awk "NR==int(($runs+1)/2)")"
  done; echo
}
echo "median: $(median)"
