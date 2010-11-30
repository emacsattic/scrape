;;; scrape.el --- Emacs Lisp utilities for web scraping

;; Copyright (C) 2005, 2007  Edward O'Connor

;; Author: Edward O'Connor <hober0@gmail.com>
;; Keywords: convenience
;; Version: 1.0.0

;; This file is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the
;; Free Software Foundation; either version 2, or (at your option) any
;; later version.

;; This file is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING. If not, write to the Free
;; Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
;; MA 02110-1301, USA.

;;; Commentary:

;; This is a simple set of utilities that help to do website scraping in
;; Emacs Lisp. We shell out to HTML Tidy to do some of the dirty work.

;; You should use tidy.el if you're looking to use Tidy to clean up HTML
;; you're composing in Emacs.


;;; History:
;; 2005-10-27: Initial version.
;; 2007-08-10: Significantly augmented Tidy wrapper code.

;;; Code:

(require 'url)
(require 'xml)

(defvar scrape-tidy-program (executable-find "tidy")
  "The name of HTML Tidy on your system.")

(defvar scrape-tidy-flavor :xhtml
  "The flavor of HTML you'd like Tidy to output.
Valid values are `:html' and `:xhtml'.")

(defvar scrape-tidy-indent t
  "Non-null means HTML Tidy should indent elements.")

(defvar scrape-tidy-fill-column fill-column
  "If non-null, HTML Tidy will wrap markup at this column.")

;; FIXME: support these other Tidy options
;; -upper or -u   to force tags to upper case (default is lower case)
;; -clean or -c   to replace FONT, NOBR and CENTER tags by CSS
;; -bare or -b    to strip out smart quotes and em dashes, etc.
;; -access <level>
;;                to  do  additional accessibility checks (<level> = 1, 2,
;;                3)
;; -raw           to output values above 127 without conversion  to  enti-
;;                ties
;; -ascii         to use US-ASCII for output, ISO-8859-1 for input
;; -latin1        to use ISO-8859-1 for both input and output
;; -iso2022       to use ISO-2022 for both input and output
;; -utf8          to use UTF-8 for both input and output
;; -mac           to use MacRoman for input, US-ASCII for output
;; -utf16le       to use UTF-16LE for both input and output
;; -utf16be       to use UTF-16BE for both input and output
;; -utf16         to use UTF-16 for both input and output
;; -win1252       to use Windows-1252 for input, US-ASCII for output
;; -big5          to use Big5 for both input and output
;; -shiftjis      to use Shift_JIS for both input and output
;; -language <lang>
;;                to  set  the two-letter language code <lang> (for future
;;                use)
;; -config <file> to set configuration options from the specified <file>
;; -version or -v to show the version of Tidy
;; -errors or -e  to only show errors

(defun scrape-tidy-options ()
  "Assemble command line options for HTML Tidy based on your settings."
  (let ((options '("-quiet")))
    (when scrape-tidy-fill-column
      (push (format "-wrap %d" scrape-tidy-fill-column) options))
    (when scrape-tidy-indent
      (push "-indent" options))
    (cond ((eq scrape-tidy-flavor :xhtml)
           (push "-numeric" options)
           (push "-asxhtml" options))
          ((eq scrape-tidy-flavor :html)
           (push "-omit" options)
           (push "-ashtml" options)))
    options))

(defun scrape-tidy-command ()
  "Return the shell command for invoking HTML Tidy."
  (mapconcat (lambda (x) x)
             (cons scrape-tidy-program (scrape-tidy-options))
             " "))

(defun scrape-tidy-region (start end)
  "Run HTML Tidy over the region from START to END.
Returns (new-start . new-end)."
  (interactive "r")
  (save-restriction
    (widen)
    (narrow-to-region start end)
    (let ((error-buffer (get-buffer-create " *tidy-errors*")))
      (shell-command-on-region start end (scrape-tidy-command)
                               nil t error-buffer))
    (cons (point) (mark))))

(defun scrape-region (start end)
  "Scrape the HTML between points START and END."
  (let ((bounds (scrape-tidy-region start end)))
    (car (xml-parse-region (car bounds) (cdr bounds)))))

(defun scrape-buffer (&optional buffer)
  "Scrape the HTML residing in BUFFER.
If BUFFER is unspecified, the current buffer is used."
  (with-current-buffer (or buffer (current-buffer))
    (scrape-region (point-min) (point-max))))

(defun scrape-string (string)
  "Scrape the HTML residing in STRING."
  (with-temp-buffer
    (insert string)
    (scrape-buffer)))

(defvar url-http-end-of-headers)
(defvar scrape-debug nil)

(defun scrape-url (url)
  "Retrieve URL, run it through HTML Tidy, and return parsed XML."
  (let ((url-package-name (or url-package-name "scrape.el")))
    (let ((buffer (url-retrieve-synchronously url)))
      (with-current-buffer buffer
        ;; (delete-region (point-min) url-http-end-of-headers)
        (prog1 (scrape-region (point) (point-max))
          (if scrape-debug
              buffer
            (kill-buffer buffer)))))))

(provide 'scrape)
;;; scrape.el ends here
