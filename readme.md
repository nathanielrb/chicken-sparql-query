# sparql-query

Chicken Scheme module for querying SPARQL endpoints and managing namespaces.


#### Escaping SPARQL Values

IRIs can be represented as either symbols or strings; `sparql-escape` can be used to escape strings and booleans, as well as

- typed literals as a cons pair, where &lt;type&gt; can be a symbol or a string):

```
(sparql-escape '("val" . <type>))
;; => "\"val\"^^<type>"
```

- language-tagged strings as a cons pair,  where @lang can be a symbol or string:

```
(sparql-escape '("val" . @lang))
;; => "\"val\"@lang"
```
- a list of sparql elements plus a string to join them:

```
(sparql-escape '("Cat" "Dog" "Mouse") ", ")
;; => "\"Cat\", \"Dog\", \"Mouse\""
```

#### Executing Queries

The two main query procedures are `sparql-select` and `sparql-update`.

```
(define-namespace animals "http://example.org/animals")

(sparql-select 
  "SELECT ?s ?food
   FROM ~A
   WHERE {
      ?s a ~A.
      ?s ~A ~A.
      ?s animals:eats ?food.
      ?s animals:isHungry ~A.
      ?s animals:lastFed ~A.
      ?s animals:says ~A.
    }" 
  (*default-graph*)
  'animals:Cat 
  '<http://schema.org/title>
  (sparql-escape "Mr Cat")
  (sparql-escape #f)
  (sparql-escape '("2017-06-24" . <http://www.w3.org/2001/XMLSchema#dateTime>))
  (sparql-escape '("miaow" . @en)))

;; =>  '(((s . "http://example.org/animals/cat123") (food . "Whiskas"))
;;       ((s . "http://example.org/animals/cat003") (food . "Purina One")))
```

The special form `select-with-vars` wraps `sparql-select` with a `let` binding following the same naming. Its syntax is `(select-with-vars (vars ...) (query args ...) body)`.

```
(select-with-vars (s food)
  ("SELECT ?s ?food
    WHERE {
       ?s a ~A.
       ?s animals:isSpayed ~A.
       ?s ~A ~A.
       ?s animals:eats ?food
     }" 
   "animals:Cat"
   (sparql-escape #f)
   '<http://schema.org/title>
   (sparql-escape "Mr Cat"))

 `((cat . ((id . ,cat) (attributes . ,(conc "Likes " food))))))

;; => '(((cat . ((id . "http://example.org/animals/cat123") (attributes . "Likes Whiskas"))))
;;      ((cat . ((id . "http://example.org/animals/cat003") (attributes . "Likes Purina One")))))
```

In the above examples, JSON results are preprocessed by the function defined by the parameter *query-unpacker*. The default unpacker, as shown above, returns a list of association lists with bindings var/val pairs:

```
;; (*query-unpacker* sparql-bindings)  - default

(sparql-select query)

;; => '(((var1 . "string value") (var2 . 123)
;;       (var3 . "http://example.org/uri") (var4 . "2017-08-01")) ...)
```

Another unpacker, `typed-sparql-bindings` is defined to parse RDF datatypes as understood by `sparql-escape`:
n
```
(*query-unpacker* typed-sparql-bindings)

(sparql-select query)

;; => '(((var1 . "str-val") 
;;       (var2 . 123)
;;       (var3 . <http://example.org/uri>)
;;       (var4 . ("2017-08-01" . <http://www.w3.org/2001/XMLSchema#dateTime>))) ...)
```

To recover the unprocessed RDF JSON, we can also set `*query-unpacker*` to `string->json" or `values`:

```
(*query-unpacker* string->json)

(sparql-select query)

;; => '(((var1 . ((value "str-val") (type . "literal")))
;;       (var2 . ((value . "123") (type . "typed-literal") (datatype . "http://www.w3.org/2001/XMLSchema#integer")))
;;       (var3 . ((value . "http://example.org/uri") (type . "uri")))
;;       (var4 . ((value . "2017-08-01") (type . "typed-literal") (datatype . "http://www.w3.org/2001/XMLSchema#dateTime")))) ...)

(*query-unpacker* values)

(sparql-select query)

;; => "[ {\"var1\": { \"value\": ...} } ...]"
```
