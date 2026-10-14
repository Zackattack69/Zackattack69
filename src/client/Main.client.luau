--!strict
-- Scrapyard: Droid Foundry — client entry point.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Client = script.Parent
local State = require(Client.State)
local WorldFx = require(Client.WorldFx)
local UI = Client.UI
local Lib = require(UI.Lib)
local HUD = require(UI.HUD)
local CratePanel = require(UI.CratePanel)
local CrateReveal = require(UI.CrateReveal)
local DroidsPanel = require(UI.DroidsPanel)
local MapPanel = require(UI.MapPanel)
local RebirthPanel = require(UI.RebirthPanel)
local FoundryPanel = require(UI.FoundryPanel)
local ShopPanel = require(UI.ShopPanel)
local MiscPanels = require(UI.MiscPanels)
local Effects = require(UI.Effects)
local Onboarding = require(UI.Onboarding)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local function screen(name: string, order: number): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = order
	g.Parent = playerGui
	return g
end

local hudGui = screen("FoundryHUD", 1)
local panelGui = screen("FoundryPanels", 5)
local fxGui = screen("FoundryFx", 10)

State.Init()
Lib.SetPanelRoot(panelGui)
CrateReveal.SetRoot(fxGui)

local panels: { [string]: any } = {}
panels.Crates = CratePanel.Build()
panels.Droids = DroidsPanel.Build()
panels.Map = MapPanel.Build()
panels.Rebirth = RebirthPanel.Build()
panels.Foundry = FoundryPanel.Build()
panels.Shop = ShopPanel.Build()
panels.Quests = MiscPanels.Quests()
panels.Leaderboard = MiscPanels.Leaderboard()
panels.Inventory = MiscPanels.Inventory(function()
	panels.Crates.open()
end)
panels.Settings = MiscPanels.Settings()
panels.Notifications = MiscPanels.Notifications()

HUD.Build(hudGui, panels)
Effects.Init(hudGui, fxGui)
WorldFx.Init()

-- ProximityPrompts in the world open panels
Remotes.Event("OpenUI").OnClientEvent:Connect(function(which: string)
	if which == "Crates" then
		panels.Crates.open()
	elseif which == "Map" then
		panels.Map.open()
	end
end)

State.WaitForData()
task.spawn(Onboarding.Run, fxGui, HUD.refs)
