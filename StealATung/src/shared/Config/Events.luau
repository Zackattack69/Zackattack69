--!strict
-- Server events: one random event every 15 minutes, lasting 3 minutes.
-- Admin Abuse is weekly and scheduled (UTC), and can also be started by an admin.

export type Event = {
	key: string,
	name: string,
	icon: string,
	color: Color3,
	desc: string,
	random: boolean, -- part of the 15-minute rotation
}

local Events = {}

Events.INTERVAL = 15 * 60
Events.DURATION = 3 * 60
Events.FIRST_DELAY = 5 * 60 -- first event after a fresh server starts

Events.List = {
	{ key = "SahurHour", name = "Sahur Hour", icon = "🌙", color = Color3.fromRGB(140, 60, 220), desc = "Secret & Mythic chances x3!", random = true },
	{ key = "TungRain", name = "Tung Rain", icon = "🌧️", color = Color3.fromRGB(70, 170, 255), desc = "Free Tungs are falling from the sky! Touch one to keep it.", random = true },
	{ key = "GoldenBelt", name = "Golden Belt", icon = "✨", color = Color3.fromRGB(255, 195, 40), desc = "Every Tung on the belt is Gold!", random = true },
	{ key = "SpeedBelt", name = "Speed Belt", icon = "⚡", color = Color3.fromRGB(255, 120, 40), desc = "The belt runs faster and spawns 2x as often!", random = true },
	{ key = "ThiefNight", name = "Thief Night", icon = "🦹", color = Color3.fromRGB(220, 40, 70), desc = "Steal in 0.75 s and base locks are OFF. Chaos!", random = true },
	{ key = "AdminAbuse", name = "ADMIN ABUSE", icon = "👑", color = Color3.fromRGB(255, 60, 160), desc = "Luck x3, every Tung is Gold, and the admin is spawning Tungs!", random = false },
} :: { Event }

Events.ByKey = {} :: { [string]: Event }
for _, e in Events.List do
	Events.ByKey[e.key] = e
end

-- Weekly Admin Abuse window (UTC). os.date("!*t").wday: 1 = Sunday ... 7 = Saturday.
Events.ADMIN_ABUSE = {
	wday = 7,
	hour = 18,
	minutes = 60,
	luck = 3,
}

-- Seconds until the next weekly Admin Abuse starts (0 while it's live), and whether it's live.
function Events.AdminAbuseStatus(unixTime: number): (number, boolean)
	local cfg = Events.ADMIN_ABUSE
	local t = os.date("!*t", unixTime)
	local daysAhead = (cfg.wday - t.wday) % 7
	local secondsToday = t.hour * 3600 + t.min * 60 + t.sec
	local start = unixTime - secondsToday + daysAhead * 86400 + cfg.hour * 3600
	if unixTime >= start and unixTime < start + cfg.minutes * 60 then
		return 0, true
	end
	if start <= unixTime then
		start += 7 * 86400
	end
	return start - unixTime, false
end

return Events
