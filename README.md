# mux - Yazi plugin multiplexer

This Yazi plugin enables multiple previewers per previewer entry. One can specify the previewers to cycle through and a keybinding that triggers the cycle.

## Installation

```bash
ya pkg add peterfication/mux
```

## Configuration

### Example previewer configuration:

```toml
prepend_previewers = [
  { name = "*.csv", run = "mux code file" },
]
```

### Example keybinding:

```toml
[mgr]
prepend_keymap = [
  { on = "p", run = "mux next", desc = "Show next previewer" },
]
```

## How it works

It uses the params to determine which previewers to call and calls the current previewers `peek` and `seek` method accordingly.

## Use cases

### `eza` list and tree preview

(Like with the [eza-preview.yazi plugin](https://github.com/sharklasers996/eza-preview.yazi))

> NOTE: Requires the [piper plugin](https://github.com/yazi-rs/plugins/tree/main/piper.yazi).

```lua
-- init.lua
require("mux"):setup({
	aliases = {
		eza = {
			previewer = "piper",
			args = {
				"eza -a --oneline --color=always --icons=always --group-directories-first --no-quotes $1",
			},
		},
		eza_tree = {
			previewer = "piper",
			args = {
				"eza -T -a --color=always --icons=always --group-directories-first --no-quotes $1",
			},
		},
	},
})
```

```toml
# yazi.toml
[mgr]
prepend_keymap = [
  # Plugin: mux
  { on = "P", run = "plugin mux next", desc = "Cycle through mux previewers" },
]
```

```toml
# keymap.toml
[mgr]
prepend_keymap = [
  # Plugin: mux
  { on = "P", run = "plugin mux next", desc = "Cycle through mux previewers" },
]
```

### `duckdb` and `code` previewer

> NOTE: Requires the [duckdb plugin](https://github.com/wylie102/duckdb.yazi).

```toml
prepend_previewers = [
  { name = "*.csv", run = "mux duckdb code" },
  { name = "*.tsv", run = "mux duckdb code" },
  { name = "*.json", run = "mux duckdb code" },
  # ...
]
```

```toml
# keymap.toml
[mgr]
prepend_keymap = [
  # Plugin: mux
  { on = "P", run = "plugin mux next", desc = "Cycle through mux previewers" },
]
```

## Roadmap

- Support spotters
- Support fetchers?
- Remember current previewer of file type or suffix

## Development

See [previewer plugin docs](https://yazi-rs.github.io/docs/plugins/overview/#previewer).

Useful [just](https://github.com/casey/just) commands are defined in the [Justfile](Justfile).

```bash
just ci
```

## License

This project is licensed under the MIT license ([LICENSE](LICENSE) or [opensource.org/licenses/MIT](https://opensource.org/licenses/MIT))
