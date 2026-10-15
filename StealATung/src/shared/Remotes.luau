--!strict
-- Single place that defines every remote. The server creates them; clients wait.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"State", -- server -> client: full player snapshot
	"Stats", -- server -> client: lightweight money/income tick
	"Notify", -- server -> client: small toast { text, kind }
	"Alert", -- server -> client(s): big centre banner { text, color, kind, sound }
	"BeltAdd", -- server -> all: a Tung appeared on a belt
	"BeltRemove", -- server -> all: a belt Tung was bought / despawned
	"BeltSync", -- server -> client: every belt Tung (on join)
	"Hype", -- server -> all: rare spawn hype { level, tung, mut, entry }
	"CollectFx", -- server -> client: coins fly from a pad { pos, amount }
	"PlaceFx", -- server -> all: a Tung landed on a pad { pos, tung, mut }
	"WalkHome", -- server -> all: a dropped Tung walks back to its pad
	"RebirthFx", -- server -> all: Tungs fly into the sky + fireworks at a base
	"BonkFx", -- server -> all: bat hit at a position
	"OpenUI", -- server -> client: open a panel (from world prompts)
	"Trade", -- server -> client: trade request / window updates
	"Global", -- server -> all: cross-server chat broadcast (Mythic spawns)
	"Hatch", -- server -> client: an egg you bought hatched { egg, tung, mut }
}
local FUNCTIONS = {
	"Request", -- client -> server: every player action goes through one validated dispatcher
}

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		for _, name in EVENTS do
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = created
		end
		for _, name in FUNCTIONS do
			local f = Instance.new("RemoteFunction")
			f.Name = name
			f.Parent = created
		end
		created.Parent = ReplicatedStorage
		folder = created
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
