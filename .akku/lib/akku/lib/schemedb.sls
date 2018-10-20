#!r6rs ;; -*- mode: scheme; coding: utf-8 -*-
;; Copyright © 2017-2018 Göran Weinholt <goran@weinholt.se>
;; SPDX-License-Identifier: GPL-3.0-or-later

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
#!r6rs

;; Scheme implementation database.

(library (akku lib schemedb)
  (export
    r6rs-builtin-library?
    r6rs-library-name*->implementation-name
    r7rs-builtin-library?
    r7rs-library-name*->implementation-name
    r6rs-implementation-names
    r7rs-implementation-names
    rnrs-implementation-name?
    r7rs-implementation-name?
    implementation-features
    ;; Quirks of library name handling in R6RS implementation.
    r6rs-library-name-mangle
    r6rs-library-omit-for-implementations
    r6rs-library-block-for-implementations)
  (import
    (rnrs (6))
    (xitomatl AS-match))

;; True if lib-name is a built-in library provided by the implementation.
(define (r6rs-builtin-library? lib-name implementation-name)
  (or (member lib-name r6rs-standard-libraries)
      (is-implementation-specific? lib-name implementation-name)))

(define (r7rs-builtin-library? lib-name implementation-name)
  (or (member lib-name r7rs-standard-libraries)
      (is-implementation-specific? lib-name implementation-name)))

(define (is-implementation-specific? lib-name implementation-name)
  (cond
    ((assq implementation-name implementation-specific-libraries)
     => (lambda (impl-spec)
          (let ((lib-pattern* (cdr impl-spec)))
            (exists (lambda (lib-pattern)
                      (match (list lib-name lib-pattern)
                        (((name0 . _) (name1 '*))
                         (eq? name0 name1))
                        (else
                         (equal? lib-name lib-pattern))))
                    lib-pattern*))))
    (else #f)))

(define implementation-specific-libraries
  '((chezscheme (scheme)
                (chezscheme *))
    (chibi (chibi)
           (chibi ast)
           (chibi filesystem)
           (chibi io)
           (chibi iset)
           (chibi iset optimize)
           (chibi net)
           (chibi process)
           (chibi system)
           (chibi time)
           (meta)
           (scheme box)
           (scheme charset)
           (scheme comparator)
           (scheme division)
           (scheme ephemeron)
           (scheme generator)
           (scheme hash-table)
           (scheme ilist)
           (scheme list-queue)
           (scheme list)
           (scheme red)
           (scheme small)
           (scheme sort)
           (scheme time tai-to-utc-offset)
           (scheme time tai)
           (scheme vector))
    (cyclone (scheme cyclone *))
    (guile (guile *)
           (ice-9 *))
    (ikarus (ikarus *))
    (ironscheme (ironscheme *))
    (kawa (kawa *)
          (class *))
    (larceny (primitives *)
             (larceny *)
             (rnrs eval reflection))    ;van Tonder macros
    (mosh (core *)
          (mosh *)
          (nmosh *)
          (primitives *)
          (system))
    ;; (mzscheme (scheme *))               ;XXX: conflicts with r7rs
    (rapid-scheme (rapid)
                  (rapid base)
                  (rapid primitive)
                  (rapid primitives)
                  (rapid runtime)
                  (rapid syntax-parameters))
    (sagittarius (sagittarius *))
    (vicare (ikarus *)
            (psyntax *)
            (vicare *))
    (ypsilon (core *)
             (time))))

(define r6rs-standard-libraries
  '((rnrs)
    (rnrs r5rs)
    (rnrs control)
    (rnrs eval)
    (rnrs mutable-pairs)
    (rnrs mutable-strings)
    (rnrs programs)
    (rnrs syntax-case)
    (rnrs files)
    (rnrs sorting)
    (rnrs base)
    (rnrs lists)
    (rnrs io simple)
    (rnrs bytevectors)
    (rnrs unicode)
    (rnrs exceptions)
    (rnrs arithmetic bitwise)
    (rnrs arithmetic fixnums)
    (rnrs arithmetic flonums)
    (rnrs hashtables)
    (rnrs io ports)
    (rnrs enums)
    (rnrs conditions)
    (rnrs records inspection)
    (rnrs records procedural)
    (rnrs records syntactic)))

(define r7rs-standard-libraries
  '((scheme base)
    (scheme case-lambda)
    (scheme char)
    (scheme complex)
    (scheme cxr)
    (scheme eval)
    (scheme file)
    (scheme inexact)
    (scheme lazy)
    (scheme load)
    (scheme process-context)
    (scheme read)
    (scheme repl)
    (scheme time)
    (scheme write)
    (scheme r5rs)))

;; Takes a library name and returns the name of the implementation
;; that supports it. If it's a portable library, then returns #f.
;; Uses the same names as in the .sls prefixes.
(define (r6rs-library-name->implementation-name lib-name)
  ;; TODO: Can be more accurate by knowing the names of identifiers
  ;; which are part of except/only/rename.
  (match lib-name
    (('chezscheme . _) 'chezscheme)
    (('scheme) 'chezscheme)             ;pretty common, legacy
    (('guile . _) 'guile)
    (('ikarus . _) 'ikarus)
    (('ironscheme . _) 'ironscheme)
    (('mosh . _) 'mosh)
    (('nmosh . _) 'mosh)
    (('sagittarius . _) 'sagittarius)
    (('vicare . _) 'vicare)
    (else #f)))

;; Takes a list of library names and determines which implementation
;; supports them.
(define (r6rs-library-name*->implementation-name lib-name*)
  (exists r6rs-library-name->implementation-name lib-name*))

;; Takes a library name and returns the name of the implementation
;; that supports it. If it's a portable library, then returns #f. In
;; particular, it should return #f for packaged libraries.
(define (r7rs-library-name->implementation-name lib-name)
  (let ((guess (match lib-name
                 (('chibi . _) 'chibi)
                 (('meta) 'chibi)
                 (('scheme . _) 'chibi) ;has many extra (scheme *) libs
                 (('kawa . _) 'kawa)
                 (('rapid . _) 'rapid-scheme)
                 (('scheme 'cyclone . _) 'cyclone)
                 (else #f))))
    (and guess (is-implementation-specific? lib-name guess) guess)))

;; Takes a list of library names and determines which implementation
;; supports them.
(define (r7rs-library-name*->implementation-name lib-name*)
  (exists r7rs-library-name->implementation-name lib-name*))

;; Implementation names matching <impl>.sls or cond-expand.
(define r6rs-implementation-names
  '(chezscheme
    guile
    ikarus
    ironscheme
    larceny
    mosh
    mzscheme
    sagittarius
    vicare
    ypsilon))

;; Implementation names matching cond-expand.
(define r7rs-implementation-names
  '(chibi
    chicken
    cyclone
    foment
    guache
    kawa
    larceny
    rapid-scheme
    sagittarius))

(define (rnrs-implementation-name? sym)
  (and (or (memq sym r6rs-implementation-names)
           (memq sym r7rs-implementation-names))
       #t))

(define (r7rs-implementation-name? sym)
  (and (memq sym r7rs-implementation-names) #t))

;; Standard features in R7RS:

;; r7rs
;; exact-closed
;; exact-complex
;; ieee-float
;; full-unicode
;; ratios
;; posix
;; windows
;; unix, darwin, gnu-linux, bsd, freebsd, solaris, ...
;; i386, x86-64, ppc, sparc, jvm, clr, llvm
;; ilp32, lp64, ilp64, ...
;; big-endian, little-endian

(define (implementation-features implementation-name)
  ;; FIXME: Fill in this table. Unfortunately there is a fundamental
  ;; problem with the target-dependent features like x86-64, which can
  ;; be detected for the running system, but will result in
  ;; non-portable files in .akku/lib.
  (define always-supported
    '(r7rs exact-closed exact-complex ieee-float full-unicode ratios))
  (append (case implementation-name
            [(rapid-scheme)
             '(posix rapid-scheme)]
            [else '()])
          (cons implementation-name always-supported)))

(define (colon-name? x)
  (let ((num (symbol->string x)))
    (and (> (string-length num) 0)
         (char=? #\: (string-ref num 0)))))

;; Some implementations want library names to be mangled. This returns
;; an alist mapping implementations to mangled names.
(define (r6rs-library-name-mangle lib-name)
  (match lib-name
    [('srfi (? colon-name? n) . _)
     ;; GNU Guile wants (srfi :1 lists) to be (srfi srfi-1). It
     ;; handles mangling the imports all by itself. This requires the
     ;; (srfi :1) library to be omitted from installation.
     (let* ((n (symbol->string n))
            (srfi-n (string->symbol
                     (string-append "srfi-" (substring n 1 (string-length n))))))
       (match lib-name
         [('srfi _n name . x*) (list (cons 'guile `(srfi ,srfi-n ,@x*)))]
         [else '()]))]
    [else '()]))

;; Implementations for which the library should be omitted from normal
;; installation procedures.
(define (r6rs-library-omit-for-implementations lib-name)
  (match lib-name
    ;; The (srfi :<n>) libs will conflict with (srfi :<n> name).
    [('srfi (? colon-name?))
     '(guile)]
    [('srfi srfi-n . _)
     ;; Some SRFIs are needed during the startup of Guile, so the
     ;; native versions must be used. Other ones would merely import
     ;; the native version.
     (if (memq srfi-n '(:6 :8 :13 :16 :19 :26 :39 :60 :64 :69
                           :2 :27 :67))
         '(guile)
         '())]
    (else '())))

;; Implementations for which the library should be blocked, by
;; constructing implementation-specific filenames that exclude these
;; implementations.
(define (r6rs-library-block-for-implementations lib-name)
  (match lib-name
    [else '()])))
