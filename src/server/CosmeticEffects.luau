--!strict
-- Shows equipped cosmetics on characters: a trail behind you and a title above
-- your head, put back every time you respawn, plus a burst of particles (your
-- victory effect) whenever you clear a room. Purely visual.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local DataManager = require(script.Parent.DataManager)

-- Built-in Roblox particle textures, so no uploaded assets are needed.
local PARTICLE_TEXTURES = {
	Sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}

local CosmeticEffects = {}

local function equippedItem(player: Player, slot: string): Cosmetics.Cosmetic?
	local profile = DataManager.Get(player)
	local itemId = if profile then profile.Equipped[slot] else nil
	return if itemId then Cosmetics.ById[itemId] else nil
end

-- Rebuilds the trail and title on the player's current character.
function CosmeticEffects.Apply(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not (root and head) then
		return
	end
	for _, holder in { root, head } do
		for _, child in holder:GetChildren() do
			if string.sub(child.Name, 1, 8) == "Cosmetic" then
				child:Destroy()
			end
		end
	end

	local trailItem = equippedItem(player, "Trail")
	if trailItem then
		local top = Instance.new("Attachment")
		top.Name = "CosmeticTrailTop"
		top.Position = Vector3.new(0, 0.8, 0)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "CosmeticTrailBottom"
		bottom.Position = Vector3.new(0, -0.8, 0)
		bottom.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "CosmeticTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = Cosmetics.ColorSequence(trailItem.Colors)
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.Lifetime = 0.5
		trail.LightEmission = 0.5
		trail.FaceCamera = true
		trail.Parent = root
	end

	local titleItem = equippedItem(player, "Title")
	if titleItem then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "CosmeticTitle"
		billboard.Size = UDim2.fromOffset(200, 28)
		billboard.StudsOffset = Vector3.new(0, 3.2, 0)
		billboard.MaxDistance = 60
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = titleItem.Text or titleItem.Name
		label.TextColor3 = titleItem.Colors[1]
		label.TextStrokeTransparency = 0
		label.Parent = billboard
		billboard.Parent = head
	end
end

-- Bursts the player's victory effect out of their character, if they have one.
function CosmeticEffects.PlayVictory(player: Player)
	local item = equippedItem(player, "Victory")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (item and root) then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "CosmeticVictory"
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = PARTICLE_TEXTURES[item.Particle or "Sparkles"]
	emitter.Color = Cosmetics.ColorSequence(item.Colors)
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(1, 1.6)
	emitter.Speed = NumberRange.new(14, 24)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -18, 0)
	emitter.Drag = 1.5
	emitter.Size = NumberSequence.new(0.6)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.LightEmission = 0.4
	emitter.Parent = attachment
	emitter:Emit(60)
	Debris:AddItem(attachment, 2.5)
end

function CosmeticEffects.Init()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Head", 10)
			CosmeticEffects.Apply(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- A character can spawn before its owner's data loads; dress it once it has.
	DataManager.OnLoaded(CosmeticEffects.Apply)
end

return CosmeticEffects
