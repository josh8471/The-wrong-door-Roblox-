--!strict
-- Short movement effects that rooms put on players (stuns, slows). Every effect
-- wears off by itself, and ClearAll() undoes everything when a room ends.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local PlayerEffects = {}

local slowedUntil: { [Player]: number } = {}

local function setWalkSpeed(player: Player, speed: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

-- Slows `player` to `speed` for `seconds`. A newer slow replaces an older one.
function PlayerEffects.Slow(player: Player, speed: number, seconds: number)
	local endsAt = os.clock() + seconds
	slowedUntil[player] = endsAt
	setWalkSpeed(player, speed)
	task.delay(seconds, function()
		if slowedUntil[player] == endsAt then
			slowedUntil[player] = nil
			setWalkSpeed(player, StarterPlayer.CharacterWalkSpeed)
		end
	end)
end

function PlayerEffects.ClearAll()
	for player in slowedUntil do
		setWalkSpeed(player, StarterPlayer.CharacterWalkSpeed)
	end
	table.clear(slowedUntil)
end

Players.PlayerRemoving:Connect(function(player)
	slowedUntil[player] = nil
end)

return PlayerEffects
