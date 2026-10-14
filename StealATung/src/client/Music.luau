--!strict
-- Background music. With GameConfig.MusicId set, that track loops. Otherwise a
-- built-in procedural theme plays: an upbeat "tung tung tung" drum rhythm with
-- a whistled melody on top, built from pitched client sounds.
-- Music.Cut() silences it for the Mythic hype; Music.Chant() plays the deep
-- "TUNG... TUNG... TUNG..." chant.

local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Sounds = require(Shared.Config.Sounds)

local State = require(script.Parent.State)

local Music = {}

local BPM = 132
local BEAT = 60 / BPM / 2 -- eighth notes

-- 16-step pattern: T = "tung" knock, K = kick, . = rest
local DRUMS = { "T", ".", "T", ".", "T", ".", ".", "K", "T", ".", "T", ".", "T", "K", "K", "." }
-- whistle melody as semitone offsets (nil = rest), 32 steps
local MELODY: { number? } = { 0, nil, 4, nil, 7, nil, 4, nil, 9, nil, 7, nil, 4, 2, 0, nil, 0, nil, 4, nil, 7, nil, 12, nil, 11, nil, 9, nil, 7, nil, nil, nil }

local cutUntil = 0
local track: Sound? = nil
local pool: { [string]: { Sound } } = {}
local poolIndex: { [string]: number } = {}

local function volume(): number
	return State.settings.music
end

local function voice(name: string): Sound?
	local cue = Sounds[name]
	if not cue then
		return nil
	end
	if not pool[name] then
		local created: { Sound } = {}
		for k = 1, 4 do
			local s = Instance.new("Sound")
			s.Name = name .. k
			s.SoundId = cue.id
			s.Parent = SoundService
			created[k] = s
		end
		pool[name] = created
		poolIndex[name] = 0
	end
	local list = pool[name] :: { Sound }
	local i = ((poolIndex[name] or 0) % #list) + 1
	poolIndex[name] = i
	return list[i]
end

local function play(name: string, pitch: number, vol: number)
	local cue = Sounds[name]
	local s = voice(name)
	if not cue or not s then
		return
	end
	s.PlaybackSpeed = (cue.pitch or 1) * pitch
	s.Volume = (cue.volume or 0.5) * vol
	s.TimePosition = 0
	s:Play()
end

function Music.Cut(seconds: number)
	cutUntil = os.clock() + seconds
	if track then
		track.Volume = 0
	end
end

-- Deep "TUNG... TUNG... TUNG..." chant.
function Music.Chant(times: number?)
	task.spawn(function()
		for _ = 1, times or 3 do
			play("Chant", 1, math.max(0.4, State.settings.sfx))
			play("MusicTung", 0.55, math.max(0.4, State.settings.sfx) * 1.2)
			task.wait(0.9)
		end
	end)
end

function Music.Init()
	if GameConfig.MusicId ~= "" then
		local s = Instance.new("Sound")
		s.Name = "Theme"
		s.SoundId = GameConfig.MusicId
		s.Looped = true
		s.Volume = volume() * 0.5
		s.Parent = SoundService
		s:Play()
		track = s
		State.On("Settings", function()
			if os.clock() >= cutUntil then
				s.Volume = volume() * 0.5
			end
		end)
		task.spawn(function()
			while true do
				task.wait(0.5)
				if os.clock() >= cutUntil then
					s.Volume = volume() * 0.5
				end
			end
		end)
		return
	end

	task.spawn(function()
		local step = 0
		local nextTime = os.clock()
		while true do
			nextTime += BEAT
			local v = volume()
			if v > 0 and os.clock() >= cutUntil then
				local d = DRUMS[(step % #DRUMS) + 1]
				if d == "T" then
					play("MusicTung", if step % 4 == 0 then 1 else 1.12, v)
				elseif d == "K" then
					play("MusicKick", 1, v)
				end
				local note = MELODY[(step % #MELODY) + 1]
				if note ~= nil then
					play("MusicWhistle", 2 ^ (note / 12), v)
				end
			end
			step += 1
			local wait = nextTime - os.clock()
			if wait > 0 then
				task.wait(wait)
			else
				nextTime = os.clock()
				task.wait()
			end
		end
	end)
end

return Music
