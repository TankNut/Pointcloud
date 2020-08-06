pointcloud.Sampler = pointcloud.Sampler or {}

pointcloud.Sampler.Mode = CreateClientConVar("pointcloud_samplemode", "1", true, false)
pointcloud.Sampler.Rate = CreateClientConVar("pointcloud_samplerate", "90", true, false)

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
	end

	pointcloud.Debug.SampleTime = SysTime() - start
end

local length = Vector(1, 1, 1):Length()

function pointcloud.Sampler:Trace(pos, ang)
	local tr = util.TraceLine({
		start = pos,
		endpos = pos + (ang:Forward() * 10000),
		mask = MASK_SOLID_BRUSHONLY
	})

	if tr.StartSolid or tr.Fraction == 1 or tr.HitSky or tr.HitNoDraw then
		return
	end

	self:AddPoint(tr.HitPos, tr.HitNormal)
end

function pointcloud.Sampler:AddPoint(vec, normal)
	local resolution = pointcloud:GetResolution()
	local pos = vec * (1 / resolution)

	pos.x = math.Round(pos.x)
	pos.y = math.Round(pos.y)
	pos.z = math.Round(pos.z)

	local slice = pos.z

	pos:Mul(resolution)

	if pointcloud.Points[tostring(pos)] then
		return
	end

	pointcloud.Points[tostring(pos)] = true

	local col = render.GetSurfaceColor(vec + normal * 1, vec - normal * 1)

	if col:Length() > length then
		return
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

	if #pointcloud.PointList - pointcloud.SaveOffset >= 1000 then
		pointcloud.Persistence:Save()
	else
		timer.Create("pointcloud", 10, 1, function()
			pointcloud.Persistence:Save()
		end)
	end

	return
end