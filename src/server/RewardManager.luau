--!strict
-- Pays out coins through DataManager. Every payout has a key, so the same
-- reward can never be paid twice, even if game code asks twice.

local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)

local RewardManager = {}

local paidKeys: { [Player]: { [string]: boolean } } = {}

function RewardManager.Init()
	Players.PlayerRemoving:Connect(function(player)
		paidKeys[player] = nil
	end)
end

-- Adds `amount` coins unless `key` was already paid to this player (or their
-- data hasn't loaded yet). Returns whether it paid.
function RewardManager.Grant(player: Player, key: string, amount: number): boolean
	local keys = paidKeys[player]
	if not keys then
		keys = {}
		paidKeys[player] = keys
	end
	if keys[key] or not DataManager.AddCoins(player, amount) then
		return false
	end
	keys[key] = true
	return true
end

return RewardManager
