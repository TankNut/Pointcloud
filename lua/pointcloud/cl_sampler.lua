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
				end
			end

			local vec = pointcloud.Data:FromData(Vector(self.x, self.y, 0))

			vec.x = vec.x + math.Rand(-res * 0.5, res * 0.5)
			vec.y = vec.y + math.Rand(-res * 0.5, res * 0.5)
			vec.z = self.z

			self:Trace(vec, Angle(90, 0, 0))
		end

		if finished then
			self.Mode:SetInt(POINTCLOUD_SAMPLE_NONE)
		end
	end

	pointcloud.Debug.SamplerTime = SysTime() - start
end

function pointcloud.Sampler:Clear()
	self.Queue = queue()

	self.x = nil
	self.y = nil
end

function pointcloud.Sampler:RunAutoMapper()
	if self.Queue:Count() == 0 then
		self.Queue:Push(LocalPlayer():EyePos())
	end

	while pointcloud.Performance:HasBudget("Sampler") do
		local vec = self.Queue:Pop()

		if not vec then
			return
		end

		for j = 1, 10 do
			if not pointcloud.Performance:HasBudget("Sampler") then
				return
			end

			local ok, pos = self:Trace(vec, AngleRand())

			if ok then
				self.Queue:Push(pos)
			end
		end
	end
end

local length = Vector(1, 1, 1):Length()

function pointcloud.Sampler:Trace(pos, ang)
	local time = SysTime()
	local tr = util.TraceLine({
		start = pos,
		endpos = pos + (ang:Forward() * 32768),
		mask = MASK_SOLID_BRUSHONLY
	})

	if tr.Fraction == 1 then
		pointcloud.Performance:AddSample("Sampler", SysTime() - time)

		return false
	end

	local ok = self:AddPoint(tr.HitPos, tr.HitNormal, tr.HitSky or tr.HitNoDraw)

	pointcloud.Performance:AddSample("Sampler", SysTime() - time)

	return ok, tr.HitPos
end

function pointcloud.Sampler:AddPoint(vec, normal, sky)
	local check = pointcloud.Data:FromWorld(vec)

	if pointcloud.Data:Exists(check) then
		return false
	end

	if sky then
		pointcloud.Data:Mark(check)

		return true
	end

	local col = render.GetSurfaceColor(vec + normal * 1, vec - normal * 1)

	if col:Length() > length then -- GetSurfaceColor returns 255,255,255 if it fails to find a surface
		pointcloud.Data:Mark(check)

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

	pointcloud.Data:AddTracePoint(vec, col)

	return true
end