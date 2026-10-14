--!strict
-- Tiny event bus so services can react to each other without circular requires.
-- Events: "DroidsChanged"(player), "UpgradesChanged"(player), "Rebirthed"(player),
--         "WorldChanged"(player), "PassesChanged"(player)

local Bus = {}
local listeners: { [string]: { (...any) -> () } } = {}

function Bus.On(name: string, fn: (...any) -> ())
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], fn)
end

function Bus.Fire(name: string, ...: any)
	local list = listeners[name]
	if list then
		for _, fn in list do
			task.spawn(fn, ...)
		end
	end
end

return Bus
