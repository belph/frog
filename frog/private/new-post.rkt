#lang rackjure/base

(require racket/date
         racket/system
         rackjure/str
         rackjure/threading
         "params.rkt"
         "paths.rkt"
         "util.rkt")

(provide new-post
         enable-editor?)

(module+ test
  (require rackunit))

(define new-markdown-post-template
#<<EOF
    Title: ~a
    Date: ~a
    Tags: DRAFT

_Replace this with your post text. Add one or more comma-separated
Tags above. The special tag `DRAFT` will prevent the post from being
published._

<!-- more -->

EOF
)

(define new-scribble-post-template
#<<EOF
#lang scribble/manual

Title: ~a
Date: ~a
Tags: DRAFT

Replace this with your post text. Add one or more comma-separated
Tags above. The special tag `DRAFT` will prevent the post from being
published.

<!-- more -->

EOF
)

(define enable-editor? (make-parameter #f))
(define (get-editor . _)
  (or (getenv "EDITOR") (getenv "VISUAL")
      (raise-user-error 'new-post
        "EDITOR or VISUAL must be defined in the environment to use $EDITOR in .frogrc")))

(define (replace-$editor-in-current-editor)
  (regexp-replaces (current-editor) `([#rx"\\$EDITOR" ,get-editor])))

(define (new-post title [type 'markdown])
  (let ([extension (case type
                     [(markdown) ".md"]
                     [(scribble) ".scrbl"])]
        [template  (case type
                     [(markdown) new-markdown-post-template]
                     [(scribble) new-scribble-post-template])])
    (parameterize ([date-display-format 'iso-8601])
      (define d (current-date))
      (define filename (str (~> (str (date->string d #f) ;omit time
                                     "-"
                                     (~> title string-downcase))
                                our-encode)
                            extension))
      (define pathname (build-path (src/posts-path) filename))
      (cond
        [(file-exists? pathname)
         (unless (enable-editor?)
           (raise-user-error 'new-post "~a already exists." pathname))]
        [else
         (display-to-file* (format template
                                   title
                                   (date->string d #t)) ;do include time
                        pathname
                        #:exists 'error)])
      (displayln pathname)
      (when (enable-editor?)
        (system (editor-command-string 
                  (replace-$editor-in-current-editor)
                  (path->string pathname) 
                  (current-editor-command)))))))
