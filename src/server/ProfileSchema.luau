--!strict
-- The shape of saved player data, kept small and versioned. Reconcile() fills
-- in anything missing (e.g. a field added in a later version) so old saves keep
-- working, and never drops anything the player earned.

export type Profile = {
	Coins: number,
	Stats: { RoomsCompleted: number, RunsPlayed: number, RunsSurvived: number },
	Owned: { [string]: boolean },
	Equipped: { [string]: string },
}

local STAT_NAMES = { "RoomsCompleted", "RunsPlayed", "RunsSurvived" }

local ProfileSchema = {}

ProfileSchema.Version = 1

function ProfileSchema.Default(): Profile
	return {
		Coins = 0,
		Stats = { RoomsCompleted = 0, RunsPlayed = 0, RunsSurvived = 0 },
		Owned = {},
		Equipped = {},
	}
end

-- Builds a clean profile from whatever was saved, filling gaps from the defaults.
-- Future schema versions migrate old data here.
function ProfileSchema.Reconcile(saved: any): Profile
	local profile = ProfileSchema.Default()
	if typeof(saved) ~= "table" then
		return profile
	end
	if typeof(saved.Coins) == "number" then
		profile.Coins = math.max(0, math.floor(saved.Coins))
	end
	if typeof(saved.Stats) == "table" then
		for _, name in STAT_NAMES do
			local value = saved.Stats[name]
			if typeof(value) == "number" then
				(profile.Stats :: any)[name] = value
			end
		end
	end
	if typeof(saved.Owned) == "table" then
		for id, owned in saved.Owned do
			if typeof(id) == "string" and owned == true then
				profile.Owned[id] = true
			end
		end
	end
	if typeof(saved.Equipped) == "table" then
		for slot, id in saved.Equipped do
			if typeof(slot) == "string" and typeof(id) == "string" and profile.Owned[id] then
				profile.Equipped[slot] = id
			end
		end
	end
	return profile
end

return ProfileSchema
