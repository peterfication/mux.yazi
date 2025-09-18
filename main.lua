local M = {}

-- Set plugin state
-- See https://yazi-rs.github.io/docs/plugins/overview#async-context
local set_state = ya.sync(function(state, key, value)
	state[key] = value
end)

-- Get plugin state
-- See https://yazi-rs.github.io/docs/plugins/overview#async-context
local get_state = ya.sync(function(state, key)
	return state[key]
end)

-- Prefix for all state keys used by this plugin
local state_key_prefix = "mux-"

-- Generate state key for the current previewer index.
--
-- It's based on the file URL to handle multiple files being previewed.
local function state_key_current(file_url)
	return state_key_prefix .. "-current-" .. file_url
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

-- Show an error notification
local function show_error(error)
	ya.notify({ title = "mux error", content = error, timeout = 5, level = "error" })
end

-- Call the specified method of the specified previewer with the given job.
local function call_previewer(previewer_name, method, job)
	local previewer = load_previewer(previewer_name)

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
	local previewers_count = #previewers
	local current = get_state(state_key_current(file_url)) or 1

	local new_current = advance_index(current, previewers_count)
	set_state(state_key_current(file_url), new_current)

	-- local new_previewer_name = previewers[new_current]
	-- ya.notify({
	-- 	title = "mux",
	-- 	content = string.format("Switched to previewer %d/%d: %s", new_current, previewers_count, new_previewer_name),
	-- 	timeout = 1,
	-- 	level = "info",
	-- })

	ya.emit("peek", { 0, force = true })
end

return M
