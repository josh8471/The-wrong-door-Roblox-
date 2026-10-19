--!strict
-- Loads and saves each player's progress (coins, stats, cosmetics) with
-- DataStoreService and mirrors it to their client: coins and runs survived in
-- leaderstats, the rest as player attributes.
-- Safety rules:
--   * A session lock stops two servers from writing the same player at once.
--   * If loading fails, the player plays on a temporary profile that is NEVER
--     saved, so a DataStore hiccup can't overwrite real progress.
--   * Saves are batched: every minute, when a player leaves, and on shutdown.
--   * Studio uses its own data store, so tests never touch live player data.
-- If DataStores aren't available at all (e.g. an unpublished place in Studio),
-- everyone plays on a session-only profile and the HUD says progress isn't saved.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ProfileSchema = require(script.Parent.ProfileSchema)

local STORE_NAME = if RunService:IsStudio() then "PlayerData_Studio" else "PlayerData"
local AUTOSAVE_INTERVAL = 60
local LOCK_EXPIRY = 180 -- seconds; a lock older than this belongs to a server that crashed
local LOAD_ATTEMPTS = 5
local SAVE_ATTEMPTS = 3
local RETRY_DELAY = 3
local SHUTDOWN_TIMEOUT = 25

type Profile = ProfileSchema.Profile
export type Status = "Saved" | "SessionOnly" | "LoadFailed"
type Session = {
	Profile: Profile,
	Status: Status,
	Key: string,
	Coins: IntValue,
	Survived: IntValue,
}

local DataManager = {}

local sessionId = HttpService:GenerateGUID(false)
local store: DataStore? = nil
local sessions: { [Player]: Session } = {}
local loadedCallbacks: { (Player) -> () } = {}
local savesInFlight = 0

-- Errors that mean "this place can't use DataStores at all", not a passing hiccup.
local function isAccessError(err: any): boolean
	local message = string.lower(tostring(err))
	return string.find(message, "publish") ~= nil
		or string.find(message, "api access") ~= nil
		or string.find(message, "studioaccess") ~= nil
		or string.find(message, "403") ~= nil
end

-- Copies the profile to what the client can see.
local function mirror(player: Player, session: Session)
	local profile = session.Profile
	session.Coins.Value = profile.Coins
	session.Survived.Value = profile.Stats.RunsSurvived
	local owned = {}
	for id in profile.Owned do
		table.insert(owned, id)
	end
	table.sort(owned)
	player:SetAttribute("OwnedCosmetics", table.concat(owned, ","))
	for _, slot in Cosmetics.Slots do
		player:SetAttribute(`Equipped{slot}`, profile.Equipped[slot])
	end
	player:SetAttribute("StatRoomsCompleted", profile.Stats.RoomsCompleted)
	player:SetAttribute("StatRunsPlayed", profile.Stats.RunsPlayed)
	player:SetAttribute("StatRunsSurvived", profile.Stats.RunsSurvived)
	player:SetAttribute("DataStatus", session.Status)
end

-- Loads a profile and takes the session lock, retrying while another server
-- still holds it. Returns nil if the player left before it finished.
local function load(player: Player, key: string): (Profile?, Status)
	for _ = 1, LOAD_ATTEMPTS do
		local activeStore = store
		if not activeStore then
			return ProfileSchema.Default(), "SessionOnly"
		end
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return activeStore:UpdateAsync(key, function(record: any)
				lockedElsewhere = false
				record = if typeof(record) == "table" then record else { Profile = ProfileSchema.Default() }
				local lock = record.Lock
				if
					typeof(lock) == "table"
					and lock.Session ~= sessionId
					and os.time() - (tonumber(lock.Time) or 0) < LOCK_EXPIRY
				then
					lockedElsewhere = true
					return nil -- another server is still using this player's data
				end
				record.Version = ProfileSchema.Version
				record.Lock = { Session = sessionId, Time = os.time() }
				return record
			end)
		end)
		if ok and result and not lockedElsewhere then
			return ProfileSchema.Reconcile(result.Profile), "Saved"
		elseif not ok and isAccessError(result) then
			warn(`[DataManager] DataStores unavailable, progress won't be saved: {result}`)
			store = nil
			return ProfileSchema.Default(), "SessionOnly"
		elseif not ok then
			warn(`[DataManager] Load failed for {player.Name}: {result}`)
		end
		if player.Parent ~= Players then
			return nil, "LoadFailed"
		end
		task.wait(RETRY_DELAY)
	end
	return ProfileSchema.Default(), "LoadFailed"
end

-- Writes the profile, but only while this server still holds the lock.
local function save(session: Session, release: boolean): boolean
	local activeStore = store
	if session.Status ~= "Saved" or not activeStore then
		return true -- nothing to save: session-only or failed-load profile
	end
	local ok, err = pcall(function()
		activeStore:UpdateAsync(session.Key, function(record: any)
			if typeof(record) ~= "table" or typeof(record.Lock) ~= "table" or record.Lock.Session ~= sessionId then
				return nil -- we lost the lock; never overwrite another server's data
			end
			record.Version = ProfileSchema.Version
			record.Profile = session.Profile
			record.Lock = if release then nil else { Session = sessionId, Time = os.time() }
			return record
		end)
	end)
	if not ok then
		warn(`[DataManager] Save failed for {session.Key}: {err}`)
	end
	return ok
end

local function saveWithRetries(session: Session, release: boolean)
	savesInFlight += 1
	for attempt = 1, SAVE_ATTEMPTS do
		if save(session, release) then
			break
		end
		if attempt < SAVE_ATTEMPTS then
			task.wait(RETRY_DELAY)
		end
	end
	savesInFlight -= 1
end

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	local survived = Instance.new("IntValue")
	survived.Name = "Survived"
	survived.Parent = leaderstats
	leaderstats.Parent = player
	player:SetAttribute("DataStatus", "Loading")

	local key = `Player_{player.UserId}`
	local profile, status = load(player, key)
	local session: Session = {
		Profile = profile or ProfileSchema.Default(),
		Status = status,
		Key = key,
		Coins = coins,
		Survived = survived,
	}
	if player.Parent ~= Players then
		-- Left while loading: hand the lock straight back for their next server.
		task.spawn(saveWithRetries, session, true)
		return
	end
	sessions[player] = session
	mirror(player, session)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player)
	end
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if session then
		sessions[player] = nil
		saveWithRetries(session, true)
	end
end

function DataManager.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`[DataManager] DataStores unavailable, progress won't be saved: {result}`)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		for player, session in sessions do
			sessions[player] = nil
			task.spawn(saveWithRetries, session, true)
		end
		local deadline = os.clock() + SHUTDOWN_TIMEOUT
		while savesInFlight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	-- Autosave also refreshes each lock, so a long session never looks abandoned.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, session in sessions do
				task.spawn(save, session, false)
			end
		end
	end)
end

-- Runs `callback(player)` once each player's profile has loaded.
function DataManager.OnLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
	for player in sessions do
		task.spawn(callback, player)
	end
end

-- The player's profile, or nil while it's still loading. Treat it as read-only
-- and change it through the functions below, which keep the client copy in sync.
function DataManager.Get(player: Player): Profile?
	local session = sessions[player]
	return if session then session.Profile else nil
end

local function change(player: Player, apply: (Profile) -> boolean): boolean
	local session = sessions[player]
	if not session or not apply(session.Profile) then
		return false
	end
	mirror(player, session)
	return true
end

function DataManager.AddCoins(player: Player, amount: number): boolean
	return change(player, function(profile)
		profile.Coins += amount
		return true
	end)
end

-- Takes `amount` coins only if the player has that many.
function DataManager.TrySpend(player: Player, amount: number): boolean
	return change(player, function(profile)
		if profile.Coins < amount then
			return false
		end
		profile.Coins -= amount
		return true
	end)
end

function DataManager.AddStat(player: Player, stat: "RoomsCompleted" | "RunsPlayed" | "RunsSurvived")
	change(player, function(profile)
		profile.Stats[stat] += 1
		return true
	end)
end

function DataManager.GiveCosmetic(player: Player, itemId: string)
	change(player, function(profile)
		profile.Owned[itemId] = true
		return true
	end)
end

-- Equips `itemId` in `slot`, or empties the slot when `itemId` is nil.
function DataManager.Equip(player: Player, slot: string, itemId: string?)
	change(player, function(profile)
		if itemId then
			profile.Equipped[slot] = itemId
		else
			profile.Equipped[slot] = nil
		end
		return true
	end)
end

return DataManager
