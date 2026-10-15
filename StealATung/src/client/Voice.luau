--!strict
-- Says things out loud with Roblox's built-in text-to-speech
-- (AudioTextToSpeech -> Wire -> AudioDeviceOutput). Used to announce a Tung's
-- name in a TikTok-style voice when you pick it up. The voice is
-- GameConfig.TtsVoice. If text-to-speech isn't available it just stays quiet.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Tungs = require(Shared.Config.Tungs)

local State = require(script.Parent.State)

local Voice = {}

local new: any = Instance.new -- the audio API classes are newer than the type definitions
local nextAllowed = 0

function Voice.Say(text: string)
	local volume = State.settings.sfx
	if volume <= 0 or os.clock() < nextAllowed then
		return
	end
	nextAllowed = os.clock() + 0.4 -- Roblox allows a few requests per second per player
	task.spawn(function()
		local ok, err = pcall(function()
			local tts = new("AudioTextToSpeech")
			tts.Text = string.sub(text, 1, 280)
			tts.VoiceId = (GameConfig :: any).TtsVoice or "4"
			tts.Speed = 1.1
			tts.Volume = math.clamp(volume * 1.6, 0, 3)
			local out = new("AudioDeviceOutput")
			local wire = new("Wire")
			tts.Parent = SoundService
			out.Parent = SoundService
			wire.SourceInstance = tts
			wire.TargetInstance = out
			wire.Parent = SoundService
			pcall(function()
				tts:LoadAsync()
			end)
			tts:Play()
			task.delay(8, function()
				wire:Destroy()
				out:Destroy()
				tts:Destroy()
			end)
		end)
		if not ok then
			warn("[Voice] text-to-speech unavailable:", err)
		end
	end)
end

function Voice.Init()
	local player = Players.LocalPlayer
	local last = player:GetAttribute("Holding")
	-- you picked up one of your Tungs: say its name
	player:GetAttributeChangedSignal("Holding"):Connect(function()
		local h = player:GetAttribute("Holding")
		if type(h) == "string" and h ~= "" and h ~= last then
			local id, mut = string.match(h, "^([^|]+)|?(.*)$")
			local t = id and Tungs.Get(id)
			if t then
				Voice.Say(Mutations.Prefix(if mut ~= "" then mut else nil) .. t.name)
			end
		end
		last = h
	end)
end

return Voice
