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

	local state_key_current = "current-" .. file_url
	local state_key_previewers = "previewers-" .. file_url

	local previewers = job.args
	local previews_count = #previewers

	if previews_count == 0 then
		ya.notify({ title = "mux", content = "No previewers configured", timeout = 2, level = "error" })
		return
	end

	set_state(state_key_previewers, previewers)

	local current = get_state(state_key_current) or 1
	-- Wrap around the current index to stay within the bounds of available previewers
	local current_mod = ((current - 1) % previews_count) + 1
	local previewer_name = previewers[current_mod]

	-- Remove the args from the job before calling the previewer because the args are the
	-- previewers list and not needed by the actual previewer.
	job.args = {}
	call_previewer(previewer_name, "peek", job)
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

	local state_key_current = "current-" .. file_url
	local state_key_previewers = "previewers-" .. file_url

	local previewers = get_state(state_key_previewers)
	local previews_count = #previewers

	if previews_count == 0 then
		ya.notify({ title = "mux", content = "No previewers configured", timeout = 2, level = "error" })
		return
	end

	local current = get_state(state_key_current) or 1
	-- Wrap around the current index to stay within the bounds of available previewers
	local current_mod = ((current - 1) % previews_count) + 1
	local previewer_name = previewers[current_mod]

	call_previewer(previewer_name, "seek", job)
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
	local hovered_url_string = get_hovered_url_string()
	ya.dbg({ title = "mux entry", args = job.args, file_url = hovered_url_string })

	local state_key = "current-" .. hovered_url_string
	local current = get_state(state_key) or 1

	local new_current = current + 1
	set_state(state_key, new_current)

	ya.emit("peek", { skip = 0, force = true })
end

return M
