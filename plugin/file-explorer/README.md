# file-explorer (Steel plugin)

Side-panel file tree for the experimental Helix plugin system (`Steel`), ported
from the semantics of [helix-editor/helix#5768](https://github.com/helix-editor/helix/pull/5768):
docked panel, tree navigation, reveal-from-current-file, help, root history and
create/rename/delete prompts.

## Requirements

A Helix build with the Steel plugin system: branch `steel-event-system`
(`cargo xtask steel`), see `STEEL.md` in that branch.

## Install

```sh
# 1. copy the plugin next to your config
cp -r plugin/file-explorer ~/.config/helix/file-explorer

# 2. load it
echo '(require "file-explorer/explorer.scm")' >> ~/.config/helix/init.scm

# 3. expose the command (helix.scm is the module that provides typed commands)
printf '(require "file-explorer/explorer.scm")\n(provide open-file-explorer)\n' >> ~/.config/helix/helix.scm

# 4. bind it
cat >> ~/.config/helix/config.toml <<'TOML'
[keys.normal.space]
E = ":open-file-explorer"
TOML
```

## Keys

| Key | Action |
|---|---|
| `j` / `k` | down / up |
| `g` / `G` | first / last |
| `h` | collapse folder, or move to the parent folder |
| `l` | expand folder |
| `o` | open file (closes the panel) / toggle folder |
| `a` | create file (prompt) |
| `A` | create folder (prompt) |
| `r` | rename (prompt) |
| `d` | delete (type `y` then Enter) |
| `B` | root = parent of current root |
| `]` | root = selected folder |
| `[` | previous root |
| `+` / `-` | widen / narrow the panel |
| `?` | toggle help |
| `q` | close panel |

The panel docks on the left by resizing the editor area (`set-editor-clip-left!`);
width is local to the plugin (default 32 columns).

## Known gaps of the plugin API

The plugin surface in the Steel branch does not expose `KeyCode` (only
`key-event-char`), so `<esc>`, `<enter>` and arrows cannot be bound from Scheme;
the plugin uses letters only, and the prompts confirm with `<enter>` through the
editor prompt component. There is also no direct "open path" command: the plugin
uses the typed command wrapper `helix.open` (plus `helix.write` for file
creation).

## Prior art

- [`Ra77a3l3-jar/oil.hx`](https://github.com/Ra77a3l3-jar/oil.hx) (MIT): oil.nvim-style
  file manager over a buffer.
- `nicoburniske/nook`, `modules/helix/plugins/cogs/file-tree/*` (no license file,
  code not reused here).
- `mattwparas/helix-config`, `cogs/file-tree.scm` (no license file).
