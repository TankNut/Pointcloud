pointcloud = {
	Enabled = CreateClientConVar("pointcloud_enabled", "1"),
	Resolution = CreateClientConVar("pointcloud_resolution", "32", true, false, "The amount of source units contained per point", 32, 128), -- Units per point
	Scale = CreateClientConVar("pointcloud_scale", "0.01", true, false, "How big to render pointclouds with respect to the actual world", 0.001, 0.1),

	MapWidth = CreateClientConVar("pointcloud_minimap_width", "300", true, false, "How wide the minimap display should be", 0),
	MapHeight = CreateClientConVar("pointcloud_minimap_height", "300", true, false, "How tall the minimap display should be", 0),
	MapZoom = CreateClientConVar("pointcloud_minimap_zoom", "1", true, false, "How far to zoom in on the minimap"),

	-- Internals
	Index = pointcloud and pointcloud.Index or 0,
	Points = pointcloud and pointcloud.Points or {},
	PointList = pointcloud and pointcloud.PointList or {},
	RenderTargets = pointcloud and pointcloud.RenderTargets or {},

	RenderTarget = GetRenderTarget("pointcloud", 1024, 1024, true),
	Material = CreateMaterial("pointcloud", "unlitgeneric", {
		["$basetexture"] = "color/white",
		["$vertexcolor"] = 1,
		["$vertexalpha"] = 1,
		["$translucent"] = 1,
		["$ignorez"] = 1
	})
}

function pointcloud:Clear()
	self.Points = {}
	self.PointList = {}

	for _, v in pairs(self.RenderTargets) do
		render.PushRenderTarget(v)
			render.Clear(0, 0, 0, 0, true, true)
		render.PopRenderTarget()
	end

	self.RenderTargets = {}

	render.PushRenderTarget(self.RenderTarget)
		render.Clear(0, 0, 0, 0, true, true)
	render.PopRenderTarget()

	self.Index = 0
end

local length = Vector(1, 1, 1):Length()

function pointcloud:AddPoint(pos, col, sky)
	local resolution = self.Resolution:GetInt()

	pos = pos * (1 / resolution)

	pos.x = math.Round(pos.x)
	pos.y = math.Round(pos.y)
	pos.z = math.Round(pos.z)

	local slice = pos.z

	pos:Mul(resolution)

	if self.Points[tostring(pos)] then
		return false
	end

	self.Points[tostring(pos)] = true

	if not sky and col:Length() <= length then
		local rendertarget = self.RenderTargets[slice]

		if not rendertarget then
			rendertarget = GetRenderTarget("pointcloud" .. slice, 1024, 1024, true)

			self.RenderTargets[slice] = rendertarget

			render.PushRenderTarget(rendertarget)
				render.Clear(0, 0, 0, 0, true, true)
			render.PopRenderTarget()
		end

		self.PointList[#self.PointList + 1] = {pos, col}
	end

	return true
end

local function clear()
	pointcloud:Clear()
end

cvars.AddChangeCallback("pointcloud_minimap_slices", clear, "pointcloud")
cvars.AddChangeCallback("pointcloud_resolution", clear, "pointcloud")

hook.Add("Think", "pointcloud", function()
	if not pointcloud.Enabled:GetBool() then
		return
	end

	local lpos = LocalPlayer():EyePos()

	for i = -90, 90 do
		local ang = Angle(i, FrameNumber() * 100.2, 0)
		local target = lpos + (ang:Forward() * 20000)

		local tr = util.TraceLine({
			start = lpos,
			endpos = target,
			mask = MASK_SOLID_BRUSHONLY
		})

		if tr.StartSolid or tr.Fraction == 1 then
			continue
		end

		pointcloud:AddPoint(tr.HitPos, render.GetSurfaceColor(tr.HitPos + tr.HitNormal * 1, tr.HitPos - tr.HitNormal * 1), tr.HitSky or tr.HitNoDraw)
	end
end)

hook.Add("PreDrawHUD", "pointcloud", function()
	local lpos = LocalPlayer():EyePos()

	if not pointcloud.Enabled:GetBool() then
		return
	end

	local resolution = pointcloud.Resolution:GetFloat()

	if #pointcloud.PointList > 0 then
		local baseslice = math.Round(lpos.z * (1 / resolution))

		local i = 0

		repeat
			if pointcloud.Index == #pointcloud.PointList then
				break
			end

			pointcloud.Index = pointcloud.Index + 1

			local vec = pointcloud.PointList[pointcloud.Index][1] * (1 / resolution)
			local col = pointcloud.PointList[pointcloud.Index][2]:ToColor()

			local rendertarget = pointcloud.RenderTargets[vec.z]

			render.PushRenderTarget(rendertarget)
				cam.Start2D()
					surface.SetDrawColor(col)
					surface.DrawRect(-vec.y + 512, -vec.x + 512, 1, 1)
				cam.End2D()
			render.PopRenderTarget()

			i = i + 1
		until i == 2048

		local width = pointcloud.MapWidth:GetInt()
		local height = pointcloud.MapHeight:GetInt()
		local zoom = pointcloud.MapZoom:GetFloat()

		local pos = lpos * (1 / resolution)
		local size = 1024 * zoom

		-- See: https://wiki.facepunch.com/gmod/surface.DrawTexturedRectUV
		local adjustment = 0.5 / 16

		pos.x = (pos.x - adjustment) / (1 - 2 * adjustment)
		pos.y = (pos.y - adjustment) / (1 - 2 * adjustment)

		pos:Mul(zoom)

		cam.Start2D()
			surface.SetDrawColor(30, 30, 30)
			surface.DrawRect(0, 0, width, height)

			render.SetStencilWriteMask(0xFF)
			render.SetStencilTestMask(0xFF)
			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetStencilPassOperation(STENCIL_KEEP)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_KEEP)

			render.SetStencilEnable(true)

			render.ClearStencil()

			render.SetStencilReferenceValue(1)

			render.ClearStencilBufferRectangle(0, 0, width, height, 1)

			render.SetStencilCompareFunction(STENCIL_EQUAL)

			for k, v in SortedPairs(pointcloud.RenderTargets) do
				if k > baseslice then
					continue
				end

				pointcloud.Material:SetTexture("$basetexture", v)

				surface.SetDrawColor(255, 255, 255)
				surface.SetMaterial(pointcloud.Material)
				surface.DrawTexturedRect((width * 0.5) - (size * 0.5) + pos.y - 2, (height * 0.5) - (size * 0.5) + pos.x - 2, size, size)
			end

			render.SetStencilEnable(false)

			surface.SetDrawColor(255, 0, 0)
			surface.DrawRect((width * 0.5) - 2, (height * 0.5) - 2, 4, 4)
		cam.End2D()
	end
end)