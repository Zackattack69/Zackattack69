--!strict
-- Sound cues (Design Doc §8). Defaults point at sounds bundled with the Roblox
-- client so the game is audible out of the box. Replace with your own uploaded
-- audio ("rbxassetid://123...") for the real rarity-specific stingers.

return {
	Click = "rbxasset://sounds/button.wav",
	Salvage = "rbxasset://sounds/clickfast.wav",
	Purchase = "rbxasset://sounds/electronicpingshort.wav",
	Error = "rbxasset://sounds/snap.wav",
	CrateShake = "rbxasset://sounds/collide.wav",

	-- Rarity reveals
	RevealBasic = "rbxasset://sounds/electronicpingshort.wav", -- Common–Rare: clunk + chime
	RevealEpic = "rbxasset://sounds/bass.wav", -- deeper bass hit + synth sting
	RevealLegendary = "rbxasset://sounds/victory.wav", -- rising orchestral swell
	RevealMythic = "rbxasset://sounds/victory.wav", -- full stinger + crowd cheer

	-- Style coatings
	StyleShing = "rbxasset://sounds/swoosh.wav", -- Gold / Diamond / Shadow / Neon
	StyleRainbow = "rbxasset://sounds/victory.wav", -- ascending glissando + sparkle

	Hyperspace = "rbxasset://sounds/swoosh.wav",
	Rebirth = "rbxasset://sounds/victory.wav",
}
