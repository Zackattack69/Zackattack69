--!strict
-- Sound cues. Defaults are sounds bundled with the Roblox client, so the game
-- is audible out of the box; pitch (PlaybackSpeed) turns them into different
-- cues. Replace any `id` with your own upload ("rbxassetid://123...").

export type Cue = { id: string, pitch: number?, volume: number? }

local KNOCK = "rbxasset://sounds/collide.wav"
local PING = "rbxasset://sounds/electronicpingshort.wav"
local BASS = "rbxasset://sounds/bass.wav"
local VICTORY = "rbxasset://sounds/victory.wav"
local SWOOSH = "rbxasset://sounds/swoosh.wav"

local Sounds: { [string]: Cue } = {
	-- UI
	Pop = { id = "rbxasset://sounds/button.wav", pitch = 1.3, volume = 0.45 },
	Whoosh = { id = SWOOSH, pitch = 1.2, volume = 0.35 },
	Error = { id = "rbxasset://sounds/snap.wav", volume = 0.4 },
	Purchase = { id = PING, pitch = 1.2, volume = 0.5 },

	-- Gameplay
	Tung = { id = KNOCK, pitch = 0.8, volume = 0.7 }, -- hollow wooden knock (pitched per Tung size)
	ChaChing = { id = "rbxasset://sounds/clickfast.wav", pitch = 1.5, volume = 0.6 },
	Jackpot = { id = VICTORY, pitch = 1.15, volume = 0.6 },
	Place = { id = KNOCK, pitch = 1.1, volume = 0.6 },
	Puff = { id = SWOOSH, pitch = 0.7, volume = 0.3 },
	Swing = { id = "rbxasset://sounds/swordslash.wav", pitch = 0.8, volume = 0.5 },
	Bonk = { id = KNOCK, pitch = 0.55, volume = 0.9 },
	Siren = { id = PING, pitch = 0.75, volume = 0.6 },
	Alarm = { id = PING, pitch = 1.6, volume = 0.6 },
	Lock = { id = BASS, pitch = 1.4, volume = 0.5 },
	Steal = { id = SWOOSH, pitch = 0.9, volume = 0.5 },
	Slip = { id = "rbxasset://sounds/swordlunge.wav", pitch = 1.4, volume = 0.5 },
	Fanfare = { id = VICTORY, pitch = 1.3, volume = 0.55 },
	Laugh = { id = BASS, pitch = 0.5, volume = 0.5 }, -- Cursed mutation
	Beep = { id = PING, pitch = 2, volume = 0.25 },
	Squeak = { id = "rbxasset://sounds/button.wav", pitch = 2.2, volume = 0.25 },
	Pop2 = { id = "rbxasset://sounds/snap.wav", pitch = 1.6, volume = 0.3 },
	Rebirth = { id = VICTORY, pitch = 1, volume = 0.8 },
	Firework = { id = BASS, pitch = 1.8, volume = 0.4 },

	-- Rarity spawn sounds: a single knock for Common up to a full drumroll for Mythic
	SpawnCommon = { id = KNOCK, pitch = 1.2, volume = 0.25 },
	SpawnUncommon = { id = KNOCK, pitch = 1.0, volume = 0.3 },
	SpawnRare = { id = PING, pitch = 1.0, volume = 0.35 },
	SpawnEpic = { id = BASS, pitch = 1.1, volume = 0.45 },
	SpawnLegendary = { id = VICTORY, pitch = 1.2, volume = 0.5 },
	SpawnSecret = { id = BASS, pitch = 0.6, volume = 0.7 },
	SpawnMythic = { id = VICTORY, pitch = 0.75, volume = 0.8 },
	Drumroll = { id = KNOCK, pitch = 0.9, volume = 0.5 },
	Chant = { id = BASS, pitch = 0.45, volume = 0.9 }, -- "TUNG... TUNG... TUNG..."

	-- Music building blocks for the procedural theme (see client/Music.luau)
	MusicKick = { id = BASS, pitch = 0.9, volume = 0.5 },
	MusicTung = { id = KNOCK, pitch = 0.7, volume = 0.55 },
	MusicWhistle = { id = PING, pitch = 1, volume = 0.18 },
}

return Sounds
