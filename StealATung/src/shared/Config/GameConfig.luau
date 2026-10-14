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

	-- Upload a looping main theme and paste "rbxassetid://..." here.
	-- Empty = no background music.
	MusicId = "",

	-- Trading is friends-only, as in the design doc (ignored in Studio so you can test).
	TradeFriendsOnly = true,

	DataStoreName = "StealATung_v1",
	GlobalTopic = "StealATung_Global", -- MessagingService topic for Mythic broadcasts
}
