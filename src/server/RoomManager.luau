--!strict
-- Loads, runs and unloads rooms. Every room module (Server.Rooms) follows the
-- same lifecycle, so adding a room never changes the game loop:
--   Room.new(model, difficulty, context)  build the room on a fresh copy of its template
--   room:Start(resolve)                   begin the challenge
--   room:Update(activePlayers, now)       called 10x per second; calls resolve() on wins/losses
--   room:Cleanup()                        stop anything the room started
-- RoomManager owns the timer and each player's result, and always cleans up.
-- To test one room over and over, set a "ForceRoom" attribute (a room Id) on
-- ServerStorage.RoomTemplates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RoomDefinitions = require(ReplicatedStorage.Shared.RoomDefinitions)
local CosmeticEffects = require(script.Parent.CosmeticEffects)
local PlayerEffects = require(script.Parent.PlayerEffects)

local ROOM_MODULES: { [string]: any } = {
	AngryGrandma = require(script.Parent.Rooms.AngryGrandma),
	GiantChicken = require(script.Parent.Rooms.GiantChicken),
	ReverseGravity = require(script.Parent.Rooms.ReverseGravity),
}

local UPDATE_INTERVAL = 0.1

export type Result = "Succeeded" | "Failed"

-- What every room module's instances offer.
export type Room = {
	Model: Model,
	Spawn: BasePart,
	Start: (any, (Player, Result, string) -> ()) -> (),
	Update: (any, { Player }, number) -> (),
	Cleanup: (any) -> (),
}

local RoomManager = {}

local status: Configuration
local templates: Instance
local lastRoomId: string? = nil

-- Big center banner for everyone in the room.
local function setAlert(text: string)
	if status:GetAttribute("Alert") ~= text then
		status:SetAttribute("Alert", text)
	end
end

-- Small HUD line under the objective, e.g. "Keys 1/3".
local function setStatus(text: string)
	if status:GetAttribute("RoomStatus") ~= text then
		status:SetAttribute("RoomStatus", text)
	end
end

-- A short personal banner for one player, e.g. "BONK!".
local function flash(player: Player, text: string, seconds: number)
	player:SetAttribute("Flash", text)
	task.delay(seconds, function()
		if player:GetAttribute("Flash") == text then
			player:SetAttribute("Flash", nil)
		end
	end)
end

-- Tells every client to play the screen-flip effect.
local function flipWorld()
	status:SetAttribute("WorldFlip", (status:GetAttribute("WorldFlip") or 0) + 1)
end

local CONTEXT = { Alert = setAlert, SetStatus = setStatus, Flash = flash, FlipWorld = flipWorld }

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

function RoomManager.Init(gameStatus: Configuration)
	status = gameStatus
	templates = ServerStorage:WaitForChild("RoomTemplates")
end

-- Picks a random room, avoiding the previous one when there is a choice.
function RoomManager.Pick(): RoomDefinitions.RoomDefinition
	local forced = templates:GetAttribute("ForceRoom")
	if typeof(forced) == "string" and RoomDefinitions[forced] then
		lastRoomId = forced
		return RoomDefinitions[forced]
	end

	local candidates = {}
	for id, definition in RoomDefinitions do
		if id ~= lastRoomId then
			table.insert(candidates, definition)
		end
	end
	if #candidates == 0 then
		candidates = { RoomDefinitions[lastRoomId :: string] }
	end
	local definition = candidates[math.random(#candidates)]
	lastRoomId = definition.Id
	return definition
end

-- The room is set up before it's added to the world, so players never see it half-built.
function RoomManager.Load(definition: RoomDefinitions.RoomDefinition, risk: number): Room
	local model = (templates:FindFirstChild(definition.Id) :: Model):Clone()
	model.Name = "ActiveRoom"
	local room = ROOM_MODULES[definition.Id].new(model, definition.Difficulty[risk], CONTEXT)
	model.Parent = workspace
	return room
end

-- Runs the room until every player has a result or `duration` runs out. Each
-- result is mirrored to the player's RoomResult/RoomResultText attributes for the HUD.
function RoomManager.Play(room: Room, players: { Player }, duration: number): { [Player]: Result }
	local results: { [Player]: Result } = {}
	local active: { [Player]: boolean } = {}
	for _, player in players do
		active[player] = true
	end

	local function resolve(player: Player, result: Result, text: string)
		if not active[player] then
			return
		end
		active[player] = nil
		results[player] = result
		player:SetAttribute("RoomResult", result)
		player:SetAttribute("RoomResultText", text)
		if result == "Succeeded" then
			CosmeticEffects.PlayVictory(player)
		end
	end

	room:Start(resolve)
	local deadline = os.clock() + duration
	while os.clock() < deadline do
		local stillPlaying = {}
		for player in active do
			if player.Parent ~= Players then
				active[player] = nil -- left the game
			elseif not isAlive(player) then
				resolve(player, "Failed", "OOPS! YOU DIED")
			else
				table.insert(stillPlaying, player)
			end
		end
		if #stillPlaying == 0 then
			break
		end
		room:Update(stillPlaying, workspace:GetServerTimeNow())
		task.wait(UPDATE_INTERVAL)
	end

	for player in active do
		resolve(player, "Failed", "TIME'S UP!")
	end
	return results
end

function RoomManager.Unload(room: Room)
	room:Cleanup()
	room.Model:Destroy()
	PlayerEffects.ClearAll()
	setAlert("")
	setStatus("")
	status:SetAttribute("WorldFlip", nil)
end

return RoomManager
