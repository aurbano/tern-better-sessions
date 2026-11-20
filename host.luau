--!strict
-- better-sessions, host half: starts a new pane in its session's root.
--
-- The spawn hook can't tell which session a pane is for, so the window half arms `pending`
-- ({ cwd, at }) just before running a built-in new-tab/new-block command; the next spawn takes it
-- once. A stale arm (no spawn followed, say) expires after TTL seconds, so a later unrelated spawn
-- (a restored pane, `tern new tab`) keeps its own directory.

local TTL = 3

tern.on("spawn", function(spec: any): any
	local armed = tern.kv.get("pending")
	if not armed then
		return nil
	end
	tern.kv.set("pending", nil)
	if os.time() - armed.at > TTL then
		return nil
	end
	spec.cwd = armed.cwd
	return spec
end)
