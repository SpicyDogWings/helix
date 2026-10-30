# Fork changelog — `SpicyDogWings/helix`

Personal fork of [helix-editor/helix](https://github.com/helix-editor/helix).
`master` is an exact mirror of upstream and is never modified; all work lives in
the branches listed below.

Fork builds are tagged `fork-YYYY.MM.DD`. They are **not** upstream releases and
they are not on the upstream track: see [Planned upstream](#planned-upstream).

---

## 2026.10.30 — file explorer side panel + Steel plugin system

Two tracks landed on the same date:

1. the **Rust side panel** rejected upstream as PR #5768, ported to current
   `master` and kept as the branch's main feature;
2. the **Steel plugin system** (draft PR #8675), merged on top of it so plugins
   can be loaded, plus a **file-explorer plugin** that reimplements the panel in
   Scheme.

### Added

| Area | Change | Commit |
|---|---|---|
| Rust explorer | `helix-term/src/ui/tree.rs` (2 678 l.) and `ui/explorer.rs` (1 464 l.): tree widget, panel, file ops, `/` search, `?` help, root history | `dbd690c25` |
| Rust explorer | `[editor.explorer]` config (`position = left/right`, `column-width = 36`) + `From<CloseError> for anyhow::Error` | `dbd690c25` |
| Rust explorer | Docked rendering and event routing in `ui/editor.rs`; `open_or_focus_explorer` and `reveal_current_file` commands; `space E` binding | `dbd690c25` |
| Rust explorer | Docs in `book/src/editor.md`, `book/src/keymap.md`; `static-cmd.md` regenerated | `dbd690c25` |
| Steel | Plugin system from draft PR #8675 (`PluginSystem` trait, optional `steel` cargo feature) | `424add100` (upstream head) |
| Steel | `plugin/file-explorer/`: tree panel as a Steel plugin (`explorer.scm`, 417 l. + README + init example) | `a63269388` |
| Merge | `personal` + Steel, conflicts resolved, builds with `--features steel` | `e5f19e00c`, `e9ced7f9f` |
| Release | `fork-2026.10.30` build (x86_64-linux), one-command installer, this changelog | tag `fork-2026.10.30` |

### Forced deviations from PR #5768

| What | Why |
|---|---|
| `space E` instead of the PR's `space e` | `space e` is the existing file picker; the `keymap!` macro panics on duplicate keys |
| `set_stringn(&str)`, `helix_stdx::path::normalize`, `Option<&Path>` for `Document::path` | The PR predates those API changes |
| `commands::Context.callback` is a `Vec`, callbacks are pushed | API change since the PR |
| `handle_events` is a `#[cfg(test)]` method on the `Component` trait | The PR's `impl dyn Component` does not resolve on a concrete component (E0599) |
| `events::register` guarded with `Once` | The registry panics on a second registration, which broke every unit test after the first editor |
| Not ported: the PR's `ui/overlay.rs` and `graphics.rs` refactor | Unrelated to the explorer and it would revert newer overlay behaviour |
| No preview pane | The PR itself removed it before freezing |

### Branches

| Branch | Base | Contents | Head |
|---|---|---|---|
| `master` | — | exact mirror of `helix-editor/helix` | `ba40e547` |
| `personal` | `master` | devbox environment, fork workflow docs, Rust explorer port | `dbd690c25` |
| `backup/personal-explorer-20261030` | `personal` | frozen snapshot of the state above | `dbd690c25` |
| `feature/steel-plugin-system` | `refs/pull/8675/head` | Steel plugin system, unmodified mirror of the draft head | `424add100` |
| `feature/explorer-as-plugin` | `backup/personal-explorer-20261030` | the file-explorer **as a Steel plugin** | `a63269388` |
| `feature/steel-with-explorer-plugin` | `feature/steel-plugin-system` | the plugin bundled inside the plugin-system branch | `ccc30242` |
| `feature/steel-on-personal` | `personal` + `feature/steel-plugin-system` | **the release branch**: Rust explorer + Steel, builds and runs | `e9ced7f9f` |

Worktrees used while developing (not required to use the branches):
`../helix-explorer-plugin`, `../helix-steel`, `../helix-merge-test`.

### Merge notes (`feature/steel-on-personal`)

Only three textual conflicts, plus two semantic breaks the textual merge could
not see:

| File | Resolution |
|---|---|
| `Cargo.lock` | take the plugin branch lock; no dependencies were added by the Rust explorer |
| `helix-term/src/ui/mod.rs` | keep both `mod explorer;` and `mod extension;` |
| `helix-term/src/compositor.rs` | keep `Component::name` (plugin system) next to the test-only `handle_events` helper |
| `helix-core/src/syntax.rs` | `rainbow_query` initialised with `OnceCell` while current `master` uses `std::sync::OnceLock`; switched to `OnceLock` |
| `helix-term/Cargo.toml` | re-added `once_cell = "1.21"`, which `commands/engine.rs` needs and the merge dropped |

### Verification performed

* `cargo build --locked --features steel` on `feature/steel-plugin-system` (4 m 26 s), binary runs: `hx --version` → `25.07.1 (424add10)`.
* `cargo build --features steel` on `feature/steel-on-personal`, binary runs → `25.07.1 (e5f19e00)`.
* `cargo test --workspace` on `personal`: all suites pass, including the 45 `helix-term` unit tests (`ui::tree::*`, `ui::explorer::*`).
* `cargo clippy -p helix-term -p helix-view --all-targets`: clean.
* Rust explorer in tmux: reveal current file, expand/collapse, `?` help, `:set explorer.position right`, `:set explorer.column-width 20`, create/rename/delete on a temporary fixture, `space e` picker regression, cold start with `[editor.explorer]` in a throwaway config.
* Steel plugin in tmux: panel renders (`▸/▾`, dirs first), `j/k/g/G`, `l/h/o` expand/collapse, `o` opens the selected file, `a` creates, `r` renames, `d` + `y`+Enter deletes, `?` help, `q` closes and restores the editor width.
* Both at once on the release branch: `space E` (Rust panel) and `:open-file-explorer` (plugin) render simultaneously in separate clips.

### Known gaps

* The plugin API does not expose `KeyCode`, only `key-event-char`: `<esc>`, `<enter>`
  and arrows cannot be bound from Scheme, so the plugin uses letters and the
  editor prompt component for confirmation.
* The plugin panel is a `Compositor` layer, not a `View`: `space w h/j/k/l`
  (`jump_view_*`) cannot reach it. See the design note in the plugin README.
* The plugin has no `/` search (the Rust explorer does).
* Plugin-driven file creation goes through `helix.open` + `helix.write`, so it
  briefly switches the focused buffer; the tree refresh is deferred with
  `enqueue-thread-local-callback`.
* `feature/steel-plugin-system` is a mirror; do not add fork commits to it or the
  next upstream rebase gets noisy.

### Planned upstream

Nothing here is being submitted right now; these are the pieces worth offering
when the time comes:

1. **Test helpers for the plugin system** (`Context::dummy_editor`,
   `dummy_jobs`, `Component::handle_events`) — required to unit-test plugin
   components, and currently missing from #8675.
2. **`OnceLock` / `once_cell` cleanup** in `helix-core/src/syntax.rs` and
   `helix-term/Cargo.toml` — the draft still mixes the two.
3. **A `Dock` trait / focusable panels** in the plugin system, so a panel can
   participate in `jump_view_*` instead of being an unreachable compositor layer.
   This is the TODO #5768 left in `ui/editor.rs`.
4. **Buffer-based explorer mode** (dirvish / oil style, aligned with PR #15220
   *editable directory buffer*): the only plugin-only way to get real `space w`
   focus, as it makes the panel an actual split.
5. **The Rust explorer itself** stays downstream: upstream marked #5768
   `R-wontfix` (file trees belong in plugins) and locked it.

### Version note

`--version` reports `25.07.1 (<commit>)` because it is derived from the upstream
version file. Fork builds are identified by the tag (`fork-2026.10.30`) and the
commit hash, not by that number.
