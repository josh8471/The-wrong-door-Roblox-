--!strict
-- Angry Grandma: run through Grandma's kitchen to the garden exit before she
-- catches you. She follows a fixed path but gets faster the longer she chases,
-- and she hurls slippers at whoever is ahead: a red circle shows where each one
-- will land, and a hit slows you down for a moment. The kitchen is randomly
-- mirrored, so the route changes between visits.
-- Her position is pure math (Shared.PathFollower), so the server checks catches
-- with the same numbers each client uses to draw her (Client.ChaserRenderer).
-- The kitchen runs toward -Z, so "further toward the exit" means "smaller Z".

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PathFollower = require(ReplicatedStorage.Shared.PathFollower)
local PlayerEffects = require(script.Parent.Parent.PlayerEffects)
local teleport = require(script.Parent.Parent.Teleport)

local CATCH_RADIUS = 5 -- studs, measured flat along the floor
local PASS_MARGIN = 2 -- once Grandma is this far past you down the hall, she got you
local MIN_ESCAPE_TIME = 8 -- seconds; a real run takes longer, so faster means teleporting
local RUN_ALERT_TIME = 1.5 -- seconds the "RUN!" alert stays up

local FIRST_THROW_DELAY = 1.5 -- seconds into the chase before the first slipper
local SLIPPER_FLIGHT = 1 -- seconds in the air; the landing circle shows the whole time
local SLIPPER_RADIUS = 4.5
local SLIPPER_RANGE = 70 -- she only throws at players this close
local HAND_HEIGHT = 9
local BONK_SPEED = 6
local BONK_TIME = 1.2
local KITCHEN_HALF_WIDTH = 13
local EXIT_Z = 318 -- slippers never land past the doorway

local SHOUT_INTERVAL = 3
local SHOUTS = {
	"COME BACK HERE!",
	"WHO ATE MY COOKIES?!",
	"NO RUNNING IN THE HOUSE!",
	"WIPE YOUR FEET!",
	"I SAW THAT!",
	"YOU'RE GROUNDED!",
	"EAT YOUR VEGETABLES!",
}

type Difficulty = { [string]: number }
type Context = { Alert: (string) -> (), Flash: (Player, string, number) -> () }
type Resolve = (Player, "Succeeded" | "Failed", string) -> ()
type Slipper = { Target: Vector3, LandsAt: number, Part: BasePart, Marker: BasePart }

local AngryGrandma = {}
AngryGrandma.__index = AngryGrandma

export type Room = typeof(setmetatable(
	{} :: {
		Model: Model,
		Spawn: BasePart,
		_alert: (string) -> (),
		_flash: (Player, string, number) -> (),
		_difficulty: Difficulty,
		_grandma: Model,
		_speech: BillboardGui,
		_path: PathFollower.Path,
		_gate: BasePart,
		_checkpoint: BasePart,
		_exit: BasePart,
		_naughtyCorner: BasePart,
		_passedCheckpoint: { [Player]: boolean },
		_slippers: { Slipper },
		_resolve: Resolve?,
		_openedAt: number,
		_chaseStartsAt: number,
		_nextThrowAt: number,
		_nextShoutAt: number,
	},
	AngryGrandma
))

local function isInside(zone: BasePart, position: Vector3): boolean
	local localPosition = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Y) <= half.Y
		and math.abs(localPosition.Z) <= half.Z
end

local function rootPart(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Flips the kitchen left-to-right. Grandma starts on the center line, so she stays as she is.
local function mirror(model: Model, grandma: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and not part:IsDescendantOf(grandma) then
			part.CFrame += Vector3.new(-2 * part.Position.X, 0, 0)
		end
	end
end

local function newPart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

function AngryGrandma.new(model: Model, difficulty: Difficulty, context: Context): Room
	local grandma = model:FindFirstChild("Grandma") :: Model
	if math.random(2) == 1 then
		mirror(model, grandma)
	end
	local pathFolder = (grandma:FindFirstChild("Path") :: ObjectValue).Value :: Instance
	local head = grandma:FindFirstChild("Head") :: BasePart
	return setmetatable({
		Model = model,
		Spawn = model:FindFirstChild("Spawn") :: BasePart,
		_alert = context.Alert,
		_flash = context.Flash,
		_difficulty = difficulty,
		_grandma = grandma,
		_speech = head:FindFirstChild("Speech") :: BillboardGui,
		_path = PathFollower.FromFolder(pathFolder),
		_gate = model:FindFirstChild("StartGate") :: BasePart,
		_checkpoint = model:FindFirstChild("Checkpoint") :: BasePart,
		_exit = model:FindFirstChild("ExitZone") :: BasePart,
		_naughtyCorner = model:FindFirstChild("NaughtyCornerSpot") :: BasePart,
		_passedCheckpoint = {},
		_slippers = {},
		_resolve = nil,
		_openedAt = 0,
		_chaseStartsAt = 0,
		_nextThrowAt = 0,
		_nextShoutAt = 0,
	}, AngryGrandma)
end

-- Opens the gate now; Grandma starts chasing once the warning time is over.
function AngryGrandma.Start(self: Room, resolve: Resolve)
	local difficulty = self._difficulty
	self._resolve = resolve
	self._openedAt = workspace:GetServerTimeNow()
	self._chaseStartsAt = self._openedAt + difficulty.WarningTime
	self._nextThrowAt = self._chaseStartsAt + FIRST_THROW_DELAY
	self._nextShoutAt = self._chaseStartsAt
	for _, name in { "StartSpeed", "Acceleration", "MaxSpeed" } do
		self._grandma:SetAttribute(name, difficulty[name])
	end
	self._grandma:SetAttribute("StartedAt", self._chaseStartsAt)
	self._gate:Destroy()
end

-- Throws a slipper at where `root` will be when it lands, and marks that spot.
function AngryGrandma._throwSlipper(self: Room, from: Vector3, root: BasePart, now: number)
	local velocity = root.AssemblyLinearVelocity
	local aim = root.Position + Vector3.new(velocity.X, 0, velocity.Z) * SLIPPER_FLIGHT
	local target = Vector3.new(math.clamp(aim.X, -KITCHEN_HALF_WIDTH, KITCHEN_HALF_WIDTH), 0, math.max(aim.Z, EXIT_Z))

	local marker = newPart("SlipperTarget", Vector3.new(0.2, SLIPPER_RADIUS * 2, SLIPPER_RADIUS * 2), Color3.fromRGB(255, 60, 60))
	marker.Shape = Enum.PartType.Cylinder
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.4
	marker.CFrame = CFrame.new(target.X, 0.15, target.Z) * CFrame.Angles(0, 0, math.rad(90))
	marker.Parent = self.Model

	local slipper = newPart("Slipper", Vector3.new(1.4, 0.6, 2.8), Color3.fromRGB(255, 140, 190))
	slipper.CFrame = CFrame.new(from)
	slipper:SetAttribute("From", from)
	slipper:SetAttribute("To", target + Vector3.new(0, 0.4, 0))
	slipper:SetAttribute("LaunchAt", now)
	slipper:SetAttribute("Flight", SLIPPER_FLIGHT)
	slipper:SetAttribute("ArcHeight", 8)
	CollectionService:AddTag(slipper, "Projectile")
	slipper.Parent = self.Model

	table.insert(self._slippers, { Target = target, LandsAt = now + SLIPPER_FLIGHT, Part = slipper, Marker = marker })
end

function AngryGrandma.Update(self: Room, activePlayers: { Player }, now: number)
	local resolve = self._resolve :: Resolve
	local difficulty = self._difficulty

	if now < self._chaseStartsAt then
		self._alert(`Grandma wakes up in {math.ceil(self._chaseStartsAt - now)}...`)
	elseif now < self._chaseStartsAt + RUN_ALERT_TIME then
		self._alert("SHE'S AWAKE! RUN!")
	else
		self._alert("")
	end

	local chasing = now >= self._chaseStartsAt
	local travelled = PathFollower.TravelDistance(
		now - self._chaseStartsAt,
		difficulty.StartSpeed,
		difficulty.Acceleration,
		difficulty.MaxSpeed
	)
	local grandmaPosition = PathFollower.At(self._path, travelled)

	if chasing and now >= self._nextShoutAt then
		self._nextShoutAt = now + SHOUT_INTERVAL
		local label = self._speech:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = SHOUTS[math.random(#SHOUTS)]
		end
		self._speech.Enabled = true
	end

	if chasing and now >= self._nextThrowAt then
		self._nextThrowAt = now + difficulty.ThrowInterval
		local targets = {}
		for _, player in activePlayers do
			local root = rootPart(player)
			if
				root
				and root.Position.Z < grandmaPosition.Z
				and flatDistance(root.Position, grandmaPosition) < SLIPPER_RANGE
			then
				table.insert(targets, root)
			end
		end
		if #targets > 0 then
			self:_throwSlipper(grandmaPosition + Vector3.new(0, HAND_HEIGHT, 0), targets[math.random(#targets)], now)
		end
	end

	for i = #self._slippers, 1, -1 do
		local slipper = self._slippers[i]
		if now >= slipper.LandsAt then
			for _, player in activePlayers do
				local root = rootPart(player)
				if root and flatDistance(root.Position, slipper.Target) < SLIPPER_RADIUS then
					PlayerEffects.Slow(player, BONK_SPEED, BONK_TIME)
					self._flash(player, "BONK!", 1)
				end
			end
			slipper.Marker:Destroy()
			Debris:AddItem(slipper.Part, 1) -- leave the slipper on the floor for a moment
			table.remove(self._slippers, i)
		end
	end

	for _, player in activePlayers do
		local root = rootPart(player)
		if not root then
			continue
		end
		local position = root.Position

		if isInside(self._checkpoint, position) then
			self._passedCheckpoint[player] = true
		end

		if
			isInside(self._exit, position)
			and self._passedCheckpoint[player]
			and now - self._openedAt >= MIN_ESCAPE_TIME
		then
			resolve(player, "Succeeded", "YOU ESCAPED!")
		elseif chasing then
			local reached = flatDistance(position, grandmaPosition) < CATCH_RADIUS
			local passed = grandmaPosition.Z < position.Z - PASS_MARGIN
			if reached or passed then
				resolve(player, "Failed", "GRANDMA GOT YOU!")
				teleport(player, self._naughtyCorner)
			end
		end
	end
end

function AngryGrandma.Cleanup(self: Room)
	table.clear(self._passedCheckpoint)
	table.clear(self._slippers)
	self._resolve = nil
end

return AngryGrandma
