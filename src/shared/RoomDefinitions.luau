--!strict
-- Every room that can appear behind a door. Each entry needs a template in
-- ServerStorage.RoomTemplates and a module in Server.Rooms with the same Id.
-- Difficulty is indexed by door risk (1 = safe ... 3 = cursed); its keys are
-- whatever that room's module reads.

export type RoomDefinition = {
	Id: string,
	DisplayName: string,
	Objective: string,
	Duration: number, -- seconds before anyone still inside fails
	Difficulty: { { [string]: number } },
}

local RoomDefinitions: { [string]: RoomDefinition } = {
	AngryGrandma = {
		Id = "AngryGrandma",
		DisplayName = "Angry Grandma",
		Objective = "Escape Grandma! Dodge her slippers!",
		Duration = 25,
		Difficulty = {
			{ StartSpeed = 11, Acceleration = 0.6, MaxSpeed = 17, WarningTime = 3, ThrowInterval = 3 },
			{ StartSpeed = 12, Acceleration = 0.8, MaxSpeed = 18, WarningTime = 2.5, ThrowInterval = 2.2 },
			{ StartSpeed = 12.5, Acceleration = 0.9, MaxSpeed = 18.5, WarningTime = 2.5, ThrowInterval = 1.6 },
		},
	},
	GiantChicken = {
		Id = "GiantChicken",
		DisplayName = "Giant Chicken",
		Objective = "Find the keys, then escape through the barn gate!",
		Duration = 50,
		Difficulty = {
			-- TurnRate is how much the chicken can steer mid-charge (degrees/s); keep it low so a sidestep dodges
			{ PatrolSpeed = 8, ChargeSpeed = 26, ChargeTime = 1.4, RestTime = 2.2, WindupTime = 0.8, DetectRadius = 20, TurnRate = 0, KeysNeeded = 3 },
			{ PatrolSpeed = 9, ChargeSpeed = 28, ChargeTime = 1.6, RestTime = 1.8, WindupTime = 0.7, DetectRadius = 24, TurnRate = 25, KeysNeeded = 3 },
			{ PatrolSpeed = 10, ChargeSpeed = 30, ChargeTime = 1.8, RestTime = 1.4, WindupTime = 0.6, DetectRadius = 28, TurnRate = 45, KeysNeeded = 4 },
		},
	},
	ReverseGravity = {
		Id = "ReverseGravity",
		DisplayName = "Reverse Gravity",
		Objective = "Gravity keeps flipping! Reach the gold platform!",
		Duration = 45,
		Difficulty = {
			{ FirstFlipDelay = 6, FlipInterval = 6, WarningTime = 2.5 },
			{ FirstFlipDelay = 5, FlipInterval = 5, WarningTime = 2 },
			{ FirstFlipDelay = 4.5, FlipInterval = 4.2, WarningTime = 1.6 },
		},
	},
}

return RoomDefinitions
