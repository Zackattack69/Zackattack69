--!strict
-- Client-side mirror of the player's data (the server is authoritative), local
-- settings, and a tiny event hub for the UI.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local State = {}
State.data = nil :: any
State.settings = {
	music = 0.5,
	sfx = 0.8,
	low = false,
	hideAuras = false,
}
State.settingsLoaded = false

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

-- Wraps the server dispatcher. Errors are shown as toasts automatically.
function State.Request(action: string, ...: any): (boolean, any)
	local args = table.pack(...)
	local ok, res = pcall(function()
		return Remotes.Function("Request"):InvokeServer(action, table.unpack(args, 1, args.n))
	end)
	if not ok or type(res) ~= "table" then
		State.Fire("Toast", "Connection hiccup, try again", "error")
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

-- Settings are applied locally right away and saved on the server.
function State.SetSetting(key: string, value: any)
	(State.settings :: any)[key] = value
	State.Fire("Settings")
	task.spawn(State.Request, "Settings", State.settings)
end

-- Number of Tungs in the base (filled slots).
function State.SlotsUsed(): number
	local n = 0
	if State.data and State.data.slots then
		for _ in State.data.slots do
			n += 1
		end
	end
	return n
end

function State.BaseFull(): boolean
	local d = State.data
	return d ~= nil and d.slotsMax ~= nil and State.SlotsUsed() >= d.slotsMax
end

function State.Init()
	Remotes.Event("State").OnClientEvent:Connect(function(snap)
		State.data = snap
		if not State.settingsLoaded and snap.settings then
			State.settingsLoaded = true
			for k, v in snap.settings do
				(State.settings :: any)[k] = v
			end
			State.Fire("Settings")
		end
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
		task.wait(3)
		while not State.data do
			pcall(function()
				Remotes.Function("Request"):InvokeServer("Sync")
			end)
			task.wait(3)
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
