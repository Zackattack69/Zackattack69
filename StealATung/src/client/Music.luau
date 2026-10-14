--!strict
-- Background music.
--   * The main theme (GameConfig.MusicId) loops forever.
--   * During an event the music changes to fit it. If GameConfig.EventMusic has
--     its own track for that event, the theme crossfades into that track.
--     Otherwise the theme itself is re-mixed live to match the mood: dreamy for
--     Sahur Hour, light for Tung Rain, shiny for Golden Belt, faster for Speed
--     Belt, slow, dark and muffled for Thief Night, loud and bassy for Admin Abuse.
--   * Music.Cut(seconds) ducks it for the big Mythic spawn moment.

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local State = require(script.Parent.State)

local Music = {}

type Mood = {
	speed: number, -- playback speed (also changes pitch unless keepPitch)
	keepPitch: boolean?,
	low: number, -- equalizer gains in dB
	mid: number,
	high: number,
	reverb: number, -- 0..1
	chorus: number, -- 0..1
	tremolo: number, -- 0..1
	volume: number,
}

local NORMAL: Mood = { speed = 1, low = 0, mid = 0, high = 0, reverb = 0, chorus = 0, tremolo = 0, volume = 1 }

local MOODS: { [string]: Mood } = {
	-- late at night: slower, deeper, dreamy and mysterious
	SahurHour = { speed = 0.9, low = 3, mid = -2, high = -7, reverb = 0.7, chorus = 0.35, tremolo = 0, volume = 1 },
	-- free Tungs falling: a little quicker, light and sparkly
	TungRain = { speed = 1.06, low = 0, mid = 0, high = 3, reverb = 0.2, chorus = 0.45, tremolo = 0, volume = 1 },
	-- everything is gold: bright and shimmery
	GoldenBelt = { speed = 1.03, low = 1, mid = 0, high = 5, reverb = 0.35, chorus = 0.6, tremolo = 0, volume = 1 },
	-- same song, sped up (pitch kept)
	SpeedBelt = { speed = 1.25, keepPitch = true, low = 2, mid = 0, high = 1, reverb = 0, chorus = 0, tremolo = 0, volume = 1 },
	-- sneaky: slow, low and muffled, like hearing it through a wall
	ThiefNight = { speed = 0.84, low = 4, mid = -5, high = -16, reverb = 0.5, chorus = 0, tremolo = 0.3, volume = 0.9 },
	-- party: faster, punchy bass, a bit louder
	AdminAbuse = { speed = 1.12, low = 6, mid = 1, high = 2, reverb = 0.1, chorus = 0.2, tremolo = 0, volume = 1.15 },
}

local BASE_VOLUME = 0.5
local FADE = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local BLEND = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local theme: Sound? = nil
local eq: EqualizerSoundEffect
local reverb: ReverbSoundEffect
local chorus: ChorusSoundEffect
local tremolo: TremoloSoundEffect
local pitchFix: PitchShiftSoundEffect

local themeFade = Instance.new("NumberValue")
themeFade.Value = 1
local eventFade = Instance.new("NumberValue")
eventFade.Value = 0
local moodVolume = Instance.new("NumberValue")
moodVolume.Value = 1

local eventTrack: Sound? = nil
local currentKey = ""
local duckUntil = 0

-- Ducks the music for a moment (used by the Mythic spawn hype).
function Music.Cut(seconds: number)
	duckUntil = os.clock() + seconds
end

local function newSound(name: string, id: string): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	return s
end

local function effect<T>(className: string, parent: Instance): T
	local e = Instance.new(className)
	;(e :: any).Enabled = false
	e.Parent = parent
	return e :: any
end

-- Re-mixes the theme towards a mood (smoothly).
local function applyMood(m: Mood)
	local s = theme
	if not s then
		return
	end
	TweenService:Create(s, BLEND, { PlaybackSpeed = m.speed }):Play()
	TweenService:Create(eq, BLEND, { LowGain = m.low, MidGain = m.mid, HighGain = m.high }):Play()
	TweenService:Create(moodVolume, BLEND, { Value = m.volume }):Play()
	eq.Enabled = true
	reverb.Enabled = m.reverb > 0
	reverb.WetLevel = -20 + m.reverb * 16
	reverb.DecayTime = 1.2 + m.reverb * 2.5
	chorus.Enabled = m.chorus > 0
	chorus.Mix = m.chorus
	tremolo.Enabled = m.tremolo > 0
	tremolo.Depth = m.tremolo
	pitchFix.Enabled = m.keepPitch == true and m.speed ~= 1
	pitchFix.Octave = math.clamp(1 / m.speed, 0.5, 2)
end

local function eventKey(): string
	if Workspace:GetAttribute("AdminAbuse") then
		return "AdminAbuse"
	end
	local e = Workspace:GetAttribute("Event")
	return if type(e) == "string" then e else ""
end

local function onEventChanged()
	local key = eventKey()
	if key == currentKey then
		return
	end
	currentKey = key
	local eventMusic: { [string]: string } = (GameConfig :: any).EventMusic or {}
	local id = eventMusic[key] or ""

	-- leave the previous event's own track
	local old = eventTrack
	if old then
		eventTrack = nil
		TweenService:Create(eventFade, FADE, { Value = 0 }):Play()
		task.delay(FADE.Time + 0.1, function()
			old:Destroy()
		end)
	end

	if key ~= "" and id ~= "" then
		-- this event has its own song: fade the theme out and the event song in
		local s = newSound("EventMusic", id)
		s:Play()
		eventTrack = s
		eventFade.Value = 0
		TweenService:Create(eventFade, FADE, { Value = 1 }):Play()
		TweenService:Create(themeFade, FADE, { Value = 0 }):Play()
		applyMood(NORMAL)
	else
		-- re-mix the theme for this event (or back to normal)
		TweenService:Create(themeFade, FADE, { Value = 1 }):Play()
		applyMood(MOODS[key] or NORMAL)
	end
end

function Music.Init()
	if GameConfig.MusicId ~= "" then
		local s = newSound("Theme", GameConfig.MusicId)
		eq = effect("EqualizerSoundEffect", s)
		reverb = effect("ReverbSoundEffect", s)
		chorus = effect("ChorusSoundEffect", s)
		chorus.Depth = 0.45
		chorus.Rate = 0.6
		tremolo = effect("TremoloSoundEffect", s)
		tremolo.Frequency = 4
		pitchFix = effect("PitchShiftSoundEffect", s)
		s:Play()
		theme = s
	end

	-- one place sets the volumes: settings slider x mood x crossfade x duck
	RunService.Heartbeat:Connect(function()
		local duck = if os.clock() < duckUntil then 0.15 else 1
		local master = State.settings.music * BASE_VOLUME * duck
		local s = theme
		if s then
			local v = master * moodVolume.Value * themeFade.Value
			if math.abs(s.Volume - v) > 0.002 then
				s.Volume = v
			end
		end
		local e = eventTrack
		if e then
			local v = master * eventFade.Value
			if math.abs(e.Volume - v) > 0.002 then
				e.Volume = v
			end
		end
	end)

	Workspace:GetAttributeChangedSignal("Event"):Connect(onEventChanged)
	Workspace:GetAttributeChangedSignal("AdminAbuse"):Connect(onEventChanged)
	onEventChanged()
end

return Music
