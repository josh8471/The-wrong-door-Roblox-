--!strict
-- Full-screen effects the server can trigger. Right now: whenever
-- GameStatus.WorldFlip changes (Reverse Gravity), the screen flashes and the
-- camera does a quick barrel roll.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ROLL_TIME = 0.6
local ROLL_BINDING = "WorldFlipRoll"

local ScreenEffects = {}

local function stopRoll()
	pcall(function()
		RunService:UnbindFromRenderStep(ROLL_BINDING)
	end)
end

function ScreenEffects.Start()
	local status = ReplicatedStorage:WaitForChild("GameStatus")

	local gui = Instance.new("ScreenGui")
	gui.Name = "ScreenEffects"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	status:GetAttributeChangedSignal("WorldFlip"):Connect(function()
		if status:GetAttribute("WorldFlip") == nil then
			return
		end
		flash.BackgroundTransparency = 0.3
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()

		-- Runs right after the default camera each frame and adds a roll on top.
		local started = os.clock()
		stopRoll()
		RunService:BindToRenderStep(ROLL_BINDING, Enum.RenderPriority.Camera.Value + 1, function()
			local alpha = math.min((os.clock() - started) / ROLL_TIME, 1)
			local camera = workspace.CurrentCamera
			camera.CFrame *= CFrame.Angles(0, 0, (1 - (1 - alpha) ^ 3) * 2 * math.pi)
			if alpha >= 1 then
				stopRoll()
			end
		end)
	end)
end

return ScreenEffects
