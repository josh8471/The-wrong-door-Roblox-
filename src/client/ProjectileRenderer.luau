--!strict
-- Flies projectiles (parts tagged "Projectile", like Grandma's slippers) along
-- an arc on this client. The server only sets From/To/LaunchAt/Flight/ArcHeight
-- and judges hits at the landing spot itself; the arc is just for show.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SPIN = Vector2.new(14, 9) -- radians of tumble over a whole flight

local ProjectileRenderer = {}

local projectiles: { [BasePart]: boolean } = {}

local function track(instance: Instance)
	if instance:IsA("BasePart") then
		projectiles[instance] = true
	end
end

local function render()
	local now = workspace:GetServerTimeNow()
	for part in projectiles do
		local from, to = part:GetAttribute("From"), part:GetAttribute("To")
		local launchAt, flight = part:GetAttribute("LaunchAt"), part:GetAttribute("Flight")
		if
			typeof(from) ~= "Vector3"
			or typeof(to) ~= "Vector3"
			or typeof(launchAt) ~= "number"
			or typeof(flight) ~= "number"
		then
			continue
		end
		local alpha = math.clamp((now - launchAt) / flight, 0, 1)
		local lift = 4 * (part:GetAttribute("ArcHeight") or 0) * alpha * (1 - alpha)
		part.CFrame = CFrame.new(from:Lerp(to, alpha) + Vector3.new(0, lift, 0))
			* CFrame.Angles(SPIN.X * alpha, SPIN.Y * alpha, 0)
	end
end

function ProjectileRenderer.Start()
	CollectionService:GetInstanceAddedSignal("Projectile"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("Projectile"):Connect(function(instance)
		projectiles[instance :: BasePart] = nil
	end)
	for _, instance in CollectionService:GetTagged("Projectile") do
		track(instance)
	end
	RunService.RenderStepped:Connect(render)
end

return ProjectileRenderer
