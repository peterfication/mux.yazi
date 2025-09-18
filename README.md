# mux - Yazi previewer multiplexer

This [preview plugin](https://yazi-rs.github.io/docs/plugins/overview/#previewer) enables multiple previewers per previewer entry. One can specify the previewers to cycle through and a keybinding that triggers the cycle.

Example previewer configuration:

```toml
prepend_previewers = [
  { name = "*.csv", run = "mux duckdb code" },
]
```

Example keybinding:

```toml
[mgr]
prepend_keymap = [
  { on = "p", run = "mux next", desc = "Show next previewer" },
```

## How it works

It uses the params to determine which previewers to call and calls the currents previewer `peek` and `seek` method accordingly.
