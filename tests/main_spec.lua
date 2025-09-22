local plugin_state = {}
local notifications = {}
local emits = {}
local dbg_messages = {}
local previewer_calls = {}

local function shallow_copy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for k, v in pairs(value) do
		copy[k] = v
	end

	return copy
end

local function record_previewer_call(name, method, job)
	table.insert(previewer_calls, {
		name = name,
		method = method,
		args = shallow_copy(job.args),
	})
end

package.preload["test.previewer.one"] = function()
	local mod = {}

	function mod:peek(job)
		record_previewer_call("test.previewer.one", "peek", job)
	end

	function mod:seek(job)
		record_previewer_call("test.previewer.one", "seek", job)
	end

	return mod
end

package.preload["test.previewer.two"] = function()
	local mod = {}

	function mod:peek(job)
		record_previewer_call("test.previewer.two", "peek", job)
	end

	function mod:seek(job)
		record_previewer_call("test.previewer.two", "seek", job)
	end

	return mod
end

package.preload["test.previewer.error"] = function()
	local mod = {}

	function mod:peek(_)
		error("boom")
	end

	function mod:seek(job)
		record_previewer_call("test.previewer.error", "seek", job)
	end

	return mod
end

ya = {
	sync = function(fn)
		return function(...)
			return fn(plugin_state, ...)
		end
	end,

	notify = function(message)
		table.insert(notifications, message)
	end,

	dbg = function(message)
		table.insert(dbg_messages, message)
	end,

	emit = function(event, payload)
		table.insert(emits, { event = event, payload = payload })
	end,
}

cx = {
	active = {
		current = {
			hovered = {
				url = "file:///initial",
			},
		},
	},
}

local function tables_equal(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end

	for k, v in pairs(a) do
		if type(v) == "table" then
			if not tables_equal(v, b[k]) then
				return false
			end
		elseif b[k] ~= v then
			return false
		end
	end

	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end

	return true
end

local function assert_true(condition, message)
	if not condition then
		error(message or "assertion failed", 2)
	end
end

local function assert_equal(actual, expected, message)
	if actual ~= expected then
		error(message or string.format("expected %s, got %s", tostring(expected), tostring(actual)), 2)
	end
end

local function assert_table_equal(actual, expected, message)
	if not tables_equal(actual, expected) then
		error(message or "tables not equal", 2)
	end
end

local function assert_matches(value, pattern, message)
	if type(value) ~= "string" or not value:match(pattern) then
		error(message or string.format("value '%s' does not match pattern '%s'", tostring(value), pattern), 2)
	end
end

local M

local function reset_environment()
	plugin_state = {}
	notifications = {}
	emits = {}
	dbg_messages = {}
	previewer_calls = {}
	cx = {
		active = {
			current = {
				hovered = {
					url = "file:///initial",
				},
			},
		},
	}

	package.loaded["main"] = nil
	M = require("main")
end

local function set_hovered(url)
	cx.active.current.hovered.url = url
end

local tests = {}

local function test(name, fn)
	table.insert(tests, { name = name, fn = fn })
end

test("peek forwards job to the first previewer", function()
	reset_environment()

	local file_url = "file:///file1"
	local job = { args = { "test.previewer.one" }, file = { url = file_url } }

	M:peek(job)

	assert_equal(#previewer_calls, 1, "expected previewer.peek to be called once")
	local call = previewer_calls[1]
	assert_equal(call.name, "test.previewer.one")
	assert_equal(call.method, "peek")
	assert_table_equal(call.args or {}, {})
end)

test("seek reuses the current previewer", function()
	reset_environment()

	local file_url = "file:///file2"
	M:peek({ args = { "test.previewer.one" }, file = { url = file_url } })

	M:seek({ args = { "ignored" }, file = { url = file_url } })

	assert_equal(#previewer_calls, 2, "expected peek and seek calls")
	local seek_call = previewer_calls[2]
	assert_equal(seek_call.name, "test.previewer.one")
	assert_equal(seek_call.method, "seek")
end)

test("entry cycles to the next previewer and emits a forced peek", function()
	reset_environment()

	local file_url = "file:///file3"
	M:peek({ args = { "test.previewer.one", "test.previewer.two" }, file = { url = file_url } })

	set_hovered(file_url)
	M:entry({ args = {} })

	assert_equal(#emits, 1, "expected one emit call")
	local emit = emits[1]
	assert_equal(emit.event, "peek")
	assert_equal(emit.payload[1], 0)
	assert_true(emit.payload.force, "expected force flag to be true")

	M:seek({ args = {}, file = { url = file_url } })

	assert_equal(#previewer_calls, 2, "expected two previewer calls")
	local seek_call = previewer_calls[2]
	assert_equal(seek_call.name, "test.previewer.two")
	assert_equal(seek_call.method, "seek")
end)

test("setup aliases load the target previewer and pass args", function()
	reset_environment()

	M:setup({
		aliases = {
			alias = {
				previewer = "test.previewer.one",
				args = { "alpha", "beta" },
			},
		},
	})

	local file_url = "file:///file4"
	M:peek({ args = { "alias" }, file = { url = file_url } })

	assert_equal(#previewer_calls, 1)
	local call = previewer_calls[1]
	assert_equal(call.name, "test.previewer.one")
	assert_table_equal(call.args, { "alpha", "beta" })
end)

test("setup reports invalid aliases", function()
	reset_environment()

	M:setup({
		aliases = {
			alias = {
				previewer = "test.previewer.missing",
				args = {},
			},
		},
	})

	assert_equal(#notifications, 1, "expected an error notification")
	local notification = notifications[1]
	assert_equal(notification.title, "mux error")
	assert_matches(notification.content, "^mux setup error: ")
	assert_matches(notification.content, "cannot load previewer 'test%.previewer%.missing'")
end)

test("previewer errors surface as notifications", function()
	reset_environment()

	local file_url = "file:///file5"
	M:peek({ args = { "test.previewer.error" }, file = { url = file_url } })

	assert_equal(#notifications, 1, "expected one error notification")
	local notification = notifications[1]
	assert_equal(notification.title, "mux error")
	assert_matches(notification.content, "error in peek%(%) of previewer 'test%.previewer%.error':")
end)

test("with notify_on_switch, entry notifies", function()
	reset_environment()

	M:setup({ notify_on_switch = true })

	local file_url = "file:///file3"
	M:peek({ args = { "test.previewer.one", "test.previewer.two" }, file = { url = file_url } })

	set_hovered(file_url)
	M:entry({ args = {} })

	assert_equal(#emits, 1, "expected one emit call")
	assert_equal(#notifications, 1, "expected one notification")

	local notification = notifications[1]
	assert_equal(notification.title, "mux")
	assert_equal(notification.content, "Switched to previewer 2/2: test.previewer.two")
end)

local failures = 0

for _, case in ipairs(tests) do
	local ok, err = xpcall(case.fn, debug.traceback)

	if ok then
		print(string.format("PASS\t%s", case.name))
	else
		failures = failures + 1
		print(string.format("FAIL\t%s", case.name))
		print(err)
	end
end

if failures > 0 then
	os.exit(1)
end
