--!strict
-- Game-wide setup values you'll want to fill in before publishing.

return {
	-- Roblox group for the free Group Tung (0 = feature off).
	GroupId = 0,

	-- UserIds allowed to use the ADMIN panel and admin chat commands.
	-- (The panel also asks for a secret code, which lives server-side in
	-- src/server/AdminConfig.luau so players can't read it.)
	-- The place owner (or group owner for group games) is always an admin, and
	-- everyone is an admin in Studio for testing.
	Admins = {} :: { number },

	-- BadgeService badge IDs (0 = don't award). Index rarity tabs + 100% Index.
	Badges = {
		Common = 0,
		Uncommon = 0,
		Rare = 0,
		Epic = 0,
		Legendary = 0,
		Secret = 0,
		Mythic = 0,
		TungMaster = 0,
	} :: { [string]: number },

	-- Main theme, loops forever. Roblox can only play audio that's been uploaded:
	-- in Studio open Window > Asset Manager > Import, pick Bills_Keep_Rolling.mp3,
	-- then right-click it > Copy Asset ID and paste it here as "rbxassetid://123...".
	-- Empty = no background music.
	MusicId = "",

	-- Optional songs for events (same "rbxassetid://..." format). Leave one empty
	-- and the main theme is re-mixed to fit that event instead (see client/Music.luau).
	EventMusic = {
		SahurHour = "",
		TungRain = "",
		GoldenBelt = "",
		SpeedBelt = "",
		ThiefNight = "",
		AdminAbuse = "",
	} :: { [string]: string },

	-- Text-to-speech voice that says a Tung's name when you pick it up (Roblox AudioTextToSpeech).
	-- "4" = US female (closest to the TikTok voice). Others: "1" British male, "2" British female,
	-- "3" US male, "5" US male 2, "6" US female 2, "7" Australian male, "8" Australian female,
	-- "9"/"10" retro voices, "11" host voice.
	TtsVoice = "4",

	-- Trading is friends-only, as in the design doc (ignored in Studio so you can test).
	TradeFriendsOnly = true,

	DataStoreName = "StealATung_v1",
	GlobalTopic = "StealATung_Global", -- MessagingService topic for Mythic broadcasts
}
