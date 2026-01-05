# mux - Yazi plugin multiplexer

This Yazi plugin enables multiple previewers per previewer entry. One can specify the previewers to cycle through and a keybinding that triggers the cycle. It uses the args to determine which previewers to call and calls the current previewers `peek` and `seek` methods accordingly.

Credits to [@sxyazi](https://github.com/sxyazi) for the idea (see [issue comment](https://github.com/sxyazi/yazi/issues/3176#issuecomment-3307014021)).

[![asciicast](https://asciinema.org/a/746031.svg)](https://asciinema.org/a/746031)

## Installation

```bash
ya pkg add peterfication/mux
```

## Configuration

### Example previewer configuration

```toml
prepend_previewers = [
  { url = "*.csv", run = "mux code file" },
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

### Example setup (optional)

| Option                        | Default | Description                                                                                                                                                                                                                                                                                                                                                                    |
| ----------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `notify_on_switch`            | `false` | Whether to show a notification when the previewer is switched.                                                                                                                                                                                                                                                                                                                 |
| `remember_per_file_extension` | `false` | If `false`, the current previewer is remembered per file (per session). If `true`, the current previewer is remembered per suffix, so e.g. each JSON file will be previewed with the last selected previewer for JSON files. NOTE: this is without mime types yet, so folders and files without an extension will be treated the same, which will lead to unexpected behavior. |
| `aliases`                     | `{}`    | See "Use cases" for examples on how to use it.                                                                                                                                                                                                                                                                                                                                 |

> NOTE: Setup is only required if you want to change from the defaults.

```lua
require("mux"):setup({
  notify_on_switch = true, -- Default: false
  remember_per_file_extension = true, -- Default: false
  aliases = {}, -- Default: {}
})
```

## Use cases

### `eza` list and tree preview

(Like with the [eza-preview.yazi plugin](https://github.com/sharklasers996/eza-preview.yazi))

> NOTE: Requires the [piper plugin](https://github.com/yazi-rs/plugins/tree/main/piper.yazi).

Explanations:

- `cd` before `eza` makes sure that the root does not contain the full path
- `LS_COLORS` paints executables green, like yazi

```lua
-- init.lua
require("mux"):setup({
	aliases = {
		eza_tree_1 = {
			previewer = "piper",
			args = {
				'cd "$1" && LS_COLORS="ex=32" eza --oneline --tree --level 1 --color=always --icons=always --group-directories-first --no-quotes .',
			},
		},
		eza_tree_2 = {
			previewer = "piper",
			args = {
				'cd "$1" && LS_COLORS="ex=32" eza --oneline --tree --level 2 --color=always --icons=always --group-directories-first --no-quotes .',
			},
		},
		eza_tree_3 = {
			previewer = "piper",
			args = {
				'cd "$1" && LS_COLORS="ex=32" eza --oneline --tree --level 3 --color=always --icons=always --group-directories-first --no-quotes .',
			},
		},
		eza_tree_4 = {
			previewer = "piper",
			args = {
				'cd "$1" && LS_COLORS="ex=32" eza --oneline --tree --level 4 --color=always --icons=always --group-directories-first --no-quotes .',
			},
		},
	},
})
```

```toml
# yazi.toml
[plugin]
prepend_previewers = [
  { url = "*/", run = "mux eza_tree_1 eza_tree_2 eza_tree_3 eza_tree_4" },
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
  { url = "*.csv", run = "mux duckdb code" },
  { url = "*.tsv", run = "mux duckdb code" },
  { url = "*.json", run = "mux duckdb code" },
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

## Development

See [previewer plugin docs](https://yazi-rs.github.io/docs/plugins/overview/#previewer).

Useful [just](https://github.com/casey/just) commands are defined in the [Justfile](Justfile).

```bash
just ci
```

## License

This project is licensed under the MIT license ([LICENSE](LICENSE) or [opensource.org/licenses/MIT](https://opensource.org/licenses/MIT))
