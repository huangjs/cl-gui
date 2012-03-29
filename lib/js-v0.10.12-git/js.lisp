(in-package :cl-js)

;; Float special values

#+sbcl
(progn
  (defmacro without-traps (&body body)
    `(sb-int:with-float-traps-masked (:overflow :invalid :divide-by-zero) ,@body))
  (defun make-nan-helper (x) ;; It's not so easy to get a NaN value on SBCL
    (sb-int:with-float-traps-masked (:overflow :invalid :divide-by-zero)
      (- x sb-ext:double-float-positive-infinity)))
  (defparameter *nan* (make-nan-helper sb-ext:double-float-positive-infinity)))

(defparameter *float-traps*
  #+(or allegro sbcl) nil
  #-(or allegro sbcl) t)

(defmacro wrap-js (&body body)
  #+sbcl
  `(sb-int:with-float-traps-masked (:overflow :invalid :divide-by-zero)
     ,@body)
  #-sbcl `(progn ,@body))

(defmacro infinity ()
  #+allegro #.excl:*infinity-double*
  #+sbcl sb-ext:double-float-positive-infinity
  #-(or allegro sbcl) :Inf)
(defmacro -infinity ()
  #+allegro #.excl:*negative-infinity-double*
  #+sbcl sb-ext:double-float-negative-infinity
  #-(or allegro sbcl) :-Inf)
(defmacro nan ()
  #+allegro #.excl:*nan-double*
  #+sbcl '*nan*
  #-(or allegro sbcl) :NaN)
(defmacro is-nan (val)
  #+allegro `(and (excl::nan-p ,val) t)
  #+sbcl (let ((name (gensym)))
           `(let ((,name ,val))
              (and (floatp ,name) (sb-ext:float-nan-p ,name))))
  #-(or allegro sbcl) `(eq ,val :NaN))

;; Intended for from-lisp use
(defun js-funcall (func &rest args)
  (wrap-js
    (apply (the function (proc func)) nil args)))

;; Indented for use inside of JS code
(defmacro js-call (func this &rest args)
  `(funcall (the function (proc ,func)) ,this ,@args))
(defmacro js-method (obj name &rest args)
  (let ((o (gensym)))
    `(let ((,o ,obj))
       (js-call ,(expand-cached-lookup o name) ,o ,@args))))

(defun wrap-js-lambda (args body)
  (let ((other nil))
    (labels ((add-default (args)
               (cond ((not args) (setf other t) '(&rest other-args))
                     ((eq (car args) '&rest) args)
                     ((symbolp (car args))
                      (cons (list (car args) :undefined) (add-default (cdr args))))
                     (t (cons (car args) (add-default (cdr args)))))))
      (setf args (cons '&optional (add-default args))))
    `(lambda (this ,@args)
       (declare (ignorable this ,@(and other '(other-args))))
       ,@body)))
(defmacro js-lambda (args &body body)
  (wrap-js-lambda args body))

(defun compile-eval (code)
  (funcall (compile nil `(lambda () (with-ignored-style-warnings ,code)))))

(defun translate-js-string (str)
  (translate-ast (parse-js-string str)))

;; Conditions

(define-condition js-condition (error)
  ((value :initarg :value :reader js-condition-value))
  (:report (lambda (e stream)
             (format stream "[js] ~a" (to-string (js-condition-value e))))))

(defun parse/err (string)
  (handler-case (parse-js-string string)
    (js-parse-error (e)
      (js-error :syntax-error (princ-to-string e)))))
