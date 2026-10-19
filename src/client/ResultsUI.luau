--!strict
-- End-of-run results card: whether you survived, rooms cleared, coins earned
-- this run, and your all-time totals. Shown while the run-complete screen is
-- up; the server fills in the Run* and Stat* attributes it reads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local localPlayer = Players.LocalPlayer

local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local GREEN = Color3.fromRGB(120, 255, 140)
local RED = Color3.fromRGB(255, 90, 90)
local GOLD = Color3.fromRGB(255, 220, 90)
local SUBTEXT = Color3.fromRGB(220, 210, 235)

local ResultsUI = {}

-- One "name ........ value" line; returns the value label.
local function createRow(parent: Instance, order: number, name: string): TextLabel
	local row = Instance.new("Frame")
	row.Name = name
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 26)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.62, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = SUBTEXT
	label.Text = name
	label.Parent = row

	local value = Instance.new("TextLabel")
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.fromScale(1, 0)
	value.Size = UDim2.fromScale(0.36, 1)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.FredokaOne
	value.TextScaled = true
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextColor3 = Color3.new(1, 1, 1)
	value.Parent = row
	return value
end

function ResultsUI.Start()
	local status = ReplicatedStorage:WaitForChild("GameStatus")
	local coins = localPlayer:WaitForChild("leaderstats"):WaitForChild("Coins") :: IntValue

	local gui = Instance.new("ScreenGui")
	gui.Name = "Results"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.58)
	card.Size = UDim2.fromScale(0.8, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromRGB(30, 18, 45)
	card.Visible = false
	card.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(380, math.huge)
	sizeLimit.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 80, 200)
	stroke.Thickness = 3
	stroke.Parent = card
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = card
	local scale = Instance.new("UIScale")
	scale.Parent = card

	local title = Instance.new("TextLabel")
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Parent = card

	local roomsValue = createRow(card, 2, "Rooms cleared")
	local coinsValue = createRow(card, 3, "Coins this run")
	coinsValue.TextColor3 = GOLD
	local totalValue = createRow(card, 4, "Total coins")
	local allRoomsValue = createRow(card, 5, "All-time rooms cleared")
	local allRunsValue = createRow(card, 6, "All-time runs survived")

	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local shown = false
	local function render()
		local visible = status:GetAttribute("State") == GameConfig.States.RunCompleted
			and localPlayer:GetAttribute("RunStages") ~= nil
		card.Visible = visible
		if not visible then
			shown = false
			return
		end

		local survived = localPlayer:GetAttribute("RunSurvived") == true
		title.Text = if survived then `YOU SURVIVED! +{GameConfig.RunBonus} BONUS` else "KNOCKED OUT"
		title.TextColor3 = if survived then GREEN else RED
		roomsValue.Text = `{localPlayer:GetAttribute("RunRoomsCleared") or 0} / {localPlayer:GetAttribute("RunStages")}`
		coinsValue.Text = `+{localPlayer:GetAttribute("RunCoins") or 0}`
		totalValue.Text = tostring(coins.Value)
		allRoomsValue.Text = tostring(localPlayer:GetAttribute("StatRoomsCompleted") or 0)
		allRunsValue.Text = tostring(localPlayer:GetAttribute("StatRunsSurvived") or 0)

		if not shown then
			shown = true
			scale.Scale = 0.6
			TweenService:Create(scale, POP, { Scale = 1 }):Play()
		end
	end

	status.AttributeChanged:Connect(render)
	localPlayer.AttributeChanged:Connect(render)
	coins.Changed:Connect(render)
	render()
end

return ResultsUI
