# mux - Yazi previewer multiplexer

This [previewer plugin](https://yazi-rs.github.io/docs/plugins/overview/#previewer) enables multiple previewers per previewer entry. One can specify the previewers to cycle through and a keybinding that triggers the cycle.

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

It uses the params to determine which previewers to call and calls the currents previewer `peek` and `seek` method accordingly.

## Roadmap

- Support arguments passed down to previewers, e.g. to support [piper](https://github.com/yazi-rs/plugins/tree/main/piper.yazi). This will most likely lead to a breaking change because the passed in arguments need to be previewers plus their args.

## License

This project is licensed under the MIT license ([LICENSE](LICENSE) or [opensource.org/licenses/MIT](https://opensource.org/licenses/MIT))
