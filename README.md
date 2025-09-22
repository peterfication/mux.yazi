# mux - Yazi plugin multiplexer

This Yazi plugin enables multiple previewers per previewer entry. One can specify the previewers to cycle through and a keybinding that triggers the cycle. It uses the args to determine which previewers to call and calls the current previewers `peek` and `seek` methods accordingly.

Credits to [@sxyazi](https://github.com/sxyazi) for the idea (see [issue comment](https://github.com/sxyazi/yazi/issues/3176#issuecomment-3307014021)).

[![asciicast](https://asciinema.org/a/18RMMPd1YoB2wqaUxsFf4Z6Sn.svg)](https://asciinema.org/a/18RMMPd1YoB2wqaUxsFf4Z6Sn)

## Installation

```bash
ya pkg add peterfication/mux
```

## Configuration

### Example previewer configuration

```toml
prepend_previewers = [
  { name = "*.csv", run = "mux code file" },
  # ...
]
```

### Example keybinding

```toml
[mgr]
prepend_keymap = [
  { on = "p", run = "mux next", desc = "Show next previewer" },
  # ...
]
```

### Example setup

| Option             | Default | Description                                                    |
| ------------------ | ------- | -------------------------------------------------------------- |
| `notify_on_switch` | `false` | Whether to show a notification when the previewer is switched. |
| `aliases`          | `{}`    | See "Use cases" for examples on how to use it.                 |

> NOTE: Setup is only required if you want to change from the defaults.

```lua
require("mux"):setup({
  notify_on_switch = true, -- Default: false
  aliases = {}, -- Default: {}
})
```

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
prepend_previewers = [
  { name = "*/", run = "mux eza eza_tree" },
  # ...
]
```

```toml
# keymap.toml
[mgr]
prepend_keymap = [
  # Plugin: mux
  { on = "P", run = "plugin mux next", desc = "Cycle through mux previewers" },
  # ...
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
  # ...
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
