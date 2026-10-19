--!strict
-- Moves something along a fixed list of points at a constant speed. It's pure
-- math: the server and every client get the same answer for the same time, so
-- a chaser can be drawn smoothly on each client and checked fairly on the server.

export type Path = {
	Points: { Vector3 },
	Lengths: { number }, -- Lengths[i] = distance from Points[i] to Points[i + 1]
	Total: number,
}

local PathFollower = {}

-- Builds a path from parts named "1", "2", "3", ... inside `folder`.
function PathFollower.FromFolder(folder: Instance): Path
	local parts = folder:GetChildren()
	table.sort(parts, function(a, b)
		return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
	end)

	local points, lengths, total = {}, {}, 0
	for i, part in parts do
		points[i] = (part :: BasePart).Position
		if i > 1 then
			lengths[i - 1] = (points[i] - points[i - 1]).Magnitude
			total += lengths[i - 1]
		end
	end
	return { Points = points, Lengths = lengths, Total = total }
end

-- How far something has travelled after `elapsed` seconds if it starts at
-- `startSpeed` and speeds up by `acceleration` per second until `maxSpeed`.
function PathFollower.TravelDistance(elapsed: number, startSpeed: number, acceleration: number, maxSpeed: number): number
	if elapsed <= 0 then
		return 0
	end
	if acceleration <= 0 or maxSpeed <= startSpeed then
		return startSpeed * elapsed
	end
	local rampTime = (maxSpeed - startSpeed) / acceleration
	if elapsed <= rampTime then
		return startSpeed * elapsed + 0.5 * acceleration * elapsed * elapsed
	end
	return startSpeed * rampTime + 0.5 * acceleration * rampTime * rampTime + maxSpeed * (elapsed - rampTime)
end

-- Returns the position `distance` studs along the path and the direction of travel there.
function PathFollower.At(path: Path, distance: number): (Vector3, Vector3)
	local remaining = math.clamp(distance, 0, path.Total)
	for i, length in path.Lengths do
		local from, to = path.Points[i], path.Points[i + 1]
		if remaining <= length or i == #path.Lengths then
			local alpha = if length > 0 then math.min(remaining / length, 1) else 0
			return from:Lerp(to, alpha), (to - from).Unit
		end
		remaining -= length
	end
	return path.Points[1], Vector3.new(0, 0, -1)
end

return PathFollower
