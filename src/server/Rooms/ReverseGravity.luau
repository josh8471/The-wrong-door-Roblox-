--!strict
-- Reverse Gravity: every few seconds gravity "flips". Really the room flips: the
-- blue and orange platform layers swap between floor and ceiling, so whatever
-- is above you becomes what you stand on. Stand under the other color before
-- each flip, ride it forward, and reach the gold platform. Fall and you're lost
-- in space. Flipping the room instead of gravity keeps character physics normal.

local teleport = require(script.Parent.Parent.Teleport)

local FLIP_HEIGHT = 12 -- layers mirror across this height: floor (top at 0) <-> ceiling (bottom at 24)
local FALL_LIMIT = -20 -- below this height you've fallen out of the room

type Difficulty = { [string]: number }
type Context = { Alert: (string) -> (), SetStatus: (string) -> (), FlipWorld: () -> () }
type Resolve = (Player, "Succeeded" | "Failed", string) -> ()

local ReverseGravity = {}
ReverseGravity.__index = ReverseGravity

export type Room = typeof(setmetatable(
	{} :: {
		Model: Model,
		Spawn: BasePart,
		_alert: (string) -> (),
		_setStatus: (string) -> (),
		_flipWorld: () -> (),
		_difficulty: Difficulty,
		_layers: { BasePart },
		_flipsNeeded: number,
		_flips: number,
		_blueDown: boolean,
		_nextFlipAt: number,
		_exit: BasePart,
		_station: BasePart,
		_resolve: Resolve?,
	},
	ReverseGravity
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

function ReverseGravity.new(model: Model, difficulty: Difficulty, context: Context): Room
	local layers = {}
	for _, folderName in { "BlueLayer", "OrangeLayer" } do
		for _, part in (model:FindFirstChild(folderName) :: Instance):GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(layers, part)
			end
		end
	end
	return setmetatable({
		Model = model,
		Spawn = model:FindFirstChild("Spawn") :: BasePart,
		_alert = context.Alert,
		_setStatus = context.SetStatus,
		_flipWorld = context.FlipWorld,
		_difficulty = difficulty,
		_layers = layers,
		_flipsNeeded = model:GetAttribute("FlipsNeeded") :: number, -- the goal only counts after this many flips
		_flips = 0,
		_blueDown = true,
		_nextFlipAt = 0,
		_exit = model:FindFirstChild("ExitZone") :: BasePart,
		_station = model:FindFirstChild("SpaceStationSpot") :: BasePart,
		_resolve = nil,
	}, ReverseGravity)
end

function ReverseGravity.Start(self: Room, resolve: Resolve)
	self._resolve = resolve
	self._nextFlipAt = workspace:GetServerTimeNow() + self._difficulty.FirstFlipDelay
end

-- Swaps the two layers: everything mirrors across FLIP_HEIGHT.
function ReverseGravity._flip(self: Room)
	for _, part in self._layers do
		part.CFrame += Vector3.new(0, 2 * (FLIP_HEIGHT - part.Position.Y), 0)
	end
	self._flips += 1
	self._blueDown = not self._blueDown
	self._flipWorld()
end

function ReverseGravity.Update(self: Room, activePlayers: { Player }, now: number)
	local resolve = self._resolve :: Resolve
	local difficulty = self._difficulty

	if now >= self._nextFlipAt then
		self:_flip()
		self._nextFlipAt = now + difficulty.FlipInterval
	end

	local untilFlip = self._nextFlipAt - now
	self._alert(if untilFlip <= difficulty.WarningTime then `GRAVITY FLIPS IN {math.ceil(untilFlip)}!` else "")
	local nextColor = if self._blueDown then "ORANGE" else "BLUE"
	self._setStatus(`Flips {math.min(self._flips, self._flipsNeeded)}/{self._flipsNeeded} · Next: stand under {nextColor}`)

	for _, player in activePlayers do
		local root = rootPart(player)
		if not root then
			continue
		end
		if root.Position.Y < FALL_LIMIT then
			resolve(player, "Failed", "LOST IN SPACE!")
			teleport(player, self._station)
		elseif self._flips >= self._flipsNeeded and isInside(self._exit, root.Position) then
			resolve(player, "Succeeded", "GRAVITY CHAMPION!")
		end
	end
end

function ReverseGravity.Cleanup(self: Room)
	self._resolve = nil
end

return ReverseGravity
