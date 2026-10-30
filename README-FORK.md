# hx-fork — quick start

This directory is a self-contained Helix build for this fork: the `hx` binary,
its `runtime/` (grammars, queries, themes) and the file-explorer plugin.

```
hx-fork/
├── hx                     # the editor (this fork build)
├── runtime/               # shipped runtime, found automatically (hx dir + /runtime)
├── plugin/file-explorer/  # Steel plugin: file tree panel
├── README-FORK.md         # this file
└── FORK_CHANGELOG.md      # everything the fork changes, branch by branch
```

## Use

`hx` behaves exactly like Helix. If the installer ran with the default options,
`~/.local/bin/hx` already points here, so:

```sh
hx                     # current directory
hx path/to/file.rs     # a file
```

If you prefer to call it directly:

```sh
/path/to/hx-fork/hx
```

Make sure your shell finds it: `export PATH="$HOME/.local/bin:$PATH"`.

## Fork keys

| Key | Action |
|---|---|
| `space E` | Rust explorer panel: reveal the current file, docked left/right |
| `space P` | Steel plugin explorer (if `~/.config/helix/` was wired by the installer) |
| `space e` | classic file picker (unchanged) |

Inside the Rust panel: `j/k/h/l` navigate, `o` open, `a` create, `r` rename,
`d` delete, `/` search, `?` help, `q` close, `+/-` resize, `B`/`]`/`[` change root.
Panel placement and width:

```toml
[editor.explorer]
position = "left"   # or "right"
column-width = 36
```

Inside the plugin panel: `j/k/g/G` navigate, `l/h/o` expand/collapse/open,
`a/A` create file/folder, `r` rename, `d` delete (`y` then Enter), `?` help,
`q` close, `+/-` resize, `B/]/[` change root.

The plugin needs Steel enabled in this build (it is) and these three lines in
your config:

```scheme
;; ~/.config/helix/init.scm
(require "file-explorer/explorer.scm")
```
```scheme
;; ~/.config/helix/helix.scm
(require "file-explorer/explorer.scm")
(provide open-file-explorer)
```
```toml
# ~/.config/helix/config.toml
[keys.normal.space]
P = ":open-file-explorer"
```

## Uninstall

```sh
rm -rf ~/.local/hx-fork ~/.local/bin/hx
rm -rf ~/.config/helix/file-explorer
```

Then drop the `file-explorer` lines from `init.scm` / `helix.scm` and the
`space P` binding from `config.toml`.

## Version

`hx --version` prints `25.07.1 (<commit>)`: that number comes from upstream's
version file. Fork builds are identified by the release tag (`fork-YYYY.MM.DD`)
and the commit hash.
