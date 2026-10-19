--!strict
-- Door voting cards: one button per door showing its hint, live vote count and
-- whether it's your pick. Clicking only asks the server; the highlight follows
-- the server-confirmed "VotedDoor" attribute, never the click itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local localPlayer = Players.LocalPlayer

local COLORS = {
	Card = Color3.fromRGB(30, 18, 45),
	Stroke = Color3.fromRGB(255, 80, 200),
	Selected = Color3.fromRGB(255, 220, 90),
	Text = Color3.new(1, 1, 1),
	SubText = Color3.fromRGB(220, 210, 235),
}

type Card = {
	Stroke: UIStroke,
	Hint: TextLabel,
	Votes: TextLabel,
}

local VotingUI = {}

-- The max size keeps the same line equally big on every card, whatever its text length.
local function createLabel(parent: Instance, name: string, y: number, height: number, font: Enum.Font, maxTextSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.fromScale(0, y)
	label.Size = UDim2.fromScale(1, height)
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = COLORS.SubText
	label.Text = ""
	label.Parent = parent

	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MaxTextSize = maxTextSize
	sizeLimit.Parent = label
	return label
end

local function createCard(parent: Instance, doorId: number, castVote: RemoteEvent): Card
	local button = Instance.new("TextButton")
	button.Name = `Door{doorId}`
	button.LayoutOrder = doorId
	button.Size = UDim2.new(1 / GameConfig.DoorsPerVote, -6, 1, 0)
	button.BackgroundColor3 = COLORS.Card
	button.BackgroundTransparency = 0.1
	button.Text = ""
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = COLORS.Stroke
	stroke.Thickness = 2
	stroke.Parent = button

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = button

	local title = createLabel(button, "Title", 0, 0.36, Enum.Font.FredokaOne, 30)
	title.TextColor3 = COLORS.Text
	title.Text = `DOOR {doorId}`
	local hint = createLabel(button, "Hint", 0.38, 0.34, Enum.Font.GothamBold, 18)
	local votes = createLabel(button, "Votes", 0.76, 0.24, Enum.Font.Gotham, 15)

	button.Activated:Connect(function()
		castVote:FireServer(doorId)
	end)

	return { Stroke = stroke, Hint = hint, Votes = votes }
end

local function buildPanel(): Frame
	local gui = Instance.new("ScreenGui")
	gui.Name = "VotingUI"
	gui.ResetOnSpawn = false

	-- Raised off the bottom edge so the cards don't sit under mobile jump/move controls.
	local panel = Instance.new("Frame")
	panel.Name = "Cards"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -110)
	panel.Size = UDim2.fromScale(0.6, 0.22)
	panel.BackgroundTransparency = 1
	panel.Visible = false
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(300, 100)
	sizeLimit.MaxSize = Vector2.new(540, 140)
	sizeLimit.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = panel

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	return panel
end

function VotingUI.Start()
	local status = ReplicatedStorage:WaitForChild("GameStatus")
	local castVote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CastVote") :: RemoteEvent
	local panel = buildPanel()

	local cards: { Card } = {}
	for doorId = 1, GameConfig.DoorsPerVote do
		cards[doorId] = createCard(panel, doorId, castVote)
	end

	local function render()
		local voting = status:GetAttribute("State") == GameConfig.States.DoorVoting
		panel.Visible = voting and localPlayer:GetAttribute("InRun") == true and not localPlayer:GetAttribute("Eliminated")

		local myVote = localPlayer:GetAttribute("VotedDoor")
		for doorId, card in cards do
			local count = status:GetAttribute(`Votes{doorId}`) or 0
			local isMine = myVote == doorId
			card.Hint.Text = status:GetAttribute(`Hint{doorId}`) or "???"
			card.Votes.Text = (if isMine then "YOUR VOTE · " else "") .. `{count} {if count == 1 then "vote" else "votes"}`
			card.Votes.TextColor3 = if isMine then COLORS.Selected else COLORS.SubText
			card.Stroke.Color = if isMine then COLORS.Selected else COLORS.Stroke
			card.Stroke.Thickness = if isMine then 4 else 2
		end
	end

	status.AttributeChanged:Connect(render)
	localPlayer.AttributeChanged:Connect(render)
	render()
end

return VotingUI
