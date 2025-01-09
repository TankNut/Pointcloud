pointcloud.Sampler = pointcloud.Sampler or {}

pointcloud.Sampler.Mode = CreateClientConVar("pointcloud_samplemode", "1", true, false)

local class = {}

function class:Push(item)
	local index = self.Last + 1

	self.Last = index
	self.Items[index] = item
end

function class:Pop()
	local index = self.First

	if index > self.Last then
		return -- Empty
	end

	local item = self.Items[index]

	self.Items[index] = nil
	self.First = index + 1

	return item
end

function class:Count()
	return self.Last - self.First + 1
end

local function queue()
	return setmetatable({
		First = 0,
		Last = -1,
		Items = {}
	}, {__index = class})
end

pointcloud.Sampler.Queue = pointcloud.Sampler.Queue or queue()
pointcloud.Sampler.Lookup = pointcloud.Sampler.Lookup or {}

local down = Angle(90, 0, 0)

function pointcloud.Sampler:Run()
	local start = SysTime()
	local lp = LocalPlayer()
	local lpos = lp:EyePos()
	local mode = self.Mode:GetInt()

	pointcloud.Performance:UpdateBudget("Sampler")

	if mode == POINTCLOUD_SAMPLE_NOISE then
		while pointcloud.Performance:HasBudget("Sampler") do
			self:Trace(lpos, AngleRand())
		end
	elseif mode == POINTCLOUD_SAMPLE_FRONTFACING then
		while pointcloud.Performance:HasBudget("Sampler") do
			local ang = AngleRand(-45, 45)

			self:Trace(lpos, lp:LocalToWorldAngles(ang))
		end
	elseif mode == POINTCLOUD_SAMPLE_AUTOMAP then
		self:RunAutoMapper()
	elseif mode == POINTCLOUD_SAMPLE_SWEEPING then
		local yaw = CurTime() * 360

		while pointcloud.Performance:HasBudget("Sampler") do
			local ang = Angle(math.Rand(-90, 90), math.Rand(yaw - 5, yaw + 5), 0)

			self:Trace(lpos, ang)
		end
	elseif mode == POINTCLOUD_SAMPLE_SATMAP and self.z then
		local mins, maxs = game.GetWorld():GetModelBounds()

		local min = pointcloud.Data:FromWorld(mins)
		local max = pointcloud.Data:FromWorld(maxs)

		local res = pointcloud:GetResolution()

		self.x = self.x or min.x
		self.y = self.y or min.y

		local finished = false

		while pointcloud.Performance:HasBudget("Sampler") and not finished do
			self.x = self.x + 1

			if self.x == max.x then
				self.x = min.x
				self.y = self.y + 1

				if self.y == max.y then
					finished = true
					break
				end
			end

			local vec = pointcloud.Data:FromData(Vector(self.x, self.y, 0))

			vec.x = vec.x + math.Rand(-res * 0.5, res * 0.5)
			vec.y = vec.y + math.Rand(-res * 0.5, res * 0.5)
			vec.z = self.z

			self:Trace(vec, down)
		end

		if finished then
			self.Mode:SetInt(POINTCLOUD_SAMPLE_NONE)
		end
	elseif mode == POINTCLOUD_SAMPLE_BSP then
		if not pointcloud.BSP.Leafs then
			pointcloud.BSP:Load()
		end

		local leafs = pointcloud.BSP.Leafs

		while pointcloud.Performance:HasBudget("Sampler") do
			local leaf = leafs[math.random(1, #leafs)]

			self:Trace(Vector(
				math.Rand(leaf.Mins.x, leaf.Maxs.x),
				math.Rand(leaf.Mins.y, leaf.Maxs.y),
				math.Rand(leaf.Mins.z, leaf.Maxs.z)
			), AngleRand())
		end
	end

	pointcloud.Debug.SamplerTime = SysTime() - start
end

function pointcloud.Sampler:Clear()
	self.Queue = queue()
	self.Lookup = {}

	self.x = nil
	self.y = nil
	self.z = nil
end

local function bitPack(vec)
	return bit.bor(bit.lshift(vec.x, 20), bit.lshift(vec.y, 10), vec.z)
end

local dirs = {
	Angle(0, 0, 0),
	Angle(0, 90, 0),
	Angle(0, 180, 0),
	Angle(0, 270, 0),
	Angle(90, 0, 0),
	Angle(-90, 0, 0)
}

function pointcloud.Sampler:RunAutoMapper()
	local res = pointcloud:GetResolution()

	while pointcloud.Performance:HasBudget("Sampler") do
		local data = self.Queue:Pop()

		if not data then
			data = {LocalPlayer():WorldSpaceCenter(), 0}
		end

		local vec = data[1]
		local depth = data[2]

		local points = {}
		local hit = false

		for i = 1, 6 do
			if not pointcloud.Performance:HasBudget("Sampler") then
				return
			end

			local ok, pos, tr = self:Trace(vec, dirs[i], res)
			local pack = bitPack(pointcloud.Data:FromWorld(pos))

			if ok and not tr.HitSky then
				hit = true
			end

			if not ok and not tr.StartSolid and not self.Lookup[pack] then
				points[#points + 1] = {pos, pack}
			end
		end

		if hit or depth < 1 then
			local newDepth = hit and 0 or depth + 1
			for i = 1, #points do
				local tab = points[i]

				self.Lookup[tab[2]] = true
				self.Queue:Push({tab[1], newDepth})
			end
		end
	end
end

local red = Color(255, 0, 0)
local green = Color(0, 255, 0)

local result = {}
local trace = {
	mask = MASK_SOLID_BRUSHONLY,
	output = result
}

function pointcloud.Sampler:Trace(pos, ang, dist)
	local time = SysTime()
	local forward = ang:Forward()

	dist = dist or 32768
	forward:Mul(dist)

	trace.start = pos
	trace.endpos = pos + forward

	util.TraceLine(trace)

	if result.StartSolid or result.Fraction == 1 then
		pointcloud.Performance:AddSample("Sampler", SysTime() - time)
		-- debugoverlay.Line(tr.StartPos, tr.HitPos, 1, red, true)

		return false, result.HitPos, result
	end

	local ok = self:AddPoint(result.HitPos, result.HitNormal, result.HitSky or result.HitNoDraw)

	-- debugoverlay.Line(tr.StartPos, tr.HitPos, 1, ok and green or red, true)

	pointcloud.Performance:AddSample("Sampler", SysTime() - time)

	return ok, result.HitPos + result.HitNormal, result
end

local length = Vector(1, 1, 1):Length()

function pointcloud.Sampler:AddPoint(vec, normal, sky)
	local pos = pointcloud.Data:FromWorld(vec)

	if pointcloud.Data:Exists(pos) then
		return false
	end

	if sky then
		pointcloud.Data:Mark(pos)

		return true
	end

	local col = render.GetSurfaceColor(vec + normal * 1, vec - normal * 1)

	if col:Length() > length then -- GetSurfaceColor returns 255,255,255 if it fails to find a surface
		pointcloud.Data:Mark(pos)

		return true
	end

	local contents = util.PointContents(vec)

	if tobool(bit.band(contents, CONTENTS_WATER)) then
		local h, s, v = ColorToHSV(col:ToColor())

		h = 202
		s = 0.5

		col = HSVToColor(h, s, v)
		col = Vector(col.r, col.g, col.b)
		col:Div(255)
	elseif tobool(bit.band(contents, CONTENTS_SLIME)) then
		local h, s, v = ColorToHSV(col:ToColor())

		h = 65
		s = 0.6

		col = HSVToColor(h, s, v)
		col = Vector(col.r, col.g, col.b)
		col:Div(255)
	end

	pointcloud.Data:AddPoint(pos, col)

	return true
end
