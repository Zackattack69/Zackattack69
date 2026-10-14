--!strict
-- Client-side mirror of the player's data (server is authoritative).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local State = {}
State.data = nil :: any
State.settings = {
	quickOpen = false,
	hideOthers = false,
	sfx = true,
}
State.notifications = {} :: { { text: string, kind: string, t: number } }
State.unread = 0

local listeners: { [string]: { (...any) -> () } } = {}

function State.On(event: string, fn: (...any) -> ())
	listeners[event] = listeners[event] or {}
	table.insert(listeners[event], fn)
end

function State.Fire(event: string, ...: any)
	local list = listeners[event]
	if list then
		for _, fn in list do
			task.spawn(fn, ...)
		end
	end
end

-- Wraps the server dispatcher. Errors are surfaced as toasts automatically.
function State.Request(action: string, ...: any): (boolean, any)
	local ok, res = pcall(function(...)
		return Remotes.Function("Request"):InvokeServer(action, ...)
	end, ...)
	if not ok or type(res) ~= "table" then
		State.Fire("Toast", "Connection hiccup — try again", "error")
		return false, nil
	end
	if not res.ok then
		if res.msg then
			State.Fire("Toast", res.msg, "error")
		end
		return false, res.msg
	end
	return true, res.data
end

function State.Init()
	Remotes.Event("State").OnClientEvent:Connect(function(snap)
		State.data = snap
		State.Fire("Changed", true)
	end)
	Remotes.Event("Stats").OnClientEvent:Connect(function(snap)
		if not State.data then
			return
		end
		for k, v in snap do
			State.data[k] = v
		end
		State.Fire("Changed", false)
	end)
	Remotes.Event("Notify").OnClientEvent:Connect(function(n)
		State.Fire("Toast", n.text, n.kind)
	end)
	-- Safety net: if the first snapshot arrived before we were listening, ask again.
	task.spawn(function()
		task.wait(2)
		while not State.data do
			pcall(function()
				Remotes.Function("Request"):InvokeServer("Sync")
			end)
			task.wait(2)
		end
	end)
end

function State.WaitForData(): any
	while not State.data do
		task.wait(0.1)
	end
	return State.data
end

return State
