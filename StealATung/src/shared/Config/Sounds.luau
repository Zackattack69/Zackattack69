--!strict
-- Sound cues, kept soft on purpose: short clicks, pings and swooshes bundled
-- with the Roblox client (so the game is audible out of the box), plus the
-- classic Roblox cash-register "cha-ching" when you collect money. Pitch
-- (PlaybackSpeed) turns one sound into several cues. Replace any `id` with
-- your own upload ("rbxassetid://123..."). A cue with a `fallback` switches to
-- it if its id can't be loaded.

export type Cue = { id: string, pitch: number?, volume: number?, fallback: string?, fallbackPitch: number? }

local KNOCK = "rbxasset://sounds/collide.wav"
local PING = "rbxasset://sounds/electronicpingshort.wav"
local CLICK = "rbxasset://sounds/button.wav"
local VICTORY = "rbxasset://sounds/victory.wav"
local SWOOSH = "rbxasset://sounds/swoosh.wav"
local CASH = "rbxassetid://7112275565" -- "Cash Register (Kaching)"

local Sounds: { [string]: Cue } = {
	-- UI
	Pop = { id = CLICK, pitch = 1.3, volume = 0.3 },
	Whoosh = { id = SWOOSH, pitch = 1.2, volume = 0.18 },
	Error = { id = CLICK, pitch = 0.7, volume = 0.3 },
	Purchase = { id = PING, pitch = 1.2, volume = 0.3 },

	-- Gameplay
	ChaChing = { id = CASH, volume = 0.6, fallback = PING, fallbackPitch = 1.5 }, -- collecting money
	Tung = { id = KNOCK, pitch = 0.8, volume = 0.35 }, -- tapping a Tung: a soft wooden knock
	Jackpot = { id = VICTORY, pitch = 1.15, volume = 0.35 },
	Place = { id = CLICK, pitch = 0.9, volume = 0.3 },
	Puff = { id = SWOOSH, pitch = 0.7, volume = 0.12 },
	Swing = { id = "rbxasset://sounds/swordslash.wav", pitch = 0.8, volume = 0.3 },
	Bonk = { id = KNOCK, pitch = 0.6, volume = 0.4 },
	Siren = { id = PING, pitch = 0.75, volume = 0.25 },
	Alarm = { id = PING, pitch = 1.4, volume = 0.25 },
	Lock = { id = CLICK, pitch = 0.8, volume = 0.35 },
	Steal = { id = SWOOSH, pitch = 0.9, volume = 0.3 },
	Slip = { id = "rbxasset://sounds/swordlunge.wav", pitch = 1.4, volume = 0.3 },
	Fanfare = { id = VICTORY, pitch = 1.3, volume = 0.3 },
	Rebirth = { id = VICTORY, pitch = 1, volume = 0.55 },
	Firework = { id = PING, pitch = 2.2, volume = 0.1 },

	-- Rare belt spawns (Legendary and up only)
	SpawnLegendary = { id = VICTORY, pitch = 1.2, volume = 0.3 },
	SpawnSecret = { id = VICTORY, pitch = 0.9, volume = 0.35 },
	SpawnMythic = { id = VICTORY, pitch = 0.75, volume = 0.45 },
}

return Sounds
