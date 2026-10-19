--!strict
-- Server side of the cosmetic shop. The client only asks ("buy X", "equip X");
-- this checks every request against the catalog and the player's saved coins
-- and items, so nobody can buy without paying or equip what they don't own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local CosmeticEffects = require(script.Parent.CosmeticEffects)
local DataManager = require(script.Parent.DataManager)

local REQUEST_COOLDOWN = 0.25 -- seconds between requests from one player

local ShopManager = {}

local lastRequestAt: { [Player]: number } = {}

-- Returns whether it worked and a message to show the player ("" for none).
local function handle(player: Player, action: string, itemId: string): (boolean, string)
	local item = Cosmetics.ById[itemId]
	local profile = DataManager.Get(player)
	if not item then
		return false, "That item doesn't exist."
	elseif not profile then
		return false, "Your data is still loading."
	end

	if action == "Buy" then
		if profile.Owned[itemId] then
			return false, "You already own that."
		elseif not DataManager.TrySpend(player, item.Price) then
			return false, "Not enough coins!"
		end
		DataManager.GiveCosmetic(player, itemId)
		DataManager.Equip(player, item.Slot, itemId)
		CosmeticEffects.Apply(player)
		return true, `Bought {item.Name}!`
	elseif action == "Equip" then
		if not profile.Owned[itemId] then
			return false, "You don't own that yet."
		end
		DataManager.Equip(player, item.Slot, itemId)
	elseif action == "Unequip" then
		if profile.Equipped[item.Slot] ~= itemId then
			return false, "That isn't equipped."
		end
		DataManager.Equip(player, item.Slot, nil)
	else
		return false, "Unknown request."
	end
	CosmeticEffects.Apply(player)
	return true, ""
end

function ShopManager.Init()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local shopRequest = Instance.new("RemoteFunction")
	shopRequest.Name = "ShopRequest"
	shopRequest.OnServerInvoke = function(player: Player, action: unknown, itemId: unknown)
		local now = os.clock()
		if now - (lastRequestAt[player] or 0) < REQUEST_COOLDOWN then
			return false, "Slow down!"
		end
		lastRequestAt[player] = now
		if typeof(action) ~= "string" or typeof(itemId) ~= "string" then
			return false, "Bad request."
		end
		return handle(player, action :: string, itemId :: string)
	end
	shopRequest.Parent = remotes

	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
	end)
end

return ShopManager
