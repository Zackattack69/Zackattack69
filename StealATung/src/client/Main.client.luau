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

local panels: { [string]: any } = {}
panels.Index = IndexPanel.Build()
panels.Shop = ShopPanel.Build()
panels.Rebirth = RebirthPanel.Build()
panels.Settings = SettingsPanel.Build()
panels.Quests = QuestsPanel.Build()
panels.Trade = TradePanel.Build(fxGui)
panels.Sell = SellPanel.Build()

HUD.Build(hudGui, panels)
Effects.Init(fxGui)
PromptUI.Init(hudGui)
Belt.Init()
WorldFx.Init()
Music.Init()

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
	if d.loginCanClaim then
		task.wait(2.5)
		panels.Quests.open()
	end
end)
