--!strict
-- Shared tuning values. Change numbers here, not inside game code.

local GameConfig = {}

GameConfig.MinPlayers = 1 -- 1 allows solo testing
GameConfig.MaxPlayers = 10 -- informational: the real cap is set in Game Settings
GameConfig.DoorsPerVote = 3
GameConfig.RoomsPerRun = 4

-- Phase durations in seconds
GameConfig.IntermissionDuration = 15
GameConfig.VotingDuration = 10
GameConfig.LoadingDuration = 3
GameConfig.RoomCompletedDuration = 4
GameConfig.RunCompletedDuration = 8 -- long enough to read the results card
GameConfig.ReturningDuration = 2

-- Voting
GameConfig.VoteCooldown = 0.25 -- min seconds between vote requests from one player

-- Every vote offers one door per risk level (1 = safe, 3 = cursed), in random
-- order. Risk sets the room's difficulty and its coin reward.
GameConfig.DoorHints = {
	{ "Probably safe", "Smells like cookies", "Totally normal door" },
	{ "Looks suspicious", "Is it... breathing?", "Strange noises inside" },
	{ "Absolutely cursed", "DO NOT OPEN", "Even the door is scared" },
}

-- Coins for clearing a room, indexed by door risk
GameConfig.RoomRewards = { 10, 20, 35 }
-- Extra coins for surviving every room of a run
GameConfig.RunBonus = 100

GameConfig.States = table.freeze({
	WaitingForPlayers = "WaitingForPlayers",
	Intermission = "Intermission",
	DoorVoting = "DoorVoting",
	LoadingRoom = "LoadingRoom",
	PlayingRoom = "PlayingRoom",
	RoomCompleted = "RoomCompleted",
	RunCompleted = "RunCompleted",
	ReturningToLobby = "ReturningToLobby",
})

return GameConfig
