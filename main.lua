local M = {}

-- Set plugin state
-- See https://yazi-rs.github.io/docs/plugins/overview#async-context
local set_state = ya.sync(function(state, key, value)
	state[key] = value
end)

-- Get plugin state
-- See https://yazi-rs.github.io/docs/plugins/overview#async-context
local get_state = ya.sync(function(state, key)
	ya.dbg({ title = "mux get_state", key = key })
	local value = state[key]

	if value == nil then
		ya.dbg({ title = "mux get_state", content = "key '" .. key .. "'not found, returning nil" })
		return nil
	else
		ya.dbg({ title = "mux get_state", content = "key '" .. key .. "' found, returning value", value = value })
		return value
	end
end)

-- Prefix for all state keys used by this plugin
local state_key_prefix = "mux-"
-- Define state option keys so that they are not hardcoded everywhere
local state_option_keys = {
	aliases = "aliases",
	notify_on_switch = "notify_on_switch",
	remember_per_file_extension = "remember_per_file_extension",
}

-- Generate state key for options.
--
-- Options are global and not per-file.
local function state_key_options(option_key)
	return state_key_prefix .. "-options-" .. option_key
end

-- Generate state key for the current previewer index.
--
-- It's based on the file URL to handle multiple files being previewed.
-- If remember_per_file_extension==true, use the file extension instead of the full URL.
-- But only if the file has an extension, otherwise use the full URL.
local function state_key_current(file_url)
	local remember_per_file_extension = get_state(state_key_options(state_option_keys.remember_per_file_extension))

	local state_key = file_url
	if remember_per_file_extension then
		ya.dbg({ title = "mux state_key_current", content = "Using file_extension for state key" })

		-- TODO: Get the actual mime type
		-- NOTE: without the mime type, folders and files without an extension will be treated the
		-- same, which will lead to unexpected behavior.

		local file_extension = string.match(file_url, "%.([^.]+)$")

		ya.dbg({ title = "mux state_key_current file_extension", file_extension = file_extension })

		state_key = file_extension or "unknown-or-folder"
	end

	return state_key_prefix .. "-current-" .. state_key
end

-- Generate state key for the previewers.
--
-- It's based on the file URL to handle multiple files being previewed.
local function state_key_previewers(file_url)
	return state_key_prefix .. "-previewers-" .. file_url
end

-- Needed for getting the file URL in entry function
-- See https://yazi-rs.github.io/docs/plugins/overview#async-context
local get_hovered_url_string = ya.sync(function()
	return tostring(cx.active.current.hovered.url)
end)

-- Dynamically load a previewer module/plugin by name
local function load_previewer(name)
	local ok, mod = pcall(require, name)
	if not ok then
		return nil, mod
	end

	if type(mod) ~= "table" then
		return nil, string.format("module '%s' did not return a table", name)
	end

	return mod, nil
end

-- Make sure the aliases table has a valid structure.
--
-- Example:
-- {
--   alias1 = { previewer = "plugin_name", args = { "arg1", "arg2" } },
--   alias2 = { previewer = "plugin_name2", args = { "arg1" } },
--   ...
-- }
local function validate_aliases(aliases)
	if type(aliases) ~= "table" then
		return false, "aliases must be a table"
	end

	for alias, alias_args in pairs(aliases) do
		if type(alias) ~= "string" then
			return false, "alias keys must be strings"
		end

		if type(alias_args) ~= "table" then
			return false, string.format("args for alias '%s' must be a table", alias)
		end

		local previewer_name = alias_args.previewer
		local args = alias_args.args

		if type(previewer_name) ~= "string" then
			return false, string.format("alias.previewer for '%s' alias must be a string", alias)
		end
		if type(args) ~= "table" then
			return false, string.format("alias.args for '%s' alias must be a table", alias)
		end
		-- Check each entry in args is a string
		for i, value in ipairs(args) do
			if type(value) ~= "string" then
				return false, string.format("arg %d for alias '%s' must be a string", i, alias)
			end
		end

		local mod, err = load_previewer(previewer_name)
		if not mod then
			return false, string.format("cannot load previewer '%s' for alias '%s': %s", previewer_name, alias, err)
		end

		if type(mod.peek) ~= "function" then
			return false, string.format("missing peek() in previewer '%s' for alias '%s'", previewer_name, alias)
		end

		if type(mod.seek) ~= "function" then
			return false, string.format("missing seek() in previewer '%s' for alias '%s'", previewer_name, alias)
		end
	end

	return true, nil
end

-- Show an error notification
local function show_error(error)
	ya.notify({ title = "mux error", content = error, timeout = 5, level = "error" })
end

-- Call the specified method of the specified previewer with the given job.
local function call_previewer(previewer_name, method, job)
	local previewer
	local aliases = get_state(state_key_options(state_option_keys.aliases)) or {}

	if aliases[previewer_name] then
		local alias = aliases[previewer_name]
		previewer = load_previewer(alias.previewer)
		job.args = alias.args
	else
		previewer = load_previewer(previewer_name)
	end

	if not previewer then
		show_error(string.format("cannot load previewer '%s'", previewer_name))
		return
	end

	local fn = previewer[method]
	if type(fn) ~= "function" then
		show_error(string.format("missing %s() in previewer '%s'", method, previewer_name))
		return
	end

	local ok, err = pcall(fn, previewer, job)

	if not ok then
		show_error(string.format("error in %s() of previewer '%s': %s", method, previewer_name, err))
		return
	end
end

-- Call the current previewer for the given file URL and method (peek or seek).
--
-- Get the relevant data from the state.
local function call_previewer_for_file_url(file_url, method, job)
	local previewers = get_state(state_key_previewers(file_url))
	local previewers_count = #previewers
	local current = get_state(state_key_current(file_url)) or 1

	if previewers_count == 0 then
		ya.notify({ title = "mux", content = "No previewers configured", timeout = 2, level = "error" })
		return
	end

	local current_previewer_name = previewers[current]
	call_previewer(current_previewer_name, method, job)
end

-- mux:peek
--
-- Forward the peek command to the current previewer for the currently previewed file.
--
-- - Get the URL of the currently previewed file
-- - Get the list of previewers for this file from the job args
-- - Store the previewers in the state
-- - Get the current previewer index fromt the state for the URL
-- - Call the current previewer peek() function with the job (without args)
function M:peek(job)
	local file_url = tostring(job.file.url)
	ya.dbg({ title = "mux peek", args = job.args, file_url = file_url })

	-- Store the previewers list in the state for seek and entry commands
	local previewers = job.args
	set_state(state_key_previewers(file_url), previewers)

	-- Remove the args from the job before calling the previewer because the args are the
	-- previewers list and not needed by the actual previewer.
	job.args = {}
	call_previewer_for_file_url(file_url, "peek", job)
end

-- mux:seek
--
-- Forward the seek command to the current previewer for the currently previewed file.
--
-- - Get the URL of the currently previewed file
-- - Get the list of previewers for this file from the state
-- - Get the current previewer index from the state for the URL
-- - Call the current previewer seek() function with the job
function M:seek(job)
	local file_url = tostring(job.file.url)
	ya.dbg({ title = "mux seek", args = job.args, file_url = file_url })

	call_previewer_for_file_url(file_url, "seek", job)
end

-- Advance the index but wrap around the count to stay in bounds.
local function advance_index(current, count)
	return (current % count) + 1
end

-- mux:entry
--
-- Advance to the next previewer for the currently hovered file.
--
-- - Get the URL of the currently hovered file
-- - Get the current previewer index for this URL
-- - Increment it
-- - Store it back
-- - Trigger a force peek to refresh the preview.
function M:entry(job)
	local file_url = get_hovered_url_string()
	ya.dbg({ title = "mux entry", args = job.args, file_url = file_url })

	local previewers = get_state(state_key_previewers(file_url))
	if not previewers or #previewers == 0 then
		ya.dbg({ title = "mux entry", message = "No previewers configured for this file" })
		ya.notify({
			title = "mux",
			content = "No previewers configured via mux for this file",
			timeout = 2,
			level = "error",
		})
		return
	end

	local previewers_count = #previewers
	local current = get_state(state_key_current(file_url)) or 1
	ya.dbg({ title = "mux entry", previewers = previewers })

	local new_current = advance_index(current, previewers_count)
	set_state(state_key_current(file_url), new_current)

	if get_state(state_key_options(state_option_keys.notify_on_switch)) then
		local new_previewer_name = previewers[new_current]
		ya.notify({
			title = "mux",
			content = string.format(
				"Switched to previewer %d/%d: %s",
				new_current,
				previewers_count,
				new_previewer_name
			),
			timeout = 1,
			level = "info",
		})
	end

	ya.emit("peek", { 0, force = true })
end

-- Plugin setup function
--
-- - Set the aliases for the plugin commands. See validate_aliases() for the required structure.
function M:setup(options)
	ya.dbg({ title = "mux setup", options = options })

	local aliases = options.aliases or {}
	local valid, err = validate_aliases(aliases)
	if not valid then
		show_error("mux setup error: " .. err)
		return
	end
	set_state(state_key_options(state_option_keys.aliases), aliases)

	local notify_on_switch = options.notify_on_switch or false
	set_state(state_key_options(state_option_keys.notify_on_switch), notify_on_switch)

	local remember_per_file_extension = options.remember_per_file_extension or false
	set_state(state_key_options(state_option_keys.remember_per_file_extension), remember_per_file_extension)
end

return M
