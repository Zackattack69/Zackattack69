--!strict
-- Steal a Tung: client entry point.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Client = script.Parent
local State = require(Client.State)
local Belt = require(Client.Belt)
local PromptUI = require(Client.PromptUI)
local WorldFx = require(Client.WorldFx)
local Music = require(Client.Music)
local Voice = require(Client.Voice)
local UI = Client.UI
local Lib = require(UI.Lib)
local HUD = require(UI.HUD)
local Effects = require(UI.Effects)
local IndexPanel = require(UI.IndexPanel)
local ShopPanel = require(UI.ShopPanel)
local RebirthPanel = require(UI.RebirthPanel)
local SettingsPanel = require(UI.SettingsPanel)
local QuestsPanel = require(UI.QuestsPanel)
local TradePanel = require(UI.TradePanel)
local SellPanel = require(UI.SellPanel)
local AdminPanel = require(UI.AdminPanel)
local SkinsPanel = require(UI.SkinsPanel)
local Hatch = require(UI.Hatch)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function screen(name: string, order: number): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = order
	g.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	g.Parent = playerGui
	return g
end

local hudGui = screen("TungHUD", 1)
local panelGui = screen("TungPanels", 5)
local fxGui = screen("TungFx", 10)

State.Init()
Lib.SetPanelRoot(panelGui)

-- Start each part on its own, so if one ever breaks the rest (music included) still runs.
local function safe(name: string, fn: () -> ())
	local ok, err = pcall(fn :: any)
	if not ok then
		warn("[Client] " .. name .. " failed to start:", err)
	end
end

safe("Music", Music.Init) -- first, so the theme plays no matter what

local panels: { [string]: any } = {}
local function panel(name: string, build: () -> any)
	safe(name, function()
		panels[name] = build()
	end)
end
panel("Index", IndexPanel.Build)
panel("Shop", ShopPanel.Build)
panel("Rebirth", RebirthPanel.Build)
panel("Settings", SettingsPanel.Build)
panel("Quests", QuestsPanel.Build)
panel("Trade", function()
	return TradePanel.Build(fxGui)
end)
panel("Sell", SellPanel.Build)
panel("Admin", AdminPanel.Build)
panel("Skins", SkinsPanel.Build)

safe("HUD", function()
	HUD.Build(hudGui, panels)
end)
safe("Effects", function()
	Effects.Init(fxGui)
end)
safe("Hatch", function()
	Hatch.Init(fxGui)
end)
safe("PromptUI", function()
	PromptUI.Init(hudGui)
end)
safe("Voice", Voice.Init)
safe("Belt", Belt.Init)
safe("WorldFx", WorldFx.Init)

-- World prompts (shop / sell stands, rebirth altar) open panels
Remotes.Event("OpenUI").OnClientEvent:Connect(function(which: string)
	local p = panels[which]
	if p then
		p.open()
	end
end)

-- VIP chat tag + gold name, and the Tung Master title
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local props = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local sender = source and Players:GetPlayerByUserId(source.UserId)
	if sender then
		local prefix = message.PrefixText
		if sender:GetAttribute("Title") then
			prefix = '<font color="#FFC83C">[Tung Master]</font> ' .. prefix
		end
		if sender:GetAttribute("VIP") then
			prefix = '<font color="#FFD23C">[VIP]</font> <font color="#FFD23C">' .. prefix .. "</font>"
		end
		props.PrefixText = prefix
	end
	return props
end

-- First load: welcome + daily login reminder
task.spawn(function()
	local d = State.WaitForData()
	State.Fire("Toast", "👋 Welcome to Steal a Tung! Buy Tungs from the belt and bring them home.", "info")
	-- admins: say clearly when this test server isn't saving progress (Studio without API access)
	if workspace:GetAttribute("SavingOff") and player:GetAttribute("IsAdmin") then
		task.delay(4, function()
			State.Fire("Toast", "⚠️ Progress is NOT saving in this test. Publish the game, then turn on Game Settings → Security → Studio Access to API Services.", "error")
		end)
		task.delay(8, function()
			State.Fire("Toast", "⚠️ In the real published game, progress saves every minute and when players leave.", "info")
		end)
	end
	if d.loginCanClaim and panels.Quests then
		task.wait(2.5)
		panels.Quests.open()
	end
end)
