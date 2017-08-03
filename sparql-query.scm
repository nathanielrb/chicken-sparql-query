(module sparql-query *
(import chicken scheme extras data-structures srfi-1) 

(use srfi-13 srfi-69 http-client intarweb uri-common medea cjson matchable irregex)

(define *sparql-endpoint*
  (make-parameter
   "http://127.0.0.1:8890/sparql"))

(define *sparql-update-endpoint*
  (make-parameter
   "http://127.0.0.1:8890/sparql"))

(define *print-queries?* (make-parameter #t))

(define *namespaces* (make-parameter '()))

(define *expand-namespaces?* (make-parameter #t))

(define-inline (car-when p)
  (and (pair? p) (car p)))

(define-inline (cdr-when p)
  (and (pair? p) (cdr p)))

(define-inline (cons-when exp p)
  (if exp (cons exp p) p))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Namespaces 
(define (register-namespace name namespace)
  (*namespaces* (cons (list name namespace) (*namespaces*))))

(define (lookup-namespace name #!optional (namespaces (*namespaces*)))
  (car (alist-ref name namespaces)))

(define-syntax define-namespace
  (syntax-rules ()
    ((_ name namespace)
     (register-namespace (quote name) namespace))))

(define (expand-namespace-prefixes namespaces)
  (apply conc
	 (map (lambda (ns)
		(format #f "PREFIX ~A: <~A>~%"
			(car ns) (cadr ns)))
	      namespaces)))

(define (add-prefixes query)
  (format #f "~A~%~A"
	  (expand-namespace-prefixes (*namespaces*))
	  query))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Querying SPARQL Endpoints
(define sparql-headers (make-parameter '()))

(define (sparql-update query #!rest args)
  (let ((endpoint (*sparql-endpoint*))
        (query (apply format #f query args)))
    (when (*print-queries?*)
      (format (current-error-port) "~%~%==Executing Query==~%~%~A" (add-prefixes query)))
    (let-values (((result uri response)
		  (with-input-from-request 
		   (make-request method: 'POST
				 uri: (uri-reference endpoint)
				 headers: (headers (append
                                                    (sparql-headers)
                                                    '((content-type application/sparql-update)
                                                      (Accept application/json)))))
		   (add-prefixes query)
		   read-json)))
      (close-connection! uri)
      result)))

(define (json-unpacker unbinder)
  (lambda (results)
    (map (lambda (binding)
           (map unbinder binding))
         (vector->list
          (alist-ref 
           'bindings (alist-ref 'results (string->json results)))))))

(define untyped-binding
  (match-lambda
    ((var . bindings)
     (let ((value (alist-ref 'value bindings))
           (type (alist-ref 'type bindings)))
       (match type
         ("typed-literal"
          (let ((datatype (alist-ref 'datatype bindings)))
            (case datatype
              (("http://www.w3.org/2001/XMLSchema#integer")
               (cons var (string->number value)))
              (else (cons var value)))))
         (else (cons var value)))))))

(define unpack-bindings
  (json-unpacker untyped-binding))

(define *sparql-query-unpacker* (make-parameter unpack-bindings))

(define (sparql-select query #!rest args)
  (let ((endpoint (*sparql-endpoint*))
        (unpack (*sparql-query-unpacker*))
        (query (apply format #f query args)))
    (when (*print-queries?*)
	  (format (current-error-port) "~%==Executing Query==~%~A~%" (add-prefixes query)))
    (let-values (((result uri response)
		  (with-input-from-request 
		   (make-request method: 'POST
				 uri: (uri-reference endpoint)
				 headers: (headers (append
                                                    (sparql-headers)
                                                    '((Content-Type application/x-www-form-urlencoded)
                                                      (Accept application/json)))))
		   `((query . ,(add-prefixes query)))
                   read-string)))
      (close-connection! uri)
      (unpack result))))

(define (sparql-select-unique query #!rest args)
  (car-when (apply sparql-select query args)))

(define-syntax with-bindings
  (syntax-rules ()
    ((with-bindings (vars ...) bindings body ...)
     (let ((vars (alist-ref (quote vars) bindings)) ...)
       body ...))))

(define-syntax query-with-vars
  (syntax-rules ()
    ((_ (vars ...) query form ...)
     (map (lambda (bindings)
            (with-bindings (vars ...) bindings form ...))
	  (sparql-select query)))))

(define-syntax query-unique-with-vars
  (syntax-rules ()
    ((query-unique-with-vars (vars ...) query form)
     (car-when (query-with-vars (vars ...) query form)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Default definitions
(define-namespace foaf "http://xmlns.com/foaf/0.1/")
(define-namespace dc "http://purl.org/dc/elements/1.1/")
(define-namespace rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
(define-namespace owl "http://www.w3.org/2002/07/owl#")
(define-namespace skos "http://www.w3.org/2004/02/skos/core#")
)
