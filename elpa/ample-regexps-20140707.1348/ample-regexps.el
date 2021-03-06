;;; ample-regexps.el --- ample regular expressions for Emacs

;; Copyright (C) 2014 immerrr

;; Author: immerrr <immerrr@gmail.com>
;; Created: 22 Jun 2014
;; Version: 20140707.1348
;; X-Original-Version: 0.1
;; Keywords: regexps, extensions, tools

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Compose and reuse Emacs regular expressions with ease.
;;
;; If you ever tried to write more than a few of related regexps and it felt
;; that there should be a way to pick out their common parts and just plug them
;; in without worrying about grouping and precedence, this package is for you.
;;
;; It is implemented over the great Emacs package called `rx' that enables
;; structural regexp editing while avoiding the colorful jungles of backslashes
;; and spices it up with the ability to define your own subforms and use them
;; to construct readable and maintainable regexps.

;;; Code:

(require 'rx)
(require 'help-fns)

;; Make sure `rx-parent' is dynamically bound
(defvar rx-parent)

(defun arx--ensure-regexp (maybe-regexp)
  "Convert MAYBE-REGEXP to string if it is an rx form."
  (if (listp maybe-regexp)
      (rx-form maybe-regexp rx-parent)
    maybe-regexp))

(defun arx--quoted-literal (literal &optional form)
  "Regexp-quote and shy-group LITERAL as necessary.

When partially applied, can be added to `rx' constituents to
handle FORM."
  (rx-check (list form))
  (rx-form literal rx-parent))


(defun arx--apply-form-func (form-func form)
  "Apply FORM-FUNC to FORM, return result as regexp string.

When partially applied, can be added to `rx' constituents to
handle FORM."
  (rx-check form)
  (arx--ensure-regexp (apply form-func form)))


(defun arx--alias-rx-form (aliased-form form)
  "Convert ALIASED-FORM to string.

When partially applied, can be added to `rx' constituents to
handle FORM."
  (rx-check (list form))
  (rx-form aliased-form rx-parent))


(defun arx--bound-interval (interval lower upper)
  "Restrict INTERVAL with LOWER and UPPER boundaries.

INTERVAL is a list: (MIN MAX).
LOWER and UPPER may be nil, which means 'no boundary'.

Returned value is a list (MIN-MAYBE MAX-MAYBE), where MIN-MAYBE
is non-nil only if greater than 0 and MAX-MAYBE is non-nil only
if less than `most-positive-fixnum'."
  (let ((i-min (car interval))
        (i-max (cadr interval)))
    (when lower
      (setq i-min (max i-min lower)))
    (when upper
      (setq i-max (min i-max upper)))

    (list (when (< 0 i-min) i-min)
          (when (< i-max most-positive-fixnum) i-max))))


(defun arx--function-arity (func)
  "Get min and max number of arguments accepted by FUNC."
  (let ((arglist (help-function-arglist func))
        (min-args 0) max-args)
    ;; Count required arguments.
    (while (and arglist
                (not (memq (car arglist) '(&rest &optional))))
      (setq min-args (1+ min-args))
      (setq arglist (cdr arglist)))

    ;; Count optional arguments.
    (setq max-args min-args)
    (when (eq (car-safe arglist) '&optional)
      (setq arglist (cdr arglist))
      (while (and arglist
                  (not (eq (car arglist) '&rest)))
        (setq max-args (1+ max-args))
        (setq arglist (cdr arglist))))

    ;; If rest is present, assign max-args maxint.
    (list (1- min-args)
          (if (eq (car-safe arglist) '&rest)
              most-positive-fixnum
            (1- max-args)))))



(defun arx--to-rx (arx-form)
  "Convert ARX-FORM to rx format.

ARX-FORM must be list containing one element according to the
`define-arx' documentation."

  (unless (listp arx-form)
    (error "Form is not a list: %S" arx-form))

  (let* ((form-name (car arx-form))
         (form-defn (cadr arx-form)))
    (cons form-name
          (cond
           ((listp form-defn)
            (if (eq (car-safe form-defn) :func)
                (let* ((func (byte-compile (plist-get form-defn :func)))
                       (min-args (plist-get form-defn :min-args))
                       (max-args (plist-get form-defn :max-args))
                       (arity (arx--bound-interval (arx--function-arity func)
                                                   min-args max-args))
                       (predicate (plist-get form-defn :predicate)))
                  ;; fancy function definition
                  `( ,(apply-partially #'arx--apply-form-func func)
                     ,@arity ,predicate))
              ;; This doesn't work:
              ;;
              ;;     (list (lambda (form) (arx--alias-rx-form form-defn form))
              ;;           0 0)
              ;;
              ;; because of
              ;;
              ;;     Lisp error: (void-function closure)
              ;;
              ;; Why?
              (list (apply-partially #'arx--alias-rx-form form-defn) 0 0)))
           ((stringp form-defn)
            (list (apply-partially #'arx--quoted-literal form-defn) 0 0))

           ((symbolp form-defn)
            ;; already a valid rx form, do nothing
            form-defn)

           (t (error "Incorrect arx-form: %S" arx-form))))))

;;;###autoload
(defmacro define-arx (macro form-defs)
  "Generate a custom rx-like macro under name MACRO.

See `rx' for how the generated macro can be invoked.

FORM-DEFS is a list of custom s-exp definitions to create whose
elements have the form (SYM DEF), where DEF is one of
the following:

- \"LITERAL\" -- create a matcher to match a string literally

- (regexp \"LITERAL\") -- create a match given a regexp

- SYMBOL -- create an alias for a symbol either defined earlier
  on the list or provided by `rx'

- (SUBFORM ...) -- create an alias for an application of s-exp
  subform either defined earlier on the list or provided by `rx'

- (:func #'FORM-FUNC ...) -- create an s-exp definition

The most interesting here is the last variant.  When a
corresponding rx form will be encountered, FORM-FUNC will be
called with all elements of that form as arguments (with the
first one being the form symbol itself).  FORM-FUNC must then
return a valid s-exp or a properly grouped plain regexp.

Another keywords that are recognized in the plist are:
- :min-args -- minimum number of arguments for that form (default nil)
- :max-args -- minimum number of arguments for that form (default nil)
- :predicate -- if given, all rx form arguments must satisfy it"
  (let* ((evaluated-form-defs (eval form-defs))
         (form-defs-str (if evaluated-form-defs (format "\
Adds the following definitions to the ones supported by `rx':

%s
" evaluated-form-defs) ""))
         (macro-name (symbol-name macro))
         (macro-to-string (intern (concat macro-name "-to-string")))
         (macro-constituents (intern (concat macro-name "-constituents"))))
    `(progn
       (defvar ,macro-constituents nil
         ,(format
           "List of form definitions for `%s' and `%s-to-string' functions.
%s\

See variable `rx-constituents' for more information on list
elements."  macro-name macro-name form-defs-str))
       (setq ,macro-constituents (copy-sequence rx-constituents))
       (mapc (lambda (form)
               (when form
                 (push (arx--to-rx form) ,macro-constituents)))
             ,form-defs)

       (defun ,macro-to-string (form &optional no-group)
         ,(format "Parse and produce code for regular expression FORM.

FORM is a regular expression in sexp form as supported by `%s'.
NO-GROUP non-nil means don't put shy groups around the result." macro)
         (let ((rx-constituents ,macro-constituents))
           (rx-to-string form no-group)))

       (defmacro ,macro (&rest regexps)
         ,(format
           "Translate regular expressions REGEXPS in sexp form to a regexp string.

See function `rx' for more documentation on REGEXPS parameter.
%s\

See function `%s-to-string' for how to do such a translation at
run-time." form-defs-str macro-name)
         (cond ((null regexps)
                (error "No regexp"))
               ((cdr regexps)
                (,macro-to-string `(and ,@regexps) t))
               (t
                (,macro-to-string (car regexps) t)))))))

;;;###autoload
(defun arx-and (forms)
  "Generate an expression to match a sequence of FORMS."
  (let ((rx-parent (if (boundp 'rx-parent) rx-parent nil)))
    (if (null forms)
        ""
      (rx-and `(seq ,@forms)))))

;;;###autoload
(defun arx-or (forms)
  "Generate an expression to match one of FORMS."
  (let ((rx-parent (if (boundp 'rx-parent) rx-parent nil)))
   (if (> (length forms) 1)
       (rx-or `(or ,@forms))
     (arx-and forms))))

(provide 'ample-regexps)

;;; ample-regexps.el ends here
