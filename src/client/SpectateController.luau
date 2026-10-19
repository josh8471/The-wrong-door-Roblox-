--!strict
-- When you're out of the run, your camera follows the players still in it.
-- The arrow buttons switch who you're watching. Camera only: the server
-- decides who is out (Eliminated / RoomResult attributes).

local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local SpectateController = {}

local function isOut(player: Player): boolean
	return player:GetAttribute("Eliminated") == true or player:GetAttribute("RoomResult") == "Failed"
end

-- Players still in the run, in a stable order so the arrows behave.
local function stillPlaying(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer and player:GetAttribute("InRun") and not isOut(player) then
			table.insert(list, player)
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

local function createArrow(parent: Instance, text: string, side: number): TextButton
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(side, 0.5)
	button.Position = UDim2.new(side, if side == 0 then 4 else -4, 0.5, 0)
	button.Size = UDim2.fromOffset(48, 48)
	button.BackgroundColor3 = Color3.fromRGB(255, 80, 200)
	button.Text = text
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	button.Parent = parent
	return button
end

function SpectateController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Spectate"
	gui.ResetOnSpawn = false

	-- Same spot as the voting cards; the two are never shown together.
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -110)
	bar.Size = UDim2.fromOffset(340, 56)
	bar.BackgroundColor3 = Color3.fromRGB(30, 18, 45)
	bar.BackgroundTransparency = 0.15
	bar.Visible = false
	bar.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bar

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -120, 1, -16)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = bar

	local previous = createArrow(bar, "<", 0)
	local nextOne = createArrow(bar, ">", 1)
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local index = 1
	local watching = false

	local function update()
		local list = if localPlayer:GetAttribute("InRun") and isOut(localPlayer) then stillPlaying() else {}
		if #list > 0 then
			index = (index - 1) % #list + 1
			local target = list[index]
			local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				workspace.CurrentCamera.CameraSubject = humanoid
			end
			label.Text = `Watching {target.DisplayName}`
			bar.Visible = true
			watching = true
		elseif watching then
			watching = false
			bar.Visible = false
			local ownHumanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
			if ownHumanoid then
				workspace.CurrentCamera.CameraSubject = ownHumanoid
			end
		end
	end

	previous.Activated:Connect(function()
		index -= 1
		update()
	end)
	nextOne.Activated:Connect(function()
		index += 1
		update()
	end)

	task.spawn(function()
		while true do
			update()
			task.wait(0.25)
		end
	end)
end

return SpectateController
