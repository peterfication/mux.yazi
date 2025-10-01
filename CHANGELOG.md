# Changelog

## Unreleased

- Rename remember_per_file_suffix to remember_per_file_extension
- Fix file suffix handling. `fs.cha` did not work.
- Fix error when no mux previewers are defined for a file type but the mux entry function is triggered on it

## 0.1.3 - 2025-09-24

- Add `remember_per_file_suffix` option. Default to `false`.

## 0.1.2 - 2025-09-19

- Add `notify_on_switch` option. Default to `false`.

## 0.1.1 - 2025-09-19

- Add alias for previewers to support more complex previewer definitions

## 0.1.0 - 2025-09-19

Initial release
