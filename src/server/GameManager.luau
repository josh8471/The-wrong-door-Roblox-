--!strict
-- Server round loop. Owns the game state and moves players between the lobby,
-- the door area and rooms. Voting lives in DoorVoting, rooms in RoomManager and
-- coins in RewardManager; this file only decides what happens when.
-- A run is up to four rooms. Fail a room and you're out for the rest of the run
-- (your camera follows the survivors); survive every room for a bonus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataManager = require(script.Parent.DataManager)
local DoorVoting = require(script.Parent.DoorVoting)
local RewardManager = require(script.Parent.RewardManager)
local RoomManager = require(script.Parent.RoomManager)
local teleport = require(script.Parent.Teleport)

local States = GameConfig.States

local VALID_TRANSITIONS: { [string]: { [string]: boolean } } = {
	[States.WaitingForPlayers] = { [States.Intermission] = true },
	[States.Intermission] = { [States.DoorVoting] = true, [States.WaitingForPlayers] = true },
	[States.DoorVoting] = { [States.LoadingRoom] = true },
	[States.LoadingRoom] = { [States.PlayingRoom] = true },
	[States.PlayingRoom] = { [States.RoomCompleted] = true },
	[States.RoomCompleted] = { [States.DoorVoting] = true, [States.RunCompleted] = true },
	[States.RunCompleted] = { [States.ReturningToLobby] = true },
	[States.ReturningToLobby] = { [States.Intermission] = true, [States.WaitingForPlayers] = true },
}

-- Per-run player attributes, all cleared when the run ends. The Run* ones feed
-- the client's results card.
local RUN_ATTRIBUTES = {
	"InRun",
	"Eliminated",
	"RoomResult",
	"RoomResultText",
	"RunSurvived",
	"RunRoomsCleared",
	"RunStages",
	"RunCoins",
}

local GameManager = {}

local status: Configuration
local currentState = States.WaitingForPlayers
local participants: { [Player]: boolean } = {} -- everyone who started the current run
local survivors: { [Player]: boolean } = {} -- participants who haven't failed a room yet
local roomsCleared: { [Player]: number } = {}
local runCoins: { [Player]: number } = {}
local runCount = 0

local lobbySpawn: BasePart
local voteGatherPoint: BasePart

-- Clients read these attributes to draw the HUD. EndsAt is a server timestamp,
-- so clients run the countdown locally instead of receiving updates every second.
local function setState(newState: string, duration: number?, message: string?)
	assert(VALID_TRANSITIONS[currentState][newState], `Invalid state transition: {currentState} -> {newState}`)
	currentState = newState
	status:SetAttribute("State", newState)
	status:SetAttribute("EndsAt", if duration then workspace:GetServerTimeNow() + duration else 0)
	status:SetAttribute("Message", message or "")
	print(`[GameManager] {newState}`)
end

local function notEnoughPlayers(): boolean
	return #Players:GetPlayers() < GameConfig.MinPlayers
end

local function noParticipantsLeft(): boolean
	return next(participants) == nil
end

local function noSurvivorsLeft(): boolean
	return next(survivors) == nil
end

local function isSurvivor(player: Player): boolean
	return survivors[player] == true
end

local function survivorList(): { Player }
	local list = {}
	for player in survivors do
		table.insert(list, player)
	end
	return list
end

-- Waits up to `duration` seconds, or less if `stopEarly` returns true.
local function waitFor(duration: number, stopEarly: () -> boolean)
	local deadline = os.clock() + duration
	while os.clock() < deadline and not stopEarly() do
		task.wait(0.25)
	end
end

local function teleportSurvivors(target: BasePart)
	for player in survivors do
		teleport(player, target)
	end
end

local function clearRoomResults()
	status:SetAttribute("RoomName", nil)
	for player in participants do
		player:SetAttribute("RoomResult", nil)
		player:SetAttribute("RoomResultText", nil)
		player:SetAttribute("Flash", nil)
	end
end

local function playStage(stage: number)
	status:SetAttribute("Stage", stage)

	DoorVoting.Open(isSurvivor)
	setState(States.DoorVoting, GameConfig.VotingDuration, "Pick a door below. Majority wins!")
	teleportSurvivors(voteGatherPoint)
	waitFor(GameConfig.VotingDuration, noSurvivorsLeft)
	local door, result = DoorVoting.Close()

	local voteMessage = if result == "NoVotes"
		then `Nobody voted, so fate picked Door {door.DoorId}...`
		elseif result == "Tie" then `Tie! A coin flip picked Door {door.DoorId}...`
		else `Door {door.DoorId} wins: "{door.Hint}"`
	local definition = RoomManager.Pick()
	local room = RoomManager.Load(definition, door.Risk)
	status:SetAttribute("RoomName", definition.DisplayName)
	setState(States.LoadingRoom, GameConfig.LoadingDuration, voteMessage)
	status:SetAttribute("Alert", `It's... {string.upper(definition.DisplayName)}!`)
	teleportSurvivors(room.Spawn)
	waitFor(GameConfig.LoadingDuration, noSurvivorsLeft)

	setState(States.PlayingRoom, definition.Duration, definition.Objective)
	local results = RoomManager.Play(room, survivorList(), definition.Duration)

	-- Pay everyone who made it; everyone else is out for the rest of the run.
	-- The key makes each room pay at most once per player per run.
	local reward = GameConfig.RoomRewards[door.Risk]
	local knockedOut = {}
	local succeeded, total = 0, 0
	for player, roomResult in results do
		total += 1
		if roomResult == "Succeeded" then
			succeeded += 1
			roomsCleared[player] = (roomsCleared[player] or 0) + 1
			DataManager.AddStat(player, "RoomsCompleted")
			if RewardManager.Grant(player, `run{runCount}:room{stage}`, reward) then
				runCoins[player] = (runCoins[player] or 0) + reward
				player:SetAttribute("RoomResultText", `{player:GetAttribute("RoomResultText")} +{reward} COINS`)
			end
		else
			survivors[player] = nil
			player:SetAttribute("Eliminated", true)
			table.insert(knockedOut, player)
		end
	end

	-- Move everyone out before removing the floor under them.
	setState(States.RoomCompleted, GameConfig.RoomCompletedDuration, `{succeeded} of {total} made it out!`)
	teleportSurvivors(voteGatherPoint)
	for _, player in knockedOut do
		teleport(player, lobbySpawn)
	end
	RoomManager.Unload(room)
	waitFor(GameConfig.RoomCompletedDuration, noParticipantsLeft)
	clearRoomResults()
end

local function playRun()
	runCount += 1
	-- Players who join mid-run wait in the lobby for the next run.
	for _, player in Players:GetPlayers() do
		participants[player] = true
		survivors[player] = true
		player:SetAttribute("InRun", true)
		DataManager.AddStat(player, "RunsPlayed")
	end

	local stage = 0
	repeat
		stage += 1
		playStage(stage)
	until stage >= GameConfig.RoomsPerRun or noSurvivorsLeft()

	-- Anyone still standing has cleared every room of the run.
	local survivorCount = #survivorList()
	setState(
		States.RunCompleted,
		GameConfig.RunCompletedDuration,
		if survivorCount == 0 then "Everyone got knocked out!" else `{survivorCount} survived all {stage} rooms!`
	)
	for player in participants do
		local survived = survivors[player] == true
		if survived then
			DataManager.AddStat(player, "RunsSurvived")
			if RewardManager.Grant(player, `run{runCount}:bonus`, GameConfig.RunBonus) then
				runCoins[player] = (runCoins[player] or 0) + GameConfig.RunBonus
			end
		end
		player:SetAttribute("RunSurvived", survived)
		player:SetAttribute("RunRoomsCleared", roomsCleared[player] or 0)
		player:SetAttribute("RunStages", stage)
		player:SetAttribute("RunCoins", runCoins[player] or 0)
	end
	waitFor(GameConfig.RunCompletedDuration, noParticipantsLeft)

	setState(States.ReturningToLobby, GameConfig.ReturningDuration, "Back to the lobby.")
	for player in participants do
		teleport(player, lobbySpawn)
		for _, attribute in RUN_ATTRIBUTES do
			player:SetAttribute(attribute, nil)
		end
	end
	table.clear(participants)
	table.clear(survivors)
	table.clear(roomsCleared)
	table.clear(runCoins)
	status:SetAttribute("Stage", 0)
	task.wait(GameConfig.ReturningDuration)
end

function GameManager.Start()
	local lobby = workspace:WaitForChild("Lobby")
	lobbySpawn = lobby:WaitForChild("LobbySpawn") :: BasePart
	local doorArea = lobby:WaitForChild("DoorArea")
	voteGatherPoint = doorArea:WaitForChild("VoteGatherPoint") :: BasePart

	status = Instance.new("Configuration")
	status.Name = "GameStatus"
	status:SetAttribute("State", currentState)
	status:SetAttribute("EndsAt", 0)
	status:SetAttribute("Stage", 0)
	status:SetAttribute("Message", "Waiting for players...")
	status.Parent = ReplicatedStorage
	DoorVoting.Init(status, doorArea)
	RoomManager.Init(status)
	RewardManager.Init()

	Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
		survivors[player] = nil
		roomsCleared[player] = nil
		runCoins[player] = nil
	end)

	while true do
		if notEnoughPlayers() then
			if currentState ~= States.WaitingForPlayers then
				setState(States.WaitingForPlayers, nil, "Waiting for players...")
			end
			repeat
				task.wait(1)
			until not notEnoughPlayers()
		end

		setState(States.Intermission, GameConfig.IntermissionDuration, "Get ready to pick a door!")
		waitFor(GameConfig.IntermissionDuration, notEnoughPlayers)
		if not notEnoughPlayers() then
			playRun()
		end
	end
end

return GameManager
