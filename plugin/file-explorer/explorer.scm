;;; File explorer panel for Helix's Steel plugin system.
;;;
;;; Semantics ported from the Rust explorer of helix-editor/helix#5768:
;;; docked side panel, tree navigation, open file/folder, help, root changes,
;;; resizing, and create/rename/delete through prompts.
;;;
;;; Load from `init.scm`:                   (require "file-explorer/explorer.scm")
;;; Expose as a typed command in `helix.scm`: (provide open-file-explorer)
;;; then bind it, e.g. `[keys.normal] "space.E" = ":open-file-explorer"`.

(require "helix/components.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require (prefix-in helix.static. "helix/static.scm"))
(require (prefix-in helix. "helix/commands.scm"))

(provide open-file-explorer)

;;; ----------------------------------------------------------------- codice

(define (string-repeat s n)
  (if (<= n 0) "" (string-append s (string-repeat s (- n 1)))))

(define (string-take s n)
  (define len (string-length s))
  (if (<= len n)
      s
      (let loop ([i 0] [acc '()])
        (if (>= i n)
            (list->string (reverse acc))
            (loop (+ i 1) (cons (string-ref s i) acc))))))

(define (slash-at-end? s)
  (and (> (string-length s) 0)
       (char=? (string-ref s (- (string-length s) 1)) #\/)))

(define (path-join base name)
  (if (slash-at-end? base)
      (string-append base name)
      (string-append base "/" name)))

(define (basename path) (file-name path))

;;; ------------------------------------------------------------------ lists

(define (path-member? path paths)
  (cond [(empty? paths) #f]
        [(equal? (car paths) path) #t]
        [else (path-member? path (cdr paths))]))

(define (path-remove path paths)
  (cond [(empty? paths) '()]
        [(equal? (car paths) path) (path-remove path (cdr paths))]
        [else (cons (car paths) (path-remove path (cdr paths)))]))

(define (index-of path paths)
  (let loop ([rest paths] [i 0])
    (cond [(empty? rest) -1]
          [(equal? (car rest) path) i]
          [else (loop (cdr rest) (+ i 1))])))

;; Index of the entry whose path matches, entries being (path depth dir? open?) lists.
(define (entry-index-of path entries)
  (let loop ([rest entries] [i 0])
    (cond [(empty? rest) -1]
          [(equal? (list-ref (car rest) 0) path) i]
          [else (loop (cdr rest) (+ i 1))])))

;;; ------------------------------------------------------------------- tree

(define (dir-first-less? a b)
  (define a-dir (is-dir? a))
  (define b-dir (is-dir? b))
  (cond [(and a-dir (not b-dir)) #t]
        [(and b-dir (not a-dir)) #f]
        [else (string<? (basename a) (basename b))]))

(define (sorted-children path)
  (define (insert item lst)
    (cond [(empty? lst) (list item)]
          [(dir-first-less? item (car lst)) (cons item lst)]
          [else (cons (car lst) (insert item (cdr lst)))]))
  (define (loop rest acc)
    (if (empty? rest) acc (loop (cdr rest) (insert (car rest) acc))))
  (loop (read-dir path) '()))

;;; Each entry is (list path depth is-dir? is-opened?).
(define (visible-entries root opened)
  (define (walk path depth)
    (define (loop rest acc)
      (if (empty? rest)
          acc
          (let* ([child (car rest)]
                 [dir? (is-dir? child)]
                 [open? (and dir? (path-member? child opened))]
                 [entry (list child depth dir? open?)]
                 [sub (if open? (walk child (+ depth 1)) '())])
            (loop (cdr rest) (append acc (cons entry sub))))))
    (loop (sorted-children path) '()))
  (if (is-dir? root)
      (walk root 0)
      (list (list root 0 #f #f))))

;;; ------------------------------------------------------------------ state

(struct Explorer (root selected entries opened help? width history))

(define (selected-entry state)
  (define entries (unbox (Explorer-entries state)))
  (define idx (unbox (Explorer-selected state)))
  (if (and (> (length entries) 0) (< idx (length entries)))
      (list-ref entries idx)
      #f))

(define (refresh! state select-path)
  (define entries
    (visible-entries (unbox (Explorer-root state))
                     (unbox (Explorer-opened state))))
  (set-box! (Explorer-entries state) entries)
  (define count (length entries))
  (define wanted
    (if (equal? select-path #f)
        (unbox (Explorer-selected state))
        (entry-index-of select-path entries)))
  (set-box! (Explorer-selected state)
            (cond [(= count 0) 0]
                  [(< wanted 0) 0]
                  [(>= wanted count) (- count 1)]
                  [else wanted])))

(define (set-selected! state idx)
  (define count (length (unbox (Explorer-entries state))))
  (set-box! (Explorer-selected state)
            (cond [(= count 0) 0]
                  [(< idx 0) 0]
                  [(>= idx count) (- count 1)]
                  [else idx])))

(define (move-selection! state delta)
  (set-selected! state (+ (unbox (Explorer-selected state)) delta)))

(define (toggle-directory! state path)
  (define opened (unbox (Explorer-opened state)))
  (set-box! (Explorer-opened state)
            (if (path-member? path opened)
                (path-remove path opened)
                (cons path opened)))
  (refresh! state path))

(define (reset-view! state root)
  (set-box! (Explorer-root state) root)
  (set-box! (Explorer-opened state) '())
  (set-box! (Explorer-selected state) 0)
  (refresh! state #f))

(define (change-root! state new-root)
  (if (equal? (unbox (Explorer-root state)) new-root)
      #f
      (begin
        (set-box! (Explorer-history state)
                  (cons (unbox (Explorer-root state)) (unbox (Explorer-history state))))
        (reset-view! state new-root)
        #t)))

(define (previous-root! state)
  (define history (unbox (Explorer-history state)))
  (if (empty? history)
      #f
      (begin
        (set-box! (Explorer-history state) (cdr history))
        (reset-view! state (car history))
        #t)))

(define (parent-of path)
  (define cleaned (canonicalize-path path))
  (define parent (parent-name cleaned))
  (cond [(equal? parent #f) cleaned]
        [(equal? parent "") cleaned]
        [else parent]))

;;; --------------------------------------------------------------- acciones

(define (close-explorer! state)
  (set-box! (Explorer-help? state) #f)
  (set-editor-clip-left! 0)
  (pop-last-component-by-name! "file-explorer"))

(define (open-selected! state)
  (define entry (selected-entry state))
  (if (equal? entry #f)
      #f
      (let ([path (list-ref entry 0)]
            [dir? (list-ref entry 2)])
        (if dir?
            (toggle-directory! state path)
            (begin
              (close-explorer! state)
              (helix.open path)
              #t)))))

(define (explorer-directory state)
  ;; New entries land in the selected folder, or next to the selected file.
  (define entry (selected-entry state))
  (cond [(equal? entry #f) (unbox (Explorer-root state))]
        [(list-ref entry 2) (list-ref entry 0)]
        [else (parent-of (list-ref entry 0))]))

(define (prompt-create! state folder?)
  (define directory (explorer-directory state))
  (define label (if folder? " New folder in " " New file in "))
  (push-component!
   (prompt (string-append label directory ": ")
           (lambda (result)
             (if (> (string-length result) 0)
                 (let ([target (path-join directory result)])
                   (if folder?
                       (begin
                         (create-directory! target)
                         (refresh! state target))
                       (begin
                         (helix.open target)
                         (helix.write target)
                         ;; Opening and writing are queued as local jobs, so refresh
                         ;; once the editor has processed them.
                         (enqueue-thread-local-callback
                          (lambda () (refresh! state target))))))
                 (refresh! state #f))))))

(define (prompt-rename! state)
  (define entry (selected-entry state))
  (if (equal? entry #f)
      #f
      (let ([path (list-ref entry 0)])
        (push-component!
         (prompt (string-append " Rename " (basename path) " to: ")
                 (lambda (result)
                   (if (> (string-length result) 0)
                       (let ([target (path-join (parent-of path) result)])
                         (rename-file-or-directory! path target)
                         (refresh! state target))
                       (refresh! state #f))))))))

(define (prompt-delete! state)
  (define entry (selected-entry state))
  (if (equal? entry #f)
      #f
      (let ([path (list-ref entry 0)]
            [dir? (list-ref entry 2)])
        (push-component!
         (prompt (string-append " Delete " (if dir? "folder" "file")
                                " " (basename path) "? y/N: ")
                 (lambda (result)
                   (if (equal? result "y")
                       (begin
                         (if dir?
                             (delete-directory! path)
                             (delete-file! path))
                         (refresh! state #f))
                       (refresh! state #f))))))))

;;; ----------------------------------------------------------------- render

(define help-lines
  (list
   " file-explorer (Steel plugin)"
   ""
   " j / k     down / up"
   " g / G     first / last"
   " h         collapse or parent"
   " l         expand folder"
   " o         open file / toggle folder"
   " a         create file"
   " A         create folder"
   " r         rename"
   " d         delete"
   " B         root = parent of root"
   " ]         root = selected folder"
   " [         previous root"
   " + / -     widen / narrow"
   " ?         toggle help"
   " q         close panel"))

(define (render-help x y width height frame)
  (define base (theme-scope-ref "ui.text"))
  (define (loop rest i)
    (if (and (not (empty? rest)) (< i height))
        (begin
          (frame-set-string! frame x (+ y i) (string-take (car rest) width) base)
          (loop (cdr rest) (+ i 1)))
        #f))
  (loop help-lines 0))

(define (panel-row entry)
  (let* ([path (list-ref entry 0)]
         [depth (list-ref entry 1)]
         [dir? (list-ref entry 2)]
         [open? (list-ref entry 3)]
         [marker (if dir? (if open? "▾ " "▸ ") "  ")])
    (string-append (string-repeat "  " depth) marker (basename path))))

(define (draw-rows entries selected x y width height frame base highlighted)
  (define (loop i)
    (if (< i height)
        (begin
          (if (< i (length entries))
              (frame-set-string! frame
                                 x
                                 (+ y i)
                                 (string-take (panel-row (list-ref entries i)) width)
                                 (if (= i selected) highlighted base))
              #f)
          (loop (+ i 1)))
        #f))
  (loop 0))

(define (explorer-render state area frame)
  (log::info "EXPLORER-RENDER")
  (define entries (unbox (Explorer-entries state)))
  (define selected (unbox (Explorer-selected state)))
  (define width (area-width area))
  (define height (area-height area))
  (define x (area-x area))
  (define y (area-y area))
  (define base (theme-scope-ref "ui.text"))
  (define highlighted (style-with-reversed base))
  (frame-set-string! frame x y
                     (string-take (string-append "EXPLORER " (unbox (Explorer-root state)))
                                  width)
                     base)
  (draw-rows entries selected x (+ y 1) width (- height 1) frame base highlighted)
  (if (unbox (Explorer-help? state))
      (render-help x y width height frame)
      #f))

;;; ----------------------------------------------------------------- events

(define (handle-left state)
  (define entry (selected-entry state))
  (if (equal? entry #f)
      #f
      (let ([path (list-ref entry 0)]
            [dir? (list-ref entry 2)]
            [open? (list-ref entry 3)])
        (if (and dir? open?)
            (toggle-directory! state path)
            (refresh! state (parent-of path))))))

(define (explorer-handle-event state event)
  (define ch (key-event-char event))
  (cond
    [(equal? ch #\j) (move-selection! state 1)]
    [(equal? ch #\k) (move-selection! state -1)]
    [(equal? ch #\g) (set-selected! state 0)]
    [(equal? ch #\G) (set-selected! state 1000000)]
    [(equal? ch #\h) (handle-left state)]
    [(equal? ch #\l)
     (define entry (selected-entry state))
     (if (and (not (equal? entry #f))
              (list-ref entry 2)
              (not (list-ref entry 3)))
         (toggle-directory! state (list-ref entry 0))
         #f)]
    [(equal? ch #\o) (open-selected! state)]
    [(equal? ch #\a) (prompt-create! state #f)]
    [(equal? ch #\A) (prompt-create! state #t)]
    [(equal? ch #\r) (prompt-rename! state)]
    [(equal? ch #\d) (prompt-delete! state)]
    [(equal? ch #\B) (change-root! state (parent-of (unbox (Explorer-root state))))]
    [(equal? ch #\])
     (define entry (selected-entry state))
     (if (equal? entry #f)
         #f
         (change-root! state
                       (if (list-ref entry 2)
                           (list-ref entry 0)
                           (parent-of (list-ref entry 0)))))]
    [(equal? ch #\[) (previous-root! state)]
    [(equal? ch #\+)
     (set-box! (Explorer-width state) (+ (unbox (Explorer-width state)) 2))
     (set-editor-clip-left! (unbox (Explorer-width state)))]
    [(equal? ch #\-)
     (define current (unbox (Explorer-width state)))
     (set-box! (Explorer-width state) (if (< current 12) 12 (- current 2)))
     (set-editor-clip-left! (unbox (Explorer-width state)))]
    [(equal? ch #\?) (set-box! (Explorer-help? state)
                               (not (unbox (Explorer-help? state))))]
    [(equal? ch #\q) (close-explorer! state)]
    [else #f])
  event-result/consume)

;;; ------------------------------------------------------------------ entry

(define (current-root)
  (define focus (editor-focus))
  (define doc-id (editor->doc-id focus))
  (define path (editor-document->path doc-id))
  (cond [(equal? path #f) (canonicalize-path (helix.static.get-helix-cwd))]
        [else (parent-of (canonicalize-path path))]))

(define (open-file-explorer)
  (define state
    (Explorer (box (current-root))
              (box 0)
              (box '())
              (box '())
              (box #f)
              (box 32)
              (box '())))
  (refresh! state #f)
  (set-editor-clip-left! (unbox (Explorer-width state)))
  (push-component!
   (new-component! "file-explorer"
                   state
                   explorer-render
                   (hash "handle_event" explorer-handle-event)))
  (set-status! (string-append "explorer: " (unbox (Explorer-root state)))))

