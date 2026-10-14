--!strict
-- Server-only admin settings. This module lives in ServerScriptService, so it
-- is never sent to players: the code below can't be read from a game client.

return {
	-- Code for the in-game ADMIN panel. Only admins (GameConfig.Admins, the
	-- place owner, or anyone in Studio) see the panel and can use the code.
	Code = "goldklumpen",
}
