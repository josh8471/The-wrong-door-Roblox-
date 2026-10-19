--!strict
-- Moves a player's character onto a flat pad (`target`), at a random spot on it
-- so a group of players doesn't land stacked on one point.

local function teleport(player: Player, target: BasePart)
	local character = player.Character
	if not character then
		return
	end
	local size = target.Size
	local offset = CFrame.new((math.random() - 0.5) * size.X, size.Y / 2 + 3, (math.random() - 0.5) * size.Z)
	character:PivotTo(target.CFrame * offset)
end

return teleport
