--!strict
-- Draws chasers (models tagged "Chaser") smoothly on this client. Two kinds:
--   Path chasers (have a "Path" ObjectValue, like Grandma): position is pure math
--     from StartedAt/StartSpeed/Acceleration/MaxSpeed, identical to the server's.
--   Free chasers (like the Giant Chicken): the server sends MovePos/MoveVel/MoveAt
--     ~10x per second; this client predicts ahead and smooths between updates.
-- The server never moves these models itself, so nothing fights the smoothing.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PathFollower = require(ReplicatedStorage.Shared.PathFollower)

local WADDLE_SPEED = 12 -- how fast a moving chaser rocks side to side
local IDLE_SPEED = 3
local MAX_PREDICTION = 0.3 -- seconds to predict ahead when an update is late
local SMOOTHING = 15
local DEFAULT_FACING = Vector3.new(0, 0, -1)

type Chaser = { Path: PathFollower.Path?, PointCount: number, Shown: Vector3? }

local ChaserRenderer = {}

local chasers: { [Model]: Chaser } = {}

local function track(instance: Instance)
	if instance:IsA("Model") then
		chasers[instance] = { Path = nil, PointCount = 0, Shown = nil }
	end
end

-- Path chasers carry a "Path" ObjectValue. The path can finish arriving a moment
-- after the model does, so it's rebuilt whenever its point count changes.
local function pathOf(model: Model, chaser: Chaser): PathFollower.Path?
	local pathRef = model:FindFirstChild("Path")
	local folder = if pathRef and pathRef:IsA("ObjectValue") then pathRef.Value else nil
	if not folder then
		return nil
	end
	local pointCount = #folder:GetChildren()
	if chaser.PointCount ~= pointCount then
		chaser.Path = PathFollower.FromFolder(folder)
		chaser.PointCount = pointCount
	end
	return chaser.Path
end

-- Where a chaser is, which way it faces, and whether it's moving right now.
local function locate(model: Model, chaser: Chaser, now: number, dt: number): (Vector3?, Vector3, boolean)
	local path = pathOf(model, chaser)
	if path then
		local startedAt = model:GetAttribute("StartedAt")
		local elapsed = if typeof(startedAt) == "number" then now - startedAt else 0
		local distance = PathFollower.TravelDistance(
			elapsed,
			model:GetAttribute("StartSpeed") or 0,
			model:GetAttribute("Acceleration") or 0,
			model:GetAttribute("MaxSpeed") or 0
		)
		local position, direction = PathFollower.At(path, distance)
		return position, direction, distance > 0 and distance < path.Total
	end

	local movePos = model:GetAttribute("MovePos")
	if typeof(movePos) ~= "Vector3" then
		return nil, DEFAULT_FACING, false
	end
	local moveVel = model:GetAttribute("MoveVel")
	local velocity = if typeof(moveVel) == "Vector3" then moveVel else Vector3.zero
	local moveAt = model:GetAttribute("MoveAt")
	local ahead = if typeof(moveAt) == "number" then math.clamp(now - moveAt, 0, MAX_PREDICTION) else 0
	local predicted = movePos + velocity * ahead
	local shown = if chaser.Shown then chaser.Shown:Lerp(predicted, math.min(1, dt * SMOOTHING)) else predicted
	chaser.Shown = shown
	local facing = model:GetAttribute("Facing")
	return shown, if typeof(facing) == "Vector3" then facing else DEFAULT_FACING, velocity.Magnitude > 0.5
end

local function render(dt: number)
	local now = workspace:GetServerTimeNow()
	for model, chaser in chasers do
		local position, direction, moving = locate(model, chaser, now, dt)
		if not position then
			continue
		end
		local facing = Vector3.new(direction.X, 0, direction.Z)
		if facing.Magnitude < 0.01 then
			facing = DEFAULT_FACING
		end
		local waddle = os.clock() * (if moving then WADDLE_SPEED else IDLE_SPEED)
		model:PivotTo(
			CFrame.lookAt(position, position + facing)
				* CFrame.new(0, math.abs(math.sin(waddle)) * 0.5, 0)
				* CFrame.Angles(0, 0, math.sin(waddle) * 0.08)
		)
	end
end

function ChaserRenderer.Start()
	CollectionService:GetInstanceAddedSignal("Chaser"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("Chaser"):Connect(function(instance)
		chasers[instance :: Model] = nil
	end)
	for _, instance in CollectionService:GetTagged("Chaser") do
		track(instance)
	end
	RunService.RenderStepped:Connect(render)
end

return ChaserRenderer
