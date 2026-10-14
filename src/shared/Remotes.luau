--!strict
-- Single place that defines every remote. The server creates them; clients wait.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"State", -- server -> client: full player snapshot (droids, tokens, quests...)
	"Stats", -- server -> client: lightweight currency/income tick
	"Notify", -- server -> client: toast { text, kind }
	"Announce", -- server -> all: server-wide unbox announcements
	"ClickFx", -- server -> client: floating "+Scrap" at a world position
	"OpenUI", -- server -> client: open a panel (from ProximityPrompts)
	"Travelled", -- server -> client: hyperspace jump finished
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
