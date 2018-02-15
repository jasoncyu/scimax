;;; scimax-org-babel-ipython-upstream.el --- Modifications to the upstream ob-ipython module

;;; Commentary:
;; This file contains monkey patches and enhancements to the upstream ob-ipython
;; module. Several new customizations are now possible.
;;
;; Some new header arguments:
;;
;; :display can be used to specify which mime-types are displayed. The default is all of them.
;; :restart can be used to restart the kernel before executing the cell
;; :async is not new, but it works by itself now, and causes an asynchronous evaluation of the cell

(require 'scimax-ob)

;; * Customizations

(defcustom ob-ipython-buffer-unique-kernel t
  "If non-nil use a unique kernel for each buffer."
  :group 'ob-ipython)

(defcustom ob-ipython-show-mime-types t
  "If non-nil show mime-types in output."
  :group 'ob-ipython)

(defcustom ob-ipython-exception-results t
  "If non-nil put the contents of the traceback buffer as results."
  :group 'ob-ipython)

(defcustom ob-ipython-suppress-execution-count nil
  "If non-nil do not show the execution count in output."
  :group 'ob-ipython)

(defcustom ob-ipython-delete-stale-images t
  "If non-nil remove images that will be replaced."
  :group 'ob-ipython)

(defcustom ob-ipython-mime-formatters
  '((text/plain . ob-ipython-format-text/plain)
    (text/html . ob-ipython-format-text/html)
    (text/latex . ob-ipython-format-text/latex)
    (text/org . ob-ipython-format-text/org)
    (image/png . ob-ipython-format-image/png)
    (image/svg+xml . ob-ipython-format-image/svg+xml)
    (application/javascript . ob-ipython-format-application/javascript)
    (default . ob-ipython-format-default)
    (output . ob-ipython-format-output))
  "An alist of (mime-type . format-func) for mime-types.
Each function takes two arguments, which is file-or-nil and a
string to be formatted."
  :group 'ob-ipython)

(defcustom ob-ipython-plain-text-filter-regexps
  '(
					;this is what boring python objects look like. I never need to see these, so
					;we strip them out. That might be a strong opinion though, and might
					;surprise people who like to or are used to seeing them.
    "^<.*at 0x.*>"
    )
  "A list of regular expressions to filter out of text/plain results."
  :group 'ob-ipython)

(defcustom ob-ipython-key-bindings
  '(("C-<return>" . #'org-ctrl-c-ctrl-c)
    ("S-<return>" . #'scimax-execute-and-next-block)
    ("M-<return>" . #'scimax-execute-to-point)
    ("s-<return>" . #'scimax-ob-ipython-restart-kernel-execute-block)
    ("M-s-<return>" . #'scimax-restart-ipython-and-execute-to-point)
    ("H-<return>" . #'scimax-ob-ipython-restart-kernel-execute-buffer)
    ("H-k" . #'scimax-ob-ipython-kill-kernel)
    ("H-r" . #'org-babel-switch-to-session)

    ;; navigation commands
    ("s-i" . #'org-babel-previous-src-block)
    ("s-k" . #'org-babel-next-src-block)
    ("H-q" . #'scimax-jump-to-visible-block)
    ("H-s-q" . #'scimax-jump-to-block)

    ;; editing commands
    ("H-=" . #'scimax-insert-src-block)
    ("H--" . #'scimax-split-src-block)
    ("H-n" . #'scimax-ob-copy-block-and-results)
    ("H-w" . #'scimax-ob-kill-block-and-results)
    ("H-c" . #'scimax-ob-clone-block)
    ("s-w" . #'scimax-ob-move-src-block-up)
    ("s-s" . #'scimax-ob-move-src-block-down)
    ("H-l" . #'org-babel-remove-result)
    ("H-s-l" . #'scimax-ob-clear-all-results)
    ("H-m" . #'scimax-merge-ipython-blocks)
    ("H-e" . #'scimax-ob-edit-header)

    ;; Miscellaneous
    ("H-/" . #'ob-ipython-inspect)

    ;; The hydra/popup menu
    ("H-s" . #'scimax-obi/body)
    ("<mouse-3>" . #'scimax-ob-ipython-popup-command))
  "An alist of key bindings and commands."
  :group 'ob-ipython)


(cl-loop for cell in ob-ipython-key-bindings
	 do
	 (eval `(scimax-define-src-key ipython ,(car cell) ,(cdr cell))))

(defcustom ob-ipython-menu-items
  '(("Execute"
     ["Current block" org-ctrl-c-ctrl-c t]
     ["Current and next" scimax-execute-and-next-block t]
     ["To point" scimax-execute-to-point t]
     ["Restart/block" scimax-ob-ipython-restart-kernel-execute-block t]
     ["Restart/to point" scimax-restart-ipython-and-execute-to-point t]
     ["Restart/buffer" scimax-ob-ipython-restart-kernel-execute-buffer t])
    ("Edit"
     ["Move block up" scimax-ob-move-src-block-up t]
     ["Move block down" scimax-ob-move-src-block-down t]
     ["Kill block" scimax-ob-kill-block-and-results t]
     ["Copy block" scimax-ob-copy-block-and-results t]
     ["Clone block" scimax-ob-clone-block t]
     ["Split block" scimax-split-src-block t]
     ["Clear result" org-babel-remove-result t]
     ["Edit header" scimax-ob-edit-header t]
     )
    ("Navigate"
     ["Previous block" org-babel-previous-src-block t]
     ["Next block" org-babel-next-src-block t]
     ["Jump to visible block" scimax-jump-to-visible-block t]
     ["Jump to block" scimax-jump-to-block t])
    ["Inspect" ob-ipython-inspect t]
    ["Kill kernel" scimax-ob-ipython-kill-kernel t]
    ["Switch to repl" org-babel-switch-to-session t])
  "Items for the menu bar and popup menu."
  :group 'ob-ipython)


;; * org templates and default header args

(add-to-list 'org-structure-template-alist
	     '("ip" "#+BEGIN_SRC ipython\n?\n#+END_SRC"
	       "<src lang=\"python\">\n?\n</src>"))

(add-to-list 'org-structure-template-alist
	     '("ipv" "#+BEGIN_SRC ipython :results value\n?\n#+END_SRC"
	       "<src lang=\"python\">\n?\n</src>"))

(add-to-list 'org-structure-template-alist
	     '("plt" "%matplotlib inline\nimport matplotlib.pyplot as plt\n"
	       ""))

(setq org-babel-default-header-args:ipython
      '((:results . "output replace drawer")
	(:session . "ipython")
	(:exports . "both")
	(:cache .   "no")
	(:noweb . "no")
	(:hlines . "no")
	(:tangle . "no")
	(:eval . "never-export")))


(defun scimax-install-ipython-lexer ()
  "Install the IPython lexer for Pygments.
You need this to get syntax highlighting."
  (interactive)
  (unless (= 0
	     (shell-command
	      "python -c \"import pygments.lexers; pygments.lexers.get_lexer_by_name('ipython')\""))
    (shell-command "pip install git+git://github.com/sanguineturtle/pygments-ipython-console")))


;; * A hydra for ob-ipython blocks

(defhydra scimax-obi (:color blue :hint nil)
  "
        Execute                   Navigate     Edit             Misc
----------------------------------------------------------------------
    _<return>_: current           _i_: previous  _w_: move up     _/_: inspect
  _S-<return>_: current to next   _k_: next      _s_: move down   _l_: clear result
  _M-<return>_: to point          _q_: visible   _x_: kill        _L_: clear all
  _s-<return>_: Restart/block     _Q_: any       _n_: copy
_M-s-<return>_: Restart/to point  ^ ^            _c_: clone
  _H-<return>_: Restart/buffer    ^ ^            _m_: merge
           _K_: kill kernel       ^ ^            _-_: split
           _r_: Goto repl         ^ ^            _+_: insert above
           ^ ^                    ^ ^            _=_: insert below
           ^ ^                    ^ ^            _h_: header"
  ("<return>" org-ctrl-c-ctrl-c :color red)
  ("S-<return>" scimax-execute-and-next-block :color red)
  ("M-<return>" scimax-execute-to-point)
  ("s-<return>" scimax-ob-ipython-restart-kernel-execute-block)
  ("M-s-<return>" scimax-restart-ipython-and-execute-to-point)
  ("H-<return>" scimax-ob-ipython-restart-kernel-execute-buffer)
  ("K" scimax-ob-ipython-kill-kernel)
  ("r" org-babel-switch-to-session)

  ("i" org-babel-previous-src-block :color red)
  ("k" org-babel-next-src-block :color red)
  ("q" scimax-jump-to-visible-block)
  ("Q" scimax-jump-to-block)

  ("w" scimax-ob-move-src-block-up :color red)
  ("s" scimax-ob-move-src-block-down :color red)
  ("x" scimax-ob-kill-block-and-results)
  ("n" scimax-ob-copy-block-and-results)
  ("c" scimax-ob-clone-block)
  ("m" scimax-merge-ipython-blocks)
  ("-" scimax-split-src-block)
  ("+" scimax-insert-src-block)
  ("=" (scimax-insert-src-block t))
  ("l" org-babel-remove-result)
  ("L" scimax-ob-clear-all-results)
  ("h" scimax-ob-edit-header)

  ("/" ob-ipython-inspect))


;; * A context menu

(define-prefix-command 'scimax-ob-ipython-mode-map)

(easy-menu-define ob-ipython-menu scimax-ob-ipython-mode-map "ob-ipython menu"
  ob-ipython-menu-items)

(defun ob-ipython-org-menu ()
  "Add the ob-ipython menu to the Org menu."
  (easy-menu-change '("Org") "ob-ipython" ob-ipython-menu-items "Show/Hide")
  (easy-menu-change '("Org") "--" nil "Show/Hide"))

(add-hook 'org-mode-hook 'ob-ipython-org-menu)

(defun scimax-ob-ipython-popup-command (event)
  "Run the command selected from `ob-ipython-menu'."
  (interactive "e")
  (call-interactively
   (or (popup-menu ob-ipython-menu)
       'ignore)))

;; * Execution functions

(defun scimax-ob-ipython-restart-kernel-execute-block ()
  "Restart kernel and execute block"
  (interactive)
  (ob-ipython-kill-kernel
   (cdr (assoc (if-let (bf (buffer-file-name))
		   (md5 (expand-file-name bf))
		 "scratch")
	       (ob-ipython--get-kernel-processes))))
  (org-babel-execute-src-block-maybe))


(defun scimax-ob-ipython-restart-kernel-execute-buffer ()
  "Restart kernel and execute buffer"
  (interactive)
  (ob-ipython-kill-kernel
   (cdr (assoc (if-let (bf (buffer-file-name))
		   (md5 (expand-file-name bf))
		 "scratch")
	       (ob-ipython--get-kernel-processes))))
  (org-babel-execute-buffer))


(defun scimax-restart-ipython-and-execute-to-point ()
  "Kill the kernel and run src-blocks to point."
  (interactive)
  (call-interactively 'ob-ipython-kill-kernel)
  (scimax-execute-to-point))


(defun scimax-ob-ipython-kill-kernel ()
  "Kill the active kernel."
  (interactive)
  (when (y-or-n-p "Kill kernel?")
    (ob-ipython-kill-kernel
     (cdr (assoc (if-let (bf (buffer-file-name))
		     (md5 (expand-file-name bf))
		   "scratch")
		 (ob-ipython--get-kernel-processes))))
    (setq header-line-format nil)
    (redisplay)))


;; * block editing functions
(defun scimax-merge-ipython-blocks (r1 r2)
  "Merge blocks in the current region (R1 R2).
This deletes the results from each block, and concatenates the
code into a single block in the position of the first block.
Currently no switches/parameters are preserved. It isn't clear
what the right thing to do for those is, e.g. dealing with
variables, etc."
  (interactive "r")
  ;; Expand the region to encompass the src blocks that the points might be in.
  (let* ((R1 (save-excursion
	       (goto-char r1)
	       (if (org-in-src-block-p)
		   (org-element-property :begin (org-element-context))
		 r1)))
	 (R2 (save-excursion
	       (goto-char r2)
	       (if (org-in-src-block-p)
		   (org-element-property :end (org-element-context))
		 r2))))
    (save-restriction
      (narrow-to-region R1 R2)
      (let* ((blocks (org-element-map (org-element-parse-buffer) 'src-block
		       (lambda (src)
			 (when (string= "ipython" (org-element-property :language src))
			   src))))
	     (first-start (org-element-property :begin (car blocks)))
	     (merged-code (s-join "\n" (loop for src in blocks
					     collect
					     (org-element-property :value src)))))
	;; Remove blocks
	(loop for src in (reverse blocks)
	      do
	      (goto-char (org-element-property :begin src))
	      (org-babel-remove-result)
	      (setf (buffer-substring (org-element-property :begin src)
				      (org-element-property :end src))
		    ""))
	;; Now create the new big block.
	(goto-char first-start)
	(insert (format "#+BEGIN_SRC ipython
%s
#+END_SRC\n\n" (s-trim merged-code)))))))



;; * Modifications of ob-ipython

;; Modified to make buffer unique kernels automatically
(defun org-babel-execute:ipython (body params)
  "Execute a block of IPython code with Babel.
This function is called by `org-babel-execute-src-block'."

  ;; TODO: how to deal with user named sessions and unique?
  (when ob-ipython-buffer-unique-kernel
    ;; Use buffer local variables for this.
    (make-local-variable 'org-babel-default-header-args:ipython)

    ;; remove the old session info
    (setq org-babel-default-header-args:ipython
	  (remove (assoc :session org-babel-default-header-args:ipython)
		  org-babel-default-header-args:ipython))

    ;; add the new session info
    (let ((session-name (if-let (bf (buffer-file-name))
			    (md5 (expand-file-name bf))
			  "scratch")))
      (setq header-line-format (format "Ipython session: %s" session-name))
      (add-to-list 'org-babel-default-header-args:ipython
		   (cons :session session-name))))

  (ob-ipython--clear-output-buffer)

  ;; delete any figures that will be replaced and clear results here.
  (when ob-ipython-delete-stale-images
    (let ((result-string (let ((location (org-babel-where-is-src-block-result)))
			   (when location
			     (save-excursion
			       (goto-char location)
			       (when (looking-at (concat org-babel-result-regexp ".*$"))
				 (buffer-substring-no-properties
				  (save-excursion
				    (skip-chars-backward " \r\t\n")
				    (line-beginning-position 2))
				  (progn (forward-line) (org-babel-result-end))))))))
	  (files '())
	  ;; This matches automatic file generation
	  (fregex "\\[\\[file:\\(./obipy-resources/.*\\)\\]\\]"))
      (when result-string
	(with-temp-buffer
	  (insert result-string)
	  (goto-char (point-min))
	  (while (re-search-forward fregex nil t)
	    (push (match-string 1) files)))
	(mapc (lambda (f)
		(when (f-exists? f)
		  (f-delete f)))
	      files))))
  (org-babel-remove-result)

  ;; scimax feature to restart
  (when (assoc :restart params)
    (let ((session (cdr (assoc :session (third (org-babel-get-src-block-info))))))
      (ob-ipython-kill-kernel
       (cdr (assoc session
		   (ob-ipython--get-kernel-processes))))
      (cl-loop for buf in (list (format "*Python:%s*" session)
				(format "*ob-ipython-kernel-%s*" session))
	       do
	       (when (get-buffer buf)
		 (kill-buffer buf)))))
  ;; I think this returns the results that get inserted by
  ;; `org-babel-execute-src-block'.
  (if (assoc :async params)
      (ob-ipython--execute-async body params)
    (ob-ipython--execute-sync body params)))


;; ** Fine tune the output of blocks
;; It was necessary to redefine these to get selective outputs via :display

(defun ob-ipython--execute-async (body params)
  (let* ((file (cdr (assoc :ipyfile params)))
         (session (cdr (assoc :session params)))
         (result-type (cdr (assoc :result-type params)))
         (sentinel (ipython--async-gen-sentinel))
	 ;; I added this. It is like the command in jupyter, but unfortunately
	 ;; similar to :display in the results from jupyter. This is to specify
	 ;; what you want to see.
	 (display-params (cdr (assoc :display params)))
	 (display (when display-params (mapcar 'intern-soft
					       (s-split " " display-params t)))))
    (ob-ipython--create-kernel (ob-ipython--normalize-session session)
                               (cdr (assoc :kernel params)))
    (ob-ipython--execute-request-async
     (org-babel-expand-body:generic (encode-coding-string body 'utf-8)
                                    params (org-babel-variable-assignments:python params))
     (ob-ipython--normalize-session session)

     `(lambda (ret sentinel buffer file result-type)
	(when ,display-params
	  (setf (cdr (assoc :display (assoc :result ret)))
		(-filter (lambda (el) (memq (car el) ',display))
			 (cdr (assoc :display (assoc :result ret)))))
	  (setf (cdr (assoc :value (assoc :result ret)))
		(-filter (lambda (el) (memq (car el) ',display))
			 (cdr (assoc :value (assoc :result ret))))))
	(let* ((replacement (ob-ipython--process-response ret file result-type)))
	  (ipython--async-replace-sentinel sentinel buffer replacement)))

     (list sentinel (current-buffer) file result-type))
    (format "%s - %s" (length ob-ipython--async-queue) sentinel)))


(defun ob-ipython--execute-sync (body params)
  "Execute BODY with PARAMS synchronously."
  (let* ((file (cdr (assoc :ipyfile params)))
         (session (cdr (assoc :session params)))
         (result-type (cdr (assoc :result-type params)))
	 ;; I added this. It is like the command in jupyter, but unfortunately
	 ;; similar to :display in the results from jupyter. This is to specify
	 ;; what you want to see.
	 (display-params (cdr (assoc :display params)))
	 (display (when display-params (mapcar 'intern-soft
					       (s-split " " display-params t)))))
    (ob-ipython--create-kernel (ob-ipython--normalize-session session)
                               (cdr (assoc :kernel params)))
    (-when-let (ret (ob-ipython--eval
                     (ob-ipython--execute-request
                      (org-babel-expand-body:generic
		       (encode-coding-string body 'utf-8)
		       params (org-babel-variable-assignments:python params))
                      (ob-ipython--normalize-session session))))
      ;; Now I want to filter out things not in the display we want. Default is everything.
      (when display-params
	(setf (cdr (assoc :display (assoc :result ret)))
	      (-filter (lambda (el) (memq (car el) display))
		       (cdr (assoc :display (assoc :result ret)))))
	(setf (cdr (assoc :value (assoc :result ret)))
	      (-filter (lambda (el) (memq (car el) display))
		       (cdr (assoc :value (assoc :result ret))))))
      (ob-ipython--process-response ret file result-type))))


(defun ob-ipython-format-output (file-or-nil output)
  "Format OUTPUT as a result.
This adds : to the beginning so the output will export as
verbatim text. FILE-OR-NIL is not used, and is here for
compatibility with the other formatters."
  (when (not (string= "" output))
    (s-join "\n"
  	    (mapcar (lambda (s)
  		      (s-concat ": " s))
  		    (s-split "\n" output t)))))


;; This gives me the output I want. Note I changed this to process one result at
;; a time instead of passing all the results to `ob-ipython--render.
(defun ob-ipython--process-response (ret file result-type)
  (let* ((result (cdr (assoc :result ret)))
	 (output (cdr (assoc :output ret)))
	 (value (cdr (assoc :value result)))
	 (display (cdr (assoc :display result))))
    (s-concat
     (if ob-ipython-suppress-execution-count
	 ""
       (format "# Out[%d]:\n" (cdr (assoc :exec-count ret))))
     (when (and (not (string= "" output)) ob-ipython-show-mime-types) "# output\n")
     (ob-ipython-format-output nil output)
     ;; I process the outputs one at a time here.
     (s-join "\n\n" (loop for (type . value) in (append value display)
			  collect
			  (ob-ipython--render file (list (cons type value))))))))


;; ** Formatters for output

(defun ob-ipython-format-text/plain (file-or-nil value)
  "Format VALUE for text/plain mime-types.
FILE-OR-NIL is not used in this function."
  (let ((lines (s-lines value)))
    ;; filter out uninteresting lines.
    (setq lines (-filter (lambda (line)
			   (not (-any (lambda (regex)
					(s-matches? regex line))
				      ob-ipython-plain-text-filter-regexps)))
			 lines))
    (when lines
      ;; Add verbatim start string
      (setq lines (mapcar (lambda (s) (s-concat ": " s)) lines))
      (when ob-ipython-show-mime-types
	(setq lines (append '("# text/plain") lines)))
      (s-join "\n" lines))))


(defun ob-ipython-format-text/html (file-or-nil value)
  "Format VALUE for text/html mime-types.
FILE-OR-NIL is not used in this function."
  (format "#+BEGIN_EXPORT html\n%s\n#+END_EXPORT" value))


(defun ob-ipython-format-text/latex (file-or-nil value)
  "Format VALUE for text/latex mime-types.
FILE-OR-NIL is not used in this function."
  (s-join "\n"
	  (list (if ob-ipython-show-mime-types "# text/latex" "")
		(format "#+BEGIN_EXPORT latex\n%s\n#+END_EXPORT" value))))


(defun ob-ipython-format-text/org (file-or-nil value)
  "Format VALUE for text/org mime-types.
FILE-OR-NIL is not used in this function."
  (s-join "\n" (list "# text/org" value)))


(defun ob-ipython--generate-file-name (suffix)
  "Generate a file name to store an image in.
I added an md5-hash of the buffer name so you can tell what file
the names belong to. This is useful later to delete files that
are no longer used."
  (s-concat (make-temp-name
	     (concat (f-join ob-ipython-resources-dir (if-let (bf (buffer-file-name))
							  (md5 (expand-file-name bf))
							"scratch"))
		     "-"))
	    suffix))


(defun ob-ipython-format-image/png (file-or-nil value)
  "Format VALUE for image/png mime-types.
FILE-OR-NIL if non-nil is the file to save the image in. If nil,
a filename is generated."
  (let ((file (or file-or-nil (ob-ipython--generate-file-name ".png"))))
    (ob-ipython--write-base64-string file value)
    (s-join "\n" (list
		  (if ob-ipython-show-mime-types "# image/png" "")
		  (format "[[file:%s]]" file)))))


(defun ob-ipython-format-image/svg+xml (file-or-nil value)
  "Format VALUE for image/svg+xml mime-types.
FILE-OR-NIL if non-nil is the file to save the image in. If nil,
a filename is generated."
  (let ((file (or file-or-nil (ob-ipython--generate-file-name ".svg"))))
    (ob-ipython--write-string-to-file file value)
    (s-join "\n"
	    (list
	     (if ob-ipython-show-mime-types "# image/svg" "")
	     (format "[[file:%s]]" file)))))


(defun ob-ipython-format-application/javascript (file-or-nil value)
  "Format VALUE for application/javascript mime-types.
FILE-OR-NIL is not used in this function."
  (format "%s#+BEGIN_SRC javascript\n%s\n#+END_SRC"
	  (if ob-ipython-show-mime-types "# application/javascript\n" "")
	  value))


(defun ob-ipython-format-default (file-or-nil value)
  "Default formatter to format VALUE.
This is used for mime-types that don't have a formatter already
defined. FILE-OR-NIL is not used in this function."
  (format "%s%s" (if ob-ipython-show-mime-types
		     (format "\n# %s\n: " (caar values))
		   ": ")
	  (cdar values)))


(defun ob-ipython--render (file-or-nil values)
  "VALUES is a list of (mime-type . value).
FILE-OR-NIL comes from a :ipyfile header value or is nil. It is
used for saving graphic outputs to files of your choice. It
doesn't make sense to me, since you can only save one file this
way, but I have left it in for compatibility."
  (let* ((mime-type (caar values))
	 (format-func (cdr (assoc mime-type ob-ipython-mime-formatters))))
    (if format-func
	(funcall format-func file-or-nil (cdar values))
      ;; fall-through
      (funcall
       (cdr (assoc 'default ob-ipython-mime-formatters))
       (cdar values)))))


;; ** Better exceptions
;; I want an option to get exceptions in the buffer
(defun ob-ipython--eval (service-response)
  (let ((status (ob-ipython--extract-status service-response)))
    (cond ((string= "ok" status) `((:result . ,(ob-ipython--extract-result service-response))
                                   (:output . ,(ob-ipython--extract-output service-response))
                                   (:exec-count . ,(ob-ipython--extract-execution-count service-response))))
          ((string= "abort" status) (error "Kernel execution aborted."))
          ((string= "error" status)
	   (if ob-ipython-exception-results
	       (let ((error-content
		      (->> service-response
			   (-filter (lambda (msg) (-contains? '("execute_reply" "inspect_reply")
							      (cdr (assoc 'msg_type msg)))))
			   car
			   (assoc 'content)
			   cdr)))
		 `((:result . ,(ob-ipython--extract-result service-response))
		   (:output . ,(org-no-properties
				(ansi-color-apply
				 (s-join "\n" (cdr (assoc 'traceback error-content))))))
		   (:exec-count . ,(ob-ipython--extract-execution-count service-response))))
	     (error (ob-ipython--extract-error service-response)))))))


;; I also want q to go to the offending line from a traceback buffer
(defun ob-ipython--create-traceback-buffer (traceback)
  "Create a traceback buffer.
Note, this does not work if you run the block async."
  (let ((current-buffer (current-buffer))
	(src (org-element-context))
	(buf (get-buffer-create "*ob-ipython-traceback*")))
    (with-current-buffer buf
      (special-mode)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (-each traceback
          (lambda (line) (insert (format "%s\n" line))))
        (ansi-color-apply-on-region (point-min) (point-max))))
    (pop-to-buffer buf)
    (let ((line (re-search-backward "-*> *\\([0-9]*\\) " nil t))
	  line-number)
      (when line
	(setq line-number (string-to-number (match-string 1)))
	(local-set-key "q" `(lambda ()
			      (interactive)
			      (quit-restore-window nil 'bury)
			      (pop-to-buffer ,current-buffer)
			      (goto-char ,(org-element-property :begin src))
			      (forward-line ,line-number)))))))


;; ** inspect from an org buffer
;; This makes inspect work from an org-buffer.

(defun ob-ipython-inspect (buffer pos)
  "Ask a kernel for documentation on the thing at POS in BUFFER."
  (interactive (list (current-buffer) (point)))
  (let ((return (org-in-src-block-p))
	(inspect-buffer))
    (when return
      (org-edit-src-code nil "*ob-ipython-src-edit-inspect*"))
    (let ((code (with-current-buffer buffer
		  (buffer-substring-no-properties (point-min) (point-max)))))
      (-if-let (result (->> (ob-ipython--inspect code pos)
			    (assoc 'text/plain)
			    cdr))
	  (setq inspect-buffer (ob-ipython--create-inspect-buffer result))
	(message "No documentation was found. Have you run the cell?")))

    (when return
      (with-current-buffer "*ob-ipython-src-edit-inspect*"
	(org-edit-src-exit)))
    (when inspect-buffer (pop-to-buffer inspect-buffer))))



;; * redefine org-show-entry

;; This function closes drawers. I redefine it here to avoid that. Maybe we will
;; find a fix for it one day.

(defun org-show-entry ()
  "Show the body directly following this heading.
Show the heading too, if it is currently invisible."
  (interactive)
  (save-excursion
    (ignore-errors
      (org-back-to-heading t)
      (outline-flag-region
       (max (point-min) (1- (point)))
       (save-excursion
	 (if (re-search-forward
	      (concat "[\r\n]\\(" org-outline-regexp "\\)") nil t)
	     (match-beginning 1)
	   (point-max)))
       nil)
      ;; (org-cycle-hide-drawers 'children)
      )))

(provide 'scimax-org-babel-ipython-upstream)

;;; scimax-org-babel-ipython-upstream.el ends here
