pointcloud.Sampler = pointcloud.Sampler or {}

pointcloud.Sampler.Mode = CreateClientConVar("pointcloud_samplemode", "1", true, false)
pointcloud.Sampler.Rate = CreateClientConVar("pointcloud_samplerate", "90", true, false)

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
	local rate = self.Rate:GetInt() + 1

	if mode == POINTCLOUD_SAMPLE_NOISE then
		for i = 1, rate do
			self:Trace(lpos, AngleRand())
		end
	elseif mode == POINTCLOUD_SAMPLE_FRONTFACING then
		for i = 1, rate do
			local ang = AngleRand(-45, 45)

			self:Trace(lpos, lp:LocalToWorldAngles(ang))
		end
	elseif mode == POINTCLOUD_SAMPLE_AUTOMAP then
		self:RunAutoMapper(rate)
	end

	if mode != POINTCLOUD_SAMPLE_AUTOMAP and self.Queue:Count() > 0 then
		self:Clear()
	end

	pointcloud.Debug.SampleTime = SysTime() - start
end

function pointcloud.Sampler:Clear()
	self.Queue = queue()
end

function pointcloud.Sampler:RunAutoMapper(rate)
	if self.Queue:Count() == 0 then
		self.Queue:Push(LocalPlayer():EyePos())
	end

	rate = math.floor(rate / 10)

	for i = 1, rate do
		local vec = self.Queue:Pop()

		if not vec then
			return
		end

		for j = 1, 10 do
			local ok, pos = self:Trace(vec, AngleRand())

			if ok then
				debugoverlay.Line(vec, pos, 1, color_white, true)

				self.Queue:Push(pos)
			end
		end
	end
end

local length = Vector(1, 1, 1):Length()

function pointcloud.Sampler:Trace(pos, ang)
	local tr = util.TraceLine({
		start = pos,
		endpos = pos + (ang:Forward() * 10000),
		mask = MASK_SOLID_BRUSHONLY
	})

	if tr.StartSolid or tr.Fraction == 1 then
		return false
	end

	return self:AddPoint(tr.HitPos, tr.HitNormal, tr.HitSky or tr.HitNoDraw), tr.HitPos
end

function pointcloud.Sampler:AddPoint(vec, normal, sky)
	local resolution = pointcloud:GetResolution()
	local pos = vec * (1 / resolution)

	pos.x = math.Round(pos.x)
	pos.y = math.Round(pos.y)
	pos.z = math.Round(pos.z)

	local slice = pos.z

	pos:Mul(resolution)

	if pointcloud.Points[tostring(pos)] then
		return false
	end

	pointcloud.Points[tostring(pos)] = true

	if sky then
		return true
	end

	local col = render.GetSurfaceColor(vec + normal * 1, vec - normal * 1)

	if col:Length() > length then
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

	local minimap = pointcloud.Minimap

	local rendertarget = minimap.RenderTargets[slice]

	if not rendertarget then
		rendertarget = GetRenderTarget("pointcloud" .. slice, 1024, 1024, true)

		minimap.RenderTargets[slice] = rendertarget

		render.PushRenderTarget(rendertarget)
			render.Clear(0, 0, 0, 0, true, true)
		render.PopRenderTarget()
	end

	pointcloud.PointList[#pointcloud.PointList + 1] = {pos, col}

	if #pointcloud.PointList - pointcloud.Persistence.Offset >= 1000 then
		pointcloud.Persistence:Save()
	else
		timer.Create("pointcloud", 10, 1, function()
			pointcloud.Persistence:Save()
		end)
	end

	return true
end