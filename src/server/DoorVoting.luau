--!strict
-- Server-authoritative door vote. Clients only ask "I pick door N"; the server
-- checks every request, keeps the counts and picks the winner.
-- Counts and hints reach clients as GameStatus attributes (Votes1, Hint1, ...);
-- each player's confirmed pick is their "VotedDoor" attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type DoorOffer = {
	DoorId: number,
	Risk: number, -- 1 = safe ... 3 = cursed
	Hint: string,
}

export type VoteResult = "Majority" | "Tie" | "NoVotes"

local DoorVoting = {}

local status: Configuration
local hintLabels: { TextLabel } = {}

local isOpen = false
local offers: { DoorOffer } = {}
local votes: { [Player]: number } = {}
local lastRequestAt: { [Player]: number } = {}
local isEligible: (Player) -> boolean = function()
	return false
end

local function countVotes(): { number }
	local counts = table.create(#offers, 0)
	for _, doorId in votes do
		counts[doorId] += 1
	end
	return counts
end

local function publishCounts()
	for doorId, count in countVotes() do
		status:SetAttribute(`Votes{doorId}`, count)
	end
end

-- One door per risk level, in random order, each with a random hint for that risk.
local function makeOffers(): { DoorOffer }
	local risks = {}
	for doorId = 1, GameConfig.DoorsPerVote do
		risks[doorId] = (doorId - 1) % #GameConfig.DoorHints + 1
	end
	for i = #risks, 2, -1 do
		local j = math.random(i)
		risks[i], risks[j] = risks[j], risks[i]
	end

	local newOffers = {}
	for doorId, risk in risks do
		local hints = GameConfig.DoorHints[risk]
		table.insert(newOffers, { DoorId = doorId, Risk = risk, Hint = hints[math.random(#hints)] })
	end
	return newOffers
end

local function onCastVote(player: Player, doorId: unknown)
	-- Rate limit every request, valid or not, so spamming can't flood the server.
	local now = os.clock()
	if now - (lastRequestAt[player] or 0) < GameConfig.VoteCooldown then
		return
	end
	lastRequestAt[player] = now

	if not isOpen or not isEligible(player) then
		return
	end
	if typeof(doorId) ~= "number" or offers[doorId :: number] == nil then
		return
	end
	votes[player] = doorId :: number
	player:SetAttribute("VotedDoor", doorId)
	publishCounts()
end

function DoorVoting.Init(gameStatus: Configuration, doorArea: Instance)
	status = gameStatus

	for doorId = 1, GameConfig.DoorsPerVote do
		local sign = doorArea:WaitForChild(`Door{doorId}`):WaitForChild("HintSign")
		hintLabels[doorId] = sign:FindFirstChildWhichIsA("TextLabel", true) :: TextLabel
	end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local castVote = Instance.new("RemoteEvent")
	castVote.Name = "CastVote"
	castVote.OnServerEvent:Connect(onCastVote)
	castVote.Parent = remotes

	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
		if votes[player] then
			votes[player] = nil
			publishCounts()
		end
	end)
end

-- Starts a new vote. Only players for whom `eligible` returns true can vote.
function DoorVoting.Open(eligible: (Player) -> boolean)
	isEligible = eligible
	offers = makeOffers()
	table.clear(votes)
	for _, offer in offers do
		status:SetAttribute(`Hint{offer.DoorId}`, offer.Hint)
		hintLabels[offer.DoorId].Text = offer.Hint
	end
	publishCounts()
	isOpen = true
end

-- Stops accepting votes and returns the winning door. Ties, including
-- "nobody voted", are settled by a random pick among the tied doors.
function DoorVoting.Close(): (DoorOffer, VoteResult)
	isOpen = false

	local counts = countVotes()
	local best = math.max(table.unpack(counts))
	local tied = {}
	for doorId, count in counts do
		if count == best then
			table.insert(tied, doorId)
		end
	end
	local winner = offers[tied[math.random(#tied)]]

	for player in votes do
		player:SetAttribute("VotedDoor", nil)
	end
	table.clear(votes)
	for _, label in hintLabels do
		label.Text = "???"
	end

	local result: VoteResult = if best == 0 then "NoVotes" elseif #tied > 1 then "Tie" else "Majority"
	return winner, result
end

return DoorVoting
