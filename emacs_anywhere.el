(defvar ea-popup-hook nil
  "Functions run after entering Emacs Anywhere session.
Functions are run with args APP-NAME WINDOW-TITLE BROWSER-URL X Y WIDTH HEIGHT")

(defvar ea-on t)
(defvar ea-copy t)
(defvar ea-paste t)
(defvar ea-abort nil)

(defconst ea--buffer-name "*Emacs Anywhere*")

(defconst ea--osx (string-equal system-type "darwin"))
(defconst ea--gnu-linux (string-equal system-type "gnu/linux"))

(defun toggle-ea ()
  (interactive)
  (setq ea-on (not ea-on))
  (message
   "Emacs Anywhere: %s"
   (if ea-on "on" "off")))


(defun ea--osx-copy-to-clip ()
  (clipboard-kill-ring-save
   (point-min)
   (point-max)))


(defun ea--gnu-linux-copy-to-clip ()
  (write-region nil nil "/tmp/eaclipboard"))


(defun ea--delete-frame-handler (_frame)
  (remove-hook 'delete-frame-functions 'ea--delete-frame-handler)
  (ea--finish)
  )


(defun ea--finish ()
  "Turn EA off and kill the buffer and frame."
  (when (and ea-on ea-copy (get-buffer ea--buffer-name))
    (switch-to-buffer ea--buffer-name)
    (cond
     (ea--osx (ea--osx-copy-to-clip))
     (ea--gnu-linux (ea--gnu-linux-copy-to-clip))))
  (when ea-on
    (setq ea-on nil)
    (shell-command
     (format (concat "echo export EA_ABORT=%s\";\""
                     "export EA_SHOULD_COPY=%s\";\""
                     "export EA_SHOULD_PASTE=%s"
                     " > /tmp/eaenv")
             (if ea-abort "true" "false")
             (if ea-copy "true" "false")
             (if ea-paste "true" "false")))
    (kill-buffer ea--buffer-name)
    (delete-frame (selected-frame) t)))

(defun ea--edit-commit ()
  "Finish editing and commit changes."
  (interactive)
  (setq ea-abort nil)
  (ea--finish))

(defun ea--edit-abort ()
  "Finish editing and cancel changes."
  (interactive)
  (setq ea-abort t)
  (ea--finish))


(defvar ea--edit-minor-map nil
  "Keymap used in ea-edit-minor-mode.")

(unless ea--edit-minor-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-q C-q")   #'ea--edit-commit)
    (define-key map (kbd "C-q C-a")   #'ea--edit-abort)
    (setq ea--edit-minor-map map)))

(define-minor-mode ea--edit-minor-mode
  "Minor mode to help edit with Emacs Anywhere."

  :global nil
  :lighter ea--buffer-name
  :keymap ea--edit-minor-map

  ;; if disabling `undo-tree-mode', rebuild `buffer-undo-list' from tree so
  ;; Emacs undo can work
  )


(defun ea--init ()
  (setq ea-on t)                        ; begin each session with EA enabled
  (setq ea-copy t)                      ; begin each session with copy enabled
  (setq ea-paste t)                     ; begin each session with paste enabled
  (add-hook 'delete-frame-functions #'ea--delete-frame-handler)
  (switch-to-buffer ea--buffer-name)
  (select-frame-set-input-focus (selected-frame))
  (yank)
  (run-hook-with-args 'ea-popup-hook
                      ea-app-name
                      ea-window-title
                      ea-browser-url
                      ea-x
                      ea-y
                      ea-width
                      ea-height)
  (ea--edit-minor-mode))


(ea--init)
