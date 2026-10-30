;; Example wiring for the file-explorer plugin.
;;
;; Copy this directory next to your Helix config (`~/.config/helix/file-explorer/`),
;; then require it from `~/.config/helix/init.scm`:
;;
;;     (require "file-explorer/explorer.scm")
;;
;; and expose the command from `~/.config/helix/helix.scm` so `:open-file-explorer`
;; exists and can be bound in `config.toml`:
;;
;;     (require "file-explorer/explorer.scm")
;;     (provide open-file-explorer)
;;
;;     # config.toml
;;     [keys.normal.space]
;;     E = ":open-file-explorer"
(require "file-explorer/explorer.scm")
