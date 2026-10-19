--!strict
-- The cosmetic shop window. Opens from the SHOP button (hidden while you're
-- playing a room) or the shop counter in the lobby. Every purchase asks for
-- confirmation first and is checked by the server (ShopManager); the cards just
-- show what the server says you own and have equipped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local States = GameConfig.States
local localPlayer = Players.LocalPlayer

local COLORS = {
	Window = Color3.fromRGB(30, 18, 45),
	Card = Color3.fromRGB(48, 30, 70),
	Accent = Color3.fromRGB(255, 80, 200),
	Gold = Color3.fromRGB(255, 210, 70),
	Green = Color3.fromRGB(90, 200, 110),
	Red = Color3.fromRGB(255, 100, 100),
	Text = Color3.new(1, 1, 1),
	DarkText = Color3.fromRGB(45, 25, 55),
	SubText = Color3.fromRGB(200, 190, 220),
	Disabled = Color3.fromRGB(90, 80, 105),
}

local SLOT_NAMES = { Trail = "Trail", Title = "Title over your head", Victory = "Burst when you win a room" }

-- While you're playing one of these with a run going, the shop button hides.
local BUSY_STATES = {
	[States.DoorVoting] = true,
	[States.LoadingRoom] = true,
	[States.PlayingRoom] = true,
	[States.RoomCompleted] = true,
}

type Card = { Item: Cosmetics.Cosmetic, Button: TextButton }

local ShopUI = {}

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function newLabel(parent: Instance, text: string, font: Enum.Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
	return label
end

local function newButton(parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = COLORS.Text
	button.Text = text
	addCorner(button, 8)
	button.Parent = parent
	return button
end

-- A small picture of the item: a color stripe for trails, colored words otherwise.
local function buildPreview(parent: Instance, item: Cosmetics.Cosmetic)
	local preview = Instance.new("Frame")
	preview.Position = UDim2.fromOffset(8, 8)
	preview.Size = UDim2.new(1, -16, 0, 44)
	preview.BackgroundColor3 = if item.Slot == "Trail" then Color3.new(1, 1, 1) else Color3.fromRGB(20, 12, 30)
	addCorner(preview, 8)
	preview.Parent = parent

	local gradient = Instance.new("UIGradient")
	gradient.Color = Cosmetics.ColorSequence(item.Colors)
	if item.Slot == "Trail" then
		gradient.Parent = preview
	else
		local sample = newLabel(
			preview,
			if item.Slot == "Title" then item.Text or item.Name else "BURST!",
			Enum.Font.FredokaOne,
			Color3.new(1, 1, 1)
		)
		sample.Position = UDim2.fromOffset(6, 4)
		sample.Size = UDim2.new(1, -12, 1, -8)
		gradient.Parent = sample
	end
end

local function buildCard(parent: Instance, order: number, item: Cosmetics.Cosmetic, onPress: (Cosmetics.Cosmetic) -> ()): Card
	local frame = Instance.new("Frame")
	frame.Name = item.Id
	frame.LayoutOrder = order
	frame.BackgroundColor3 = COLORS.Card
	addCorner(frame, 12)
	frame.Parent = parent
	buildPreview(frame, item)

	local name = newLabel(frame, item.Name, Enum.Font.FredokaOne, COLORS.Text)
	name.Position = UDim2.fromOffset(8, 58)
	name.Size = UDim2.new(1, -16, 0, 22)
	local slot = newLabel(frame, SLOT_NAMES[item.Slot], Enum.Font.Gotham, COLORS.SubText)
	slot.Position = UDim2.fromOffset(8, 82)
	slot.Size = UDim2.new(1, -16, 0, 14)

	local button = newButton(frame, "", COLORS.Accent)
	button.Name = "ActionButton"
	button.Position = UDim2.new(0, 8, 1, -40)
	button.Size = UDim2.new(1, -16, 0, 32)
	button.Activated:Connect(function()
		onPress(item)
	end)
	return { Item = item, Button = button }
end

local function ownedIds(): { [string]: boolean }
	local owned = {}
	for id in string.gmatch(localPlayer:GetAttribute("OwnedCosmetics") or "", "[^,]+") do
		owned[id] = true
	end
	return owned
end

function ShopUI.Start()
	local status = ReplicatedStorage:WaitForChild("GameStatus")
	local shopRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopRequest") :: RemoteFunction
	local coins = localPlayer:WaitForChild("leaderstats"):WaitForChild("Coins") :: IntValue

	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	-- On the right edge, above the mobile jump button.
	local openButton = newButton(gui, "SHOP", COLORS.Accent)
	openButton.Name = "OpenButton"
	openButton.AnchorPoint = Vector2.new(1, 0.5)
	openButton.Position = UDim2.new(1, -12, 0.4, 0)
	openButton.Size = UDim2.fromOffset(72, 48)

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Active = true
	backdrop.Visible = false
	backdrop.Parent = gui

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.92, 0.86)
	window.BackgroundColor3 = COLORS.Window
	addCorner(window, 16)
	window.Parent = backdrop
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(620, 460)
	sizeLimit.Parent = window
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Accent
	stroke.Thickness = 3
	stroke.Parent = window

	local title = newLabel(window, "COSMETIC SHOP", Enum.Font.FredokaOne, COLORS.Text)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(0.5, -16, 0, 34)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local coinsLabel = newLabel(window, "", Enum.Font.FredokaOne, COLORS.Gold)
	coinsLabel.AnchorPoint = Vector2.new(1, 0)
	coinsLabel.Position = UDim2.new(1, -64, 0, 14)
	coinsLabel.Size = UDim2.new(0.35, 0, 0, 28)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	local closeButton = newButton(window, "X", Color3.fromRGB(90, 60, 120))
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -10, 0, 8)
	closeButton.Size = UDim2.fromOffset(44, 44)

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Items"
	grid.Position = UDim2.fromOffset(12, 58)
	grid.Size = UDim2.new(1, -24, 1, -104)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = window
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(170, 150)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local toast = newLabel(window, "", Enum.Font.GothamBold, COLORS.Text)
	toast.Position = UDim2.new(0, 12, 1, -40)
	toast.Size = UDim2.new(1, -24, 0, 28)

	-- "Are you sure?" dialog, drawn over the window
	local confirm = Instance.new("Frame")
	confirm.Name = "Confirm"
	confirm.Size = UDim2.fromScale(1, 1)
	confirm.BackgroundColor3 = Color3.new(0, 0, 0)
	confirm.BackgroundTransparency = 0.35
	confirm.Active = true
	confirm.Visible = false
	addCorner(confirm, 16)
	confirm.Parent = window
	local dialog = Instance.new("Frame")
	dialog.Name = "Dialog"
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	dialog.Position = UDim2.fromScale(0.5, 0.5)
	dialog.Size = UDim2.fromOffset(300, 150)
	dialog.BackgroundColor3 = COLORS.Window
	addCorner(dialog, 14)
	dialog.Parent = confirm
	local dialogStroke = Instance.new("UIStroke")
	dialogStroke.Color = COLORS.Gold
	dialogStroke.Thickness = 2
	dialogStroke.Parent = dialog
	local question = newLabel(dialog, "", Enum.Font.FredokaOne, COLORS.Text)
	question.Position = UDim2.fromOffset(12, 12)
	question.Size = UDim2.new(1, -24, 0, 60)
	question.TextWrapped = true
	local yesButton = newButton(dialog, "BUY", COLORS.Green)
	yesButton.Name = "BuyButton"
	yesButton.Position = UDim2.new(0, 12, 1, -56)
	yesButton.Size = UDim2.new(0.5, -18, 0, 44)
	local noButton = newButton(dialog, "CANCEL", COLORS.Disabled)
	noButton.Name = "CancelButton"
	noButton.AnchorPoint = Vector2.new(1, 0)
	noButton.Position = UDim2.new(1, -12, 1, -56)
	noButton.Size = UDim2.new(0.5, -18, 0, 44)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local cards: { Card } = {}
	local pending: Cosmetics.Cosmetic? = nil
	local toastId = 0

	local function showToast(text: string, good: boolean)
		toastId += 1
		local myId = toastId
		toast.Text = text
		toast.TextColor3 = if good then COLORS.Gold else COLORS.Red
		task.delay(2.5, function()
			if toastId == myId then
				toast.Text = ""
			end
		end)
	end

	local function render()
		local owned = ownedIds()
		coinsLabel.Text = `Coins: {coins.Value}`
		for _, card in cards do
			local item, button = card.Item, card.Button
			if localPlayer:GetAttribute(`Equipped{item.Slot}`) == item.Id then
				button.Text = "EQUIPPED"
				button.BackgroundColor3 = COLORS.Green
				button.TextColor3 = COLORS.Text
			elseif owned[item.Id] then
				button.Text = "EQUIP"
				button.BackgroundColor3 = COLORS.Accent
				button.TextColor3 = COLORS.Text
			else
				local affordable = coins.Value >= item.Price
				button.Text = `{item.Price} coins`
				button.BackgroundColor3 = if affordable then COLORS.Gold else COLORS.Disabled
				button.TextColor3 = if affordable then COLORS.DarkText else COLORS.SubText
			end
		end
	end

	local function request(action: string, item: Cosmetics.Cosmetic)
		local ok, message = shopRequest:InvokeServer(action, item.Id)
		if typeof(message) == "string" and message ~= "" then
			showToast(message, ok == true)
		end
	end

	-- Tapping a card: equipped -> unequip, owned -> equip, otherwise confirm a purchase.
	local function onPress(item: Cosmetics.Cosmetic)
		if localPlayer:GetAttribute(`Equipped{item.Slot}`) == item.Id then
			request("Unequip", item)
		elseif ownedIds()[item.Id] then
			request("Equip", item)
		elseif coins.Value < item.Price then
			showToast(`You need {item.Price - coins.Value} more coins.`, false)
		else
			pending = item
			question.Text = `Buy {item.Name} for {item.Price} coins?`
			confirm.Visible = true
		end
	end

	for index, item in Cosmetics.List do
		table.insert(cards, buildCard(grid, index, item, onPress))
	end

	yesButton.Activated:Connect(function()
		local item = pending
		pending = nil
		confirm.Visible = false
		if item then
			request("Buy", item)
		end
	end)
	noButton.Activated:Connect(function()
		pending = nil
		confirm.Visible = false
	end)

	local function setOpen(open: boolean)
		backdrop.Visible = open
		if open then
			render()
		else
			pending = nil
			confirm.Visible = false
		end
	end
	openButton.Activated:Connect(function()
		setOpen(true)
	end)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)

	local function updateAvailability()
		local busy = BUSY_STATES[status:GetAttribute("State")]
			and localPlayer:GetAttribute("InRun")
			and not localPlayer:GetAttribute("Eliminated")
		openButton.Visible = not busy
		if busy then
			setOpen(false)
		end
	end
	status.AttributeChanged:Connect(updateAvailability)
	localPlayer.AttributeChanged:Connect(function()
		updateAvailability()
		render()
	end)
	coins.Changed:Connect(render)
	updateAvailability()
	render()

	-- The shop counter in the lobby opens the window too.
	task.spawn(function()
		local counter = workspace:WaitForChild("Lobby"):WaitForChild("Shop"):WaitForChild("Counter")
		local prompt = counter:WaitForChild("OpenShop") :: ProximityPrompt
		prompt.Triggered:Connect(function()
			if openButton.Visible then
				setOpen(true)
			end
		end)
	end)
end

return ShopUI
