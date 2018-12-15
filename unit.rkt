#lang racket

;; TODO:
;; - [ ] Handle exceptions? -- This could easily be a simple user test macro.

(require (for-syntax syntax/parse))

;; A Test is either
;; - (any ... -> boolean?)
;; - (any ... -> test-result?)

(struct test-result (failure? message))

;; run-tests: Test ... -> void?
(define-syntax (test-begin stx)
  (syntax-parse stx
    [(_) #'(void)]
    [(_ ((~datum ignore) ignored-e ...)
        e:expr ...)
     (syntax/loc stx
       (begin
         ignored-e ...
         (test-begin e ...)))]
    [(_ test:expr e ...)
     (with-syntax ([fail-loc (test-stx->location-stx (syntax/loc stx test))])
       (quasisyntax/loc stx
         (begin
           (match test
             [(test-result #t msg)
              (register-test-failure! fail-loc msg)]
             [#f
              (register-test-failure! fail-loc)]
             [else
              (register-test-success!)])
           (test-begin e ...))))]))

(struct test-location (path line column))

(define-for-syntax (test-stx->location-stx test-stx)
  #`(test-location #,(syntax-source test-stx)
                   #,(syntax-line test-stx)
                   #,(syntax-column test-stx)))

(define (basename path)
  (define-values (_1 name _2) (split-path path))
  name)

(define/match (test-location->string loc)
  [{(test-location path line col)}
   (format "~a:~a:~a" (basename path) line col)])

(define-syntax-rule (++! v)
  (set! v (add1 v)))


(define (failure-extras->string extras)
  (if extras
      (string-append "\nmessage:  " extras)
      ""))


(define test-count 0)
(define test-count/failed 0)

(define (register-test-failure! loc [msg #f])
  (printf
   #<<HERE
--------------- FAILURE ---------------
location: ~a~a
---------------------------------------

HERE
   (test-location->string loc)
   (failure-extras->string msg))
  (++! test-count)
  (++! test-count/failed))

(define (register-test-success!)
  (++! test-count))

(define (display-test-results)
  (newline)
  (displayln
   (match* (test-count test-count/failed)
     [(n n)
      (format "Every test (~a) failed." n)]
     [(n 0)
      (format "All ~a tests passed." n)]
     [(total failed)
      (format "~a of ~a tests passed." (- total failed) total)])))





#;(define-syntax-rule (define-test-syntax stx)
  (syntax-parse stx
    [(_ id/sig:expr body:expr ...)
     #'()]))


(module+ test
  (test-begin
    (equal? 0 0)
    (equal? 2 2)
    (equal? 1 1))

  (test-begin
    (equal? 1 1)
    (equal? 2 2)
    (equal? 1 1)
    (test-result #t "hahaha"))

  (display-test-results))