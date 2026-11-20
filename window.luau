--!strict
-- better-sessions, window half. Three parts:
--   1. Top tab bar: the current session's tabs as widget-bar widgets `better-sessions/tab-1` … `tab-10`
--      (settings.json `widgets`); a click runs `goto_tab:N`. better-sessions.css moves the bar into the top bar.
--   2. Session roots: a folder per session that new tabs and agent/shell blocks in it start in.
--   3. Sidebar layout: the vertical session list and the tab widgets, applied once on install and by command.
-- Nothing here opens tabs or sessions by itself: only commands and overrides the user triggers do.

-- 1. Top tab bar --------------------------------------------------------------------------------

local PLUGIN = "better-sessions"
local MAX_TABS = 10 -- goto_tab:N exists for 1..10 (Cmd+1 … Cmd+0)
local MAX_LABEL = 28
local REFRESH_MS = 1500 -- catches renames and title changes that fire no event

type Entry = { label: string, title: string, current: boolean }

local current: { Entry } = {}
local lastKey = ""

local function label(tab: any): string
	local text = if tab.name and tab.name ~= "" then tab.name else tab.title
	text = string.gsub(text or "", "%s+", " ")
	if utf8.len(text) and (utf8.len(text) :: number) > MAX_LABEL then
		local cut = utf8.offset(text, MAX_LABEL) or #text
		text = string.sub(text, 1, cut - 1) .. "…"
	end
	return text
end

local function snapshot(cx: any)
	if not cx then
		return
	end
	local session
	for _, s in cx.session:sessions() do
		if s.current then
			session = s
			break
		end
	end
	local byId = {}
	for _, t in cx.session:tabs() do
		byId[t.id] = t
	end
	local focused = cx.session:focused()
	local focusedTab = if focused then cx.session:tab_of(focused) else nil

	local list: { Entry } = {}
	local key = ""
	if session then
		for _, id in session.tabs do
			local t = byId[id]
			if t and #list < MAX_TABS then
				local e = { label = label(t), title = t.name or t.title or "", current = id == focusedTab }
				table.insert(list, e)
				key ..= e.label .. (if e.current then "*" else "") .. "\0"
			end
		end
	end
	current = list
	if key ~= lastKey then
		lastKey = key
		tern.chrome.refresh()
	end
end

for i = 1, MAX_TABS do
	tern.chrome.widget("tab-" .. i, {
		name = "Session tab " .. i,
		description = "Tab " .. i .. " of the current session; click to switch",
		render = function(_pane)
			local e = current[i]
			if not e then
				return nil
			end
			return {
				text = e.label,
				tone = if e.current then "accent" else "muted",
				title = e.title,
				command = "goto_tab:" .. i,
			}
		end,
	})
end

-- `window_start` fires once per window, not on a plugin reload, so the refresh loop starts at load;
-- timers hand the window context a fresh `cx`.
local pending: any = nil
local function tick(cx)
	snapshot(cx)
	pending = tern.timer(REFRESH_MS, tick)
end
pending = tern.timer(0, tick)

tern.on("window_start", snapshot)
tern.on("unload", function()
	if pending then
		pending:cancel()
	end
end)

for _, ev in { "focus", "tab_created", "tab_closed", "title", "pane_created", "pane_closed" } do
	tern.on(ev, function(_ev, cx)
		snapshot(cx)
	end)
end

-- 2. Session roots ------------------------------------------------------------------------------
-- kv `roots`: { [session id]: { path, name } } (name only for reading kv.json by hand).
-- kv `pending`: what host.luau's spawn hook gives the next pane; see there.

local ROOTS = "roots"
local ARMED = "pending"
-- Built-ins that open a new pane in the current session. Splits (Cmd+D) keep inheriting the
-- focused block's folder, so a split beside a worktree agent opens in that worktree.
local NEW_PANE_COMMANDS = { "new_tab", "new_agent_block", "new_shell_block" }

local HOME = tern.getenv("HOME") or ""

local function expand(text: string): string
	local path = string.match(text, "^%s*(.-)%s*$") or ""
	if path == "~" then
		path = HOME
	elseif string.sub(path, 1, 2) == "~/" then
		path = HOME .. string.sub(path, 2)
	end
	if #path > 1 then
		path = string.gsub(path, "/+$", "")
	end
	return path
end

local function tilde(path: string): string
	if HOME ~= "" and string.sub(path, 1, #HOME) == HOME then
		return "~" .. string.sub(path, #HOME + 1)
	end
	return path
end

-- tern.fs has no stat: listing succeeds only for a directory.
local function is_dir(path: string): boolean
	return string.sub(path, 1, 1) == "/" and (pcall(tern.fs.list, path))
end

local function root_of(session: number): string?
	local all = tern.kv.get(ROOTS)
	local entry = all and all[tostring(session)]
	return entry and entry.path
end

local function set_root(session: any, path: string?)
	local all = tern.kv.get(ROOTS) or {}
	all[tostring(session.id)] = if path then { path = path, name = session.name } else nil
	tern.kv.set(ROOTS, all)
end

-- Arms the host's spawn hook with the current session's root, then lets the built-in run.
local function arm(cx: any): boolean?
	local path = root_of(cx.sessions:current().id)
	if path and is_dir(path) then
		tern.kv.set(ARMED, { cwd = path, at = os.time() })
	elseif tern.kv.get(ARMED) then
		tern.kv.set(ARMED, nil)
	end
	return nil
end

for _, id in NEW_PANE_COMMANDS do
	tern.override(id, arm)
end

local function focused_cwd(cx: any): string?
	local pane = cx.session:focused()
	local info = pane and cx.session:pane(pane)
	if info and info.cwd and info.cwd ~= "" then
		return info.cwd
	end
	return nil
end

-- Asks for a folder; calls `done(path, cx)` with a validated absolute path.
local function ask_folder(cx: any, start: string?, placeholder: string, action: string, done: (string, any) -> ())
	cx:prompt({ value = tilde(start or HOME), placeholder = placeholder, action = action }):next(function(text, _err, cx2)
		if not text or not cx2 then
			return
		end
		local path = expand(text)
		if not is_dir(path) then
			cx2:toast("error", "Not a folder", text)
			return
		end
		done(path, cx2)
	end)
end

tern.command({
	id = "set_root",
	title = "Set session root…",
	run = function(cx)
		local session = cx.sessions:current()
		local start = root_of(session.id) or focused_cwd(cx)
		ask_folder(cx, start, "Folder new tabs in " .. session.name .. " start in", "set root", function(path, cx2)
			set_root(session, path)
			cx2:toast("success", "New tabs in " .. session.name .. " start in " .. tilde(path))
		end)
	end,
})

tern.command({
	id = "clear_root",
	title = "Clear session root",
	available = function(cx)
		return root_of(cx.sessions:current().id) ~= nil
	end,
	run = function(cx)
		local session = cx.sessions:current()
		set_root(session, nil)
		cx:toast("info", "New tabs in " .. session.name .. " start in the focused block's folder again")
	end,
})

tern.command({
	id = "new_session_at",
	title = "New session at folder…",
	run = function(cx)
		ask_folder(cx, focused_cwd(cx), "Root folder of the new session", "create", function(path, cx2)
			local name = string.match(path, "([^/]+)$") or path
			local session = cx2.sessions:create({ name = name, cwd = path })
			set_root(session, path)
		end)
	end,
})

tern.on("session_ended", function(ev: any, cx)
	snapshot(cx)
	if root_of(ev.session) then
		set_root({ id = ev.session }, nil)
	end
end)

-- 3. Sidebar layout -----------------------------------------------------------------------------
-- What better-sessions.css is styled for: the vertical session list (hidden until hovered) and the
-- tab widgets first in the widget bar. Other widgets stay, after them. Applied once when the plugin
-- first loads (kv `layout_applied`), and again whenever the command runs.

local function apply_layout(cx: any): (boolean, string?)
	local widgets = {}
	for i = 1, MAX_TABS do
		table.insert(widgets, { id = PLUGIN .. "/tab-" .. i })
	end
	for _, w in cx.settings:get("widgets") or {} do
		if string.sub(w.id, 1, #PLUGIN + 1) ~= PLUGIN .. "/" then
			table.insert(widgets, w)
		end
	end
	local ok, err = pcall(function()
		cx.settings:set_many({ tabs = "Vertical", tabs_autohide = true, widgets = tern.json.array(widgets) })
	end)
	if ok then
		tern.kv.set("layout_applied", true)
	end
	return ok, if ok then nil else tostring(err)
end

tern.command({
	id = "apply_layout",
	title = "Apply sidebar layout (vertical sessions, tabs on top)",
	run = function(cx)
		local ok, err = apply_layout(cx)
		if ok then
			cx:toast("success", "Sidebar layout applied")
		else
			cx:toast("error", "Could not apply the sidebar layout", err)
		end
	end,
})

if not tern.kv.get("layout_applied") then
	tern.timer(0, function(cx)
		if cx and not tern.kv.get("layout_applied") then
			local ok, err = apply_layout(cx)
			if not ok then
				cx:toast("error", "better-sessions could not apply its sidebar layout", err)
			end
		end
	end)
end
