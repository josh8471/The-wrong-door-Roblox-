--!strict
-- Giant Chicken: find the keys hidden around the farm, then escape through the
-- barn gate. The chicken patrols a loop. When it spots someone it stops and
-- squawks ("!") while aiming at where they're heading, locks its aim just
-- before it charges, then dashes in a near-straight line. Change direction
-- after the lock and it thunders past you. After a charge it has to catch its
-- breath. Keys are shared: anyone's pickup counts for the whole group.
-- The server moves the chicken and sends its position ~10x per second
-- (MovePos/MoveVel/MoveAt attributes); Client.ChaserRenderer smooths it on screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PathFollower = require(ReplicatedStorage.Shared.PathFollower)
local teleport = require(script.Parent.Parent.Teleport)

local CATCH_RADIUS = 4.5 -- studs, measured flat along the ground
local AIM_LOCK_TIME = 0.35 -- seconds before the charge when the chicken stops re-aiming
local KEY_RADIUS = 4.5
local BODY_RADIUS = 4 -- how close the chicken's center gets to solid obstacles and fences
local WAYPOINT_REACHED = 3
local MIN_ESCAPE_TIME = 8 -- seconds; nobody finds the keys faster, so faster means teleporting
local ALERT_TIME = 2.5

type Difficulty = { [string]: number }
type Context = { Alert: (string) -> (), SetStatus: (string) -> (), Flash: (Player, string, number) -> () }
type Resolve = (Player, "Succeeded" | "Failed", string) -> ()
type State = "Patrol" | "Windup" | "Charge" | "Rest"
type Key = { Model: Model, Position: Vector3 }

local GiantChicken = {}
GiantChicken.__index = GiantChicken

export type Room = typeof(setmetatable(
	{} :: {
		Model: Model,
		Spawn: BasePart,
		_alert: (string) -> (),
		_setStatus: (string) -> (),
		_flash: (Player, string, number) -> (),
		_difficulty: Difficulty,
		_chicken: Model,
		_spottedMark: BillboardGui,
		_patrol: { Vector3 },
		_solids: { BasePart },
		_bounds: BasePart,
		_gate: BasePart,
		_exit: BasePart,
		_coop: BasePart,
		_keys: { Key },
		_keysNeeded: number,
		_keysFound: number,
		_resolve: Resolve?,
		_state: State,
		_stateEndsAt: number,
		_target: BasePart?,
		_waypoint: number,
		_position: Vector3,
		_heading: Vector3,
		_startedAt: number,
		_lastUpdate: number,
		_alertEndsAt: number,
	},
	GiantChicken
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

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return flat(a - b).Magnitude
end

-- Turns `current` toward `desired` (both flat) by at most `maxAngle` radians.
local function turnToward(current: Vector3, desired: Vector3, maxAngle: number): Vector3
	if desired.Magnitude < 0.01 then
		return current
	end
	desired = desired.Unit
	local angle = math.acos(math.clamp(current:Dot(desired), -1, 1))
	if angle <= maxAngle then
		return desired
	end
	local direction = if current:Cross(desired).Y >= 0 then 1 else -1
	return CFrame.Angles(0, direction * maxAngle, 0):VectorToWorldSpace(current)
end

-- Keeps the chicken's center at least BODY_RADIUS away from every solid box.
local function pushOutOfSolids(position: Vector3, solids: { BasePart }): Vector3
	for _, solid in solids do
		local center, half = solid.Position, solid.Size / 2
		local closest = Vector3.new(
			math.clamp(position.X, center.X - half.X, center.X + half.X),
			position.Y,
			math.clamp(position.Z, center.Z - half.Z, center.Z + half.Z)
		)
		local offset = position - closest
		if offset.Magnitude < BODY_RADIUS then
			if offset.Magnitude > 0.01 then
				position = closest + offset.Unit * BODY_RADIUS
			else
				local side = if position.X < center.X then -1 else 1
				position = Vector3.new(center.X + side * (half.X + BODY_RADIUS), position.Y, position.Z)
			end
		end
	end
	return position
end

local function clampToBounds(position: Vector3, bounds: BasePart): Vector3
	local center, half = bounds.Position, bounds.Size / 2
	return Vector3.new(
		math.clamp(position.X, center.X - half.X + BODY_RADIUS, center.X + half.X - BODY_RADIUS),
		position.Y,
		math.clamp(position.Z, center.Z - half.Z + BODY_RADIUS, center.Z + half.Z - BODY_RADIUS)
	)
end

local function nearestRoot(players: { Player }, from: Vector3, radius: number): BasePart?
	local best, bestDistance = nil, radius
	for _, player in players do
		local root = rootPart(player)
		if root then
			local distance = flatDistance(root.Position, from)
			if distance < bestDistance then
				best, bestDistance = root, distance
			end
		end
	end
	return best
end

function GiantChicken.new(model: Model, difficulty: Difficulty, context: Context): Room
	local chicken = model:FindFirstChild("Chicken") :: Model
	local head = chicken:FindFirstChild("Head") :: BasePart
	local patrol = PathFollower.FromFolder(model:FindFirstChild("PatrolPath") :: Instance).Points

	-- Hide keys at a random set of the possible spots. The prototype key is taken
	-- out of the room before it's added to the world, so it never shows up itself.
	local prototypes = model:FindFirstChild("Prototypes") :: Instance
	local keyPrototype = prototypes:FindFirstChild("Key") :: Model
	local spots = (model:FindFirstChild("KeySpots") :: Instance):GetChildren()
	local keysFolder = Instance.new("Folder")
	keysFolder.Name = "Keys"
	keysFolder.Parent = model
	local keys = {}
	for _ = 1, math.min(difficulty.KeysNeeded, #spots) do
		local spot = table.remove(spots, math.random(#spots)) :: BasePart
		local key = keyPrototype:Clone()
		key:PivotTo(CFrame.new(spot.Position))
		key.Parent = keysFolder
		table.insert(keys, { Model = key, Position = spot.Position })
	end
	prototypes:Destroy()

	local solids = {}
	for _, solid in (model:FindFirstChild("Solids") :: Instance):GetChildren() do
		if solid:IsA("BasePart") then
			table.insert(solids, solid)
		end
	end

	return setmetatable({
		Model = model,
		Spawn = model:FindFirstChild("Spawn") :: BasePart,
		_alert = context.Alert,
		_setStatus = context.SetStatus,
		_flash = context.Flash,
		_difficulty = difficulty,
		_chicken = chicken,
		_spottedMark = head:FindFirstChild("SpottedMark") :: BillboardGui,
		_patrol = patrol,
		_solids = solids,
		_bounds = model:FindFirstChild("Bounds") :: BasePart,
		_gate = model:FindFirstChild("BarnGate") :: BasePart,
		_exit = model:FindFirstChild("ExitZone") :: BasePart,
		_coop = model:FindFirstChild("CoopSpot") :: BasePart,
		_keys = keys,
		_keysNeeded = #keys,
		_keysFound = 0,
		_resolve = nil,
		_state = "Patrol" :: State,
		_stateEndsAt = 0,
		_target = nil,
		_waypoint = 2,
		_position = Vector3.new(patrol[1].X, 0, patrol[1].Z),
		_heading = Vector3.new(0, 0, -1),
		_startedAt = 0,
		_lastUpdate = 0,
		_alertEndsAt = 0,
	}, GiantChicken)
end

-- Shows a room-wide alert for a few seconds.
function GiantChicken._announce(self: Room, text: string, now: number)
	self._alert(text)
	self._alertEndsAt = now + ALERT_TIME
end

function GiantChicken._updateStatus(self: Room)
	self._setStatus(
		if self._keysFound >= self._keysNeeded
			then "Gate open! Get to the barn!"
			else `Keys {self._keysFound}/{self._keysNeeded}`
	)
end

-- Sends the chicken's position to clients, which smooth it on screen.
function GiantChicken._publish(self: Room, velocity: Vector3, now: number)
	self._chicken:SetAttribute("MovePos", self._position)
	self._chicken:SetAttribute("MoveVel", velocity)
	self._chicken:SetAttribute("Facing", self._heading)
	self._chicken:SetAttribute("MoveAt", now)
end

function GiantChicken.Start(self: Room, resolve: Resolve)
	local now = workspace:GetServerTimeNow()
	self._resolve = resolve
	self._startedAt = now
	self._lastUpdate = now
	self:_announce("BAWK! Find the keys!", now)
	self:_updateStatus()
	self:_publish(Vector3.zero, now)
end

-- Runs the chicken's patrol/windup/charge/rest cycle and returns its velocity.
function GiantChicken._moveChicken(self: Room, activePlayers: { Player }, now: number, dt: number): Vector3
	local difficulty = self._difficulty
	local velocity = Vector3.zero

	if self._state == "Patrol" then
		local spotted = nearestRoot(activePlayers, self._position, difficulty.DetectRadius)
		if spotted then
			self._state, self._stateEndsAt, self._target = "Windup", now + difficulty.WindupTime, spotted
			self._spottedMark.Enabled = true
			local player = Players:GetPlayerFromCharacter(spotted.Parent)
			if player then
				self._flash(player, "THE CHICKEN SEES YOU!", 1.2)
			end
		else
			local toWaypoint = flat(self._patrol[self._waypoint] - self._position)
			if toWaypoint.Magnitude < WAYPOINT_REACHED then
				self._waypoint = self._waypoint % #self._patrol + 1
			else
				self._heading = toWaypoint.Unit
				velocity = self._heading * difficulty.PatrolSpeed
			end
		end
	elseif self._state == "Windup" then
		local target = self._target
		if target and target.Parent and now < self._stateEndsAt - AIM_LOCK_TIME then
			local lead = target.AssemblyLinearVelocity * (flatDistance(target.Position, self._position) / difficulty.ChargeSpeed)
			self._heading = turnToward(self._heading, flat(target.Position + lead - self._position), math.pi)
		end
		if now >= self._stateEndsAt then
			self._state, self._stateEndsAt = "Charge", now + difficulty.ChargeTime
		end
	elseif self._state == "Charge" then
		local target = self._target
		if target and target.Parent then
			local maxTurn = math.rad(difficulty.TurnRate) * dt
			self._heading = turnToward(self._heading, flat(target.Position - self._position), maxTurn)
		end
		velocity = self._heading * difficulty.ChargeSpeed
		if now >= self._stateEndsAt then
			self._state, self._stateEndsAt, self._target = "Rest", now + difficulty.RestTime, nil
			self._spottedMark.Enabled = false
		end
	elseif now >= self._stateEndsAt then -- done resting: back to the nearest patrol point
		self._state = "Patrol"
		local nearest, nearestDistance = 1, math.huge
		for index, point in self._patrol do
			local distance = flatDistance(point, self._position)
			if distance < nearestDistance then
				nearest, nearestDistance = index, distance
			end
		end
		self._waypoint = nearest
	end

	local moved = clampToBounds(pushOutOfSolids(self._position + velocity * dt, self._solids), self._bounds)
	local actualVelocity = if dt > 0 then (moved - self._position) / dt else Vector3.zero
	self._position = moved
	return actualVelocity
end

function GiantChicken.Update(self: Room, activePlayers: { Player }, now: number)
	local resolve = self._resolve :: Resolve
	local dt = math.min(now - self._lastUpdate, 0.25)
	self._lastUpdate = now

	if self._alertEndsAt > 0 and now >= self._alertEndsAt then
		self._alertEndsAt = 0
		self._alert("")
	end

	local velocity = self:_moveChicken(activePlayers, now, dt)
	self:_publish(velocity, now)

	for i = #self._keys, 1, -1 do
		local key = self._keys[i]
		for _, player in activePlayers do
			local root = rootPart(player)
			if root and (root.Position - key.Position).Magnitude < KEY_RADIUS then
				key.Model:Destroy()
				table.remove(self._keys, i)
				self._keysFound += 1
				self._flash(player, "KEY FOUND!", 1.2)
				if self._keysFound == self._keysNeeded then
					self._gate:Destroy()
					self:_announce("THE BARN GATE IS OPEN!", now)
				end
				self:_updateStatus()
				break
			end
		end
	end

	local gateOpen = self._keysFound >= self._keysNeeded
	for _, player in activePlayers do
		local root = rootPart(player)
		if not root then
			continue
		end
		if gateOpen and isInside(self._exit, root.Position) and now - self._startedAt >= MIN_ESCAPE_TIME then
			resolve(player, "Succeeded", "YOU ESCAPED THE FARM!")
		elseif flatDistance(root.Position, self._position) < CATCH_RADIUS then
			resolve(player, "Failed", "THE CHICKEN GOT YOU!")
			teleport(player, self._coop)
		end
	end
end

function GiantChicken.Cleanup(self: Room)
	table.clear(self._keys)
	self._target = nil
	self._resolve = nil
end

return GiantChicken
