default:
  just --list

# Run all steps from CI
ci: format lint test

# Format all files
format: format-lua format-rest

# Format lua files with stylua
format-lua:
  stylua .

# Format all other files with dprint
format-rest:
  dprint fmt

# Lint lua files with luacheck
lint:
  luacheck .

# Run tests
test:
  lua tests/main_spec.lua
