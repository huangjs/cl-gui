;;; Initially taken from http://fare.tunes.org/files/fun/fibonacci.lisp

#+xcvb (module nil)

(cl:defpackage #:fare-memoization
  (:nicknames #:fmemo)
  (:use #:common-lisp)
  (:export #:memoize #:unmemoize
	   #:define-memo-function
	   #:memoizing #:memo-lambda
           #:memoized #:memoized-apply))

(in-package :fare-memoization)

;;; One may want to provide customized equality predicates and hashing functions for arguments,
;;; but that is not provided by CL hashing primitives.
(eval-when (:compile-toplevel :load-toplevel :execute)
(defun compute-memoized-function (f h args)
  "the basic helper for computing with a memoized function F,
with a hash-table H, being called with arguments ARGS"
  (multiple-value-bind (results foundp) (gethash args h)
    (if foundp (apply #'values results)
	(let ((results (multiple-value-list (apply f args))))
	  (setf (gethash args h) results)
	  (apply #'values results)))))
(declaim (inline compute-memoized-function))

(defun unmemoize (sym)
  "undoing the memoizing function, return the hash of memoized things so far"
  (let ((r (get sym :original-memoized-function)))
    (when r
      (setf (symbol-function sym) (car r))
      (remprop sym :original-memoized-function)
      (cdr r))))

(defun memoize (sym &optional (h (make-hash-table :test 'equal)))
  "a pretty generic memoizing function to speed things up"
  (unmemoize sym)
  (let ((f (symbol-function sym)))
    (setf (symbol-function sym)
	  #'(lambda (&rest args)
	      (compute-memoized-function f h args))
	  (get sym :original-memoized-function)
	  (cons f h))))

(defun memoizing (f &rest keys)
  (let ((h (apply #'make-hash-table :test 'equal keys)))
    #'(lambda (&rest args)
	(compute-memoized-function f h args))))

(defmacro memo-lambda (formals &body body)
  `(memoizing #'(lambda ,formals ,@body)))

;;(defmacro define-memo-function (name formals &body body)
;;  `(progn (defun ,name ,formals ,@body) (memoize ',name)))
(defmacro define-memo-function (name formals &body body)
  (let* ((args (gensym "ARGS"))
         (h (gensym "HASH"))
         (keys (when (consp name) (cdr name)))
         (name (if (consp name) (car name) name))
         (fun (gensym (symbol-name name))))
    `(let ((,h (make-hash-table :test 'equal ,@keys)))
       (defun ,name (&rest ,args)
         (labels ((,fun ,formals (block ,name ,@body))
                  (,name (&rest ,args) (compute-memoized-function #',fun ,h ,args)))
           (apply #',name ,args))))))

;;; This is your generic memoized function.
;;; If you want to make sure that a given function is only ever called once
;;; with the "same" list of arguments and thus ensure that it always returns
;;; the same value for a "same" list of arguments, it is up to YOU
;;; to normalize the arguments of the function you call such that EQUAL
;;; will properly compare argument lists. You may pass any additional
;;; arguments that you don't want memoized in dynamic variable bindings.
(define-memo-function memoized (fun &rest arguments)
  (apply fun arguments))

(defun memoized-apply (fun &rest args)
  (apply #'apply #'memoized fun args))

);eval-when
#|
;;; I wanted to provide a library function:
(define-memo-function make-the (class &rest keys)
  (apply #'make-instance (find-class class) keys))

;;; But there is no portable way to normalize initialization key list:
;;; not only do you have to sort the keys (which can be done portably as below,
;;; assuming they are all keywords), you first have to merge default initform's
;;; for slots -- and because in practice make-instance and shared-initialize
;;; methods are allowed to do things before, after and around the initform's
;;; depending on provided keys, you cannot do that in a portable way at all.
;;;
;;; In conclusion, if programmers want to have classes with objects that are
;;; interned in a table that ensures that two objects are EQ if their keys
;;; verify some equality predicate, they have to develop their own protocol.
;;; Things get even murkier when the creation of some object is requested,
;;; but an object already exists that has a similar keys, yet with other
;;; properties not covered by key equality that differ from the previously
;;; interned object. How are the two objects to be reconciled? This also
;;; requires application-dependent semantics that the protocol must allow
;;; the programmer to specify.
|#
