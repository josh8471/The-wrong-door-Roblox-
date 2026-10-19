--!strict
-- Round HUD: shows the current phase, countdown, room number and room status
-- (e.g. "Keys 1/3"), plus a big center banner for alerts and your own result.
-- Reads everything from ReplicatedStorage.GameStatus and your player
-- attributes, which the server owns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local States = GameConfig.States
local localPlayer = Players.LocalPlayer

local STATE_TITLES = {
	[States.WaitingForPlayers] = "Waiting for players",
	[States.Intermission] = "Next run starts in",
	[States.DoorVoting] = "Pick a door!",
	[States.LoadingRoom] = "Opening the door...",
	[States.PlayingRoom] = "Survive!",
	[States.RoomCompleted] = "Room cleared",
	[States.RunCompleted] = "Run complete!",
	[States.ReturningToLobby] = "Back to the lobby",
}

-- States where the room counter is shown and late joiners are told to wait.
local STAGE_STATES = {
	[States.DoorVoting] = true,
	[States.LoadingRoom] = true,
	[States.PlayingRoom] = true,
	[States.RoomCompleted] = true,
}

local BANNER_COLORS = {
	Succeeded = Color3.fromRGB(120, 255, 140),
	Failed = Color3.fromRGB(255, 90, 90),
	Flash = Color3.fromRGB(255, 160, 60),
	Alert = Color3.fromRGB(255, 220, 90),
}

local BANNER_POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- Shown when this session's progress isn't being saved (DataStatus attribute).
local SAVE_NOTICES = {
	SessionOnly = "Progress isn't being saved (test mode)",
	LoadFailed = "Couldn't load your data, so nothing saves. Rejoin!",
}

local UIController = {}

type Hud = {
	Title: TextLabel,
	Timer: TextLabel,
	Info: TextLabel,
	Status: TextLabel,
	Notice: TextLabel,
	Banner: TextLabel,
	BannerScale: UIScale,
}

local function createLabel(parent: Instance, name: string, order: number, height: number, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = ""
	label.Parent = parent
	return label
end

local function buildBanner(gui: ScreenGui): (TextLabel, UIScale)
	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.45)
	banner.Size = UDim2.new(0.9, 0, 0, 64)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.FredokaOne
	banner.TextScaled = true
	banner.Text = ""
	banner.Parent = gui

	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MaxTextSize = 56
	sizeLimit.Parent = banner

	local outline = Instance.new("UIStroke")
	outline.Thickness = 3
	outline.Parent = banner

	local scale = Instance.new("UIScale")
	scale.Parent = banner
	return banner, scale
end

local function buildHud(): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "RoundHud"
	gui.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 8)
	panel.Size = UDim2.fromScale(0.6, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Color3.fromRGB(30, 18, 45)
	panel.BackgroundTransparency = 0.15
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(240, 0)
	sizeLimit.MaxSize = Vector2.new(420, math.huge)
	sizeLimit.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 80, 200)
	stroke.Thickness = 2
	stroke.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = panel

	local title = createLabel(panel, "Title", 1, 24, Enum.Font.FredokaOne)
	local timer = createLabel(panel, "Timer", 2, 36, Enum.Font.FredokaOne)
	timer.TextColor3 = Color3.fromRGB(255, 220, 90)
	timer.Visible = false
	local info = createLabel(panel, "Info", 3, 18, Enum.Font.Gotham)
	info.TextColor3 = Color3.fromRGB(220, 210, 235)
	local roomStatus = createLabel(panel, "Status", 4, 20, Enum.Font.FredokaOne)
	roomStatus.TextColor3 = Color3.fromRGB(255, 220, 90)
	roomStatus.Visible = false
	local notice = createLabel(panel, "Notice", 5, 14, Enum.Font.GothamBold)
	notice.TextColor3 = Color3.fromRGB(255, 120, 120)
	notice.Visible = false

	local banner, bannerScale = buildBanner(gui)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	return {
		Title = title,
		Timer = timer,
		Info = info,
		Status = roomStatus,
		Notice = notice,
		Banner = banner,
		BannerScale = bannerScale,
	}
end

function UIController.Start()
	local status = ReplicatedStorage:WaitForChild("GameStatus")
	local hud = buildHud()

	local function setBanner(text: string, color: Color3)
		hud.Banner.TextColor3 = color
		if hud.Banner.Text ~= text then
			hud.Banner.Text = text
			hud.BannerScale.Scale = 1.3
			TweenService:Create(hud.BannerScale, BANNER_POP, { Scale = 1 }):Play()
		end
	end

	local function render()
		local state = status:GetAttribute("State")
		local stage = status:GetAttribute("Stage") or 0
		local message = status:GetAttribute("Message") or ""
		local roomName = status:GetAttribute("RoomName")

		hud.Title.Text = if state == States.PlayingRoom and roomName
			then string.upper(roomName)
			else STATE_TITLES[state] or ""
		if STAGE_STATES[state] and not localPlayer:GetAttribute("InRun") then
			hud.Info.Text = "Run in progress. You'll join the next one."
		elseif STAGE_STATES[state] and localPlayer:GetAttribute("Eliminated") then
			hud.Info.Text = "You're out! Watching the survivors..."
		elseif STAGE_STATES[state] then
			hud.Info.Text = `Room {stage}/{GameConfig.RoomsPerRun} · {message}`
		else
			hud.Info.Text = message
		end

		local roomStatus = status:GetAttribute("RoomStatus") or ""
		hud.Status.Text = roomStatus
		hud.Status.Visible = roomStatus ~= ""

		local saveNotice = SAVE_NOTICES[localPlayer:GetAttribute("DataStatus")]
		hud.Notice.Text = saveNotice or ""
		hud.Notice.Visible = saveNotice ~= nil

		-- Your own result beats a personal flash ("BONK!"), which beats room-wide alerts.
		local resultText = localPlayer:GetAttribute("RoomResultText")
		local flashText = localPlayer:GetAttribute("Flash")
		if resultText then
			setBanner(resultText, BANNER_COLORS[localPlayer:GetAttribute("RoomResult")] or BANNER_COLORS.Alert)
		elseif flashText then
			setBanner(flashText, BANNER_COLORS.Flash)
		else
			setBanner(status:GetAttribute("Alert") or "", BANNER_COLORS.Alert)
		end
	end

	status.AttributeChanged:Connect(render)
	localPlayer.AttributeChanged:Connect(render)
	render()

	-- Countdown is computed locally from the server's end time, so the server
	-- doesn't need to send an update every second.
	RunService.Heartbeat:Connect(function()
		local endsAt = status:GetAttribute("EndsAt") or 0
		local text = if endsAt > 0 then tostring(math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))) else ""
		if hud.Timer.Text ~= text then
			hud.Timer.Text = text
			hud.Timer.Visible = text ~= ""
		end
	end)
end

return UIController
