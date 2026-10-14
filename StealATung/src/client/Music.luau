--!strict
-- Background music. Set GameConfig.MusicId to an uploaded looping track to
-- play a main theme; with no MusicId the game has no background music (the
-- old built-in drum loop was removed because its constant knocking got annoying).
-- Music.Cut() silences the theme for the Mythic hype; Music.Chant() plays the
-- deep "TUNG... TUNG... TUNG..." chant for Mythic spawns and Sahur Hour.

local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Sounds = require(Shared.Config.Sounds)

local State = require(script.Parent.State)

local Music = {}

local cutUntil = 0
local track: Sound? = nil

local function play(name: string, pitch: number, vol: number)
	local cue = Sounds[name]
	if not cue then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = cue.id
	s.PlaybackSpeed = (cue.pitch or 1) * pitch
	s.Volume = (cue.volume or 0.5) * vol
	s.Parent = SoundService
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
end

function Music.Cut(seconds: number)
	cutUntil = os.clock() + seconds
	if track then
		track.Volume = 0
	end
end

-- Deep "TUNG... TUNG... TUNG..." chant (only for rare moments).
function Music.Chant(times: number?)
	task.spawn(function()
		for _ = 1, times or 3 do
			play("Chant", 1, math.max(0.3, State.settings.sfx) * 0.8)
			task.wait(0.9)
		end
	end)
end

function Music.Init()
	if GameConfig.MusicId == "" then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Theme"
	s.SoundId = GameConfig.MusicId
	s.Looped = true
	s.Volume = State.settings.music * 0.5
	s.Parent = SoundService
	s:Play()
	track = s
	task.spawn(function()
		while true do
			task.wait(0.5)
			if os.clock() >= cutUntil then
				s.Volume = State.settings.music * 0.5
			end
		end
	end)
end

return Music
