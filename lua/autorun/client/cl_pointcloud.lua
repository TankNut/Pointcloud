pointcloud = {
	Enabled = CreateClientConVar("pointcloud_enabled", "1"),
	Resolution = CreateClientConVar("pointcloud_resolution", "32", true, false, "The amount of source units contained per point", 32, 128), -- Units per point
	Scale = CreateClientConVar("pointcloud_scale", "0.01", true, false, "How big to render pointclouds with respect to the actual world", 0.001, 0.1),

	MapWidth = CreateClientConVar("pointcloud_minimap_width", "300", true, false, "How wide the minimap display should be", 0),
	MapHeight = CreateClientConVar("pointcloud_minimap_height", "300", true, false, "How tall the minimap display should be", 0),
	MapZoom = CreateClientConVar("pointcloud_minimap_zoom", "1", true, false, "How far to zoom in on the minimap"),
	MapSlices = CreateClientConVar("pointcloud_minimap_slices", "0", true, false, "Whether or not the minimap should perform vertical slicing"),

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
	local slices = self.MapSlices:GetBool()

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
		if slices then
			local rendertarget = self.RenderTargets[slice]

			if not rendertarget then
				rendertarget = GetRenderTarget("pointcloud" .. slice, 1024, 1024, true)

				self.RenderTargets[slice] = rendertarget

				render.PushRenderTarget(rendertarget)
					render.Clear(0, 0, 0, 0, true, true)
				render.PopRenderTarget()
			end
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
	local scale = pointcloud.Scale:GetFloat()
	local slices = pointcloud.MapSlices:GetBool()

	if #pointcloud.PointList > 0 then
		local mins, maxs = game.GetWorld():GetModelBounds()
		local bounds = math.ceil(math.max(-mins.x, -mins.y, maxs.x, maxs.y) * scale) + 10

		local data = {
			drawviewer = true,
			origin = Vector(0, 0, 0),
			angles = Angle(90, 0, 0),
			znear = -1000,
			zfar = 1000,
			ortho = {
				left = -bounds,
				right = bounds,
				bottom = bounds,
				top = -bounds
			}
		}

		cam.Start(data)
			local boxsize = resolution * scale * 0.5

			local boxmin = Vector(-boxsize, -boxsize, -boxsize)
			local boxmax = Vector(boxsize, boxsize, boxsize)

			local baseslice = math.Round(lpos.z * (1 / resolution))

			render.SetColorMaterial()

			render.OverrideDepthEnable(true, true)
			render.OverrideAlphaWriteEnable(true, true)

			if slices then
				local i = 0

				repeat
					if pointcloud.Index == #pointcloud.PointList then
						break
					end

					pointcloud.Index = pointcloud.Index + 1

					local vec = pointcloud.PointList[pointcloud.Index][1]
					local col = pointcloud.PointList[pointcloud.Index][2]:ToColor()

					local slice = vec.z * (1 / resolution)

					local rendertarget = pointcloud.RenderTargets[slice]

					render.PushRenderTarget(rendertarget)
						render.DrawBox(vec * scale, Angle(), boxmin, boxmax, col)
					render.PopRenderTarget()

					i = i + 1
				until i == 2048
			else
				render.PushRenderTarget(pointcloud.RenderTarget)
					local i = 0

					repeat
						if pointcloud.Index == #pointcloud.PointList then
							break
						end

						pointcloud.Index = pointcloud.Index + 1

						local vec = pointcloud.PointList[pointcloud.Index][1]
						local col = pointcloud.PointList[pointcloud.Index][2]:ToColor()

						render.DrawBox(vec * scale, Angle(), boxmin, boxmax, col)

						i = i + 1
					until i == 2048
				render.PopRenderTarget()

				pointcloud.Material:SetTexture("$basetexture", pointcloud.RenderTarget)
			end

			render.OverrideDepthEnable(false)
			render.OverrideAlphaWriteEnable(false)

			local width = pointcloud.MapWidth:GetInt()
			local height = pointcloud.MapHeight:GetInt()
			local zoom = pointcloud.MapZoom:GetFloat()

			local pos = lpos * scale
			local default = 1024

			pos.x = math.Remap(pos.x, -bounds, bounds, -default * 0.5, default * 0.5)
			pos.y = math.Remap(pos.y, -bounds, bounds, -default * 0.5, default * 0.5)

			-- See: https://wiki.facepunch.com/gmod/surface.DrawTexturedRectUV
			local adjustment = 0.5 / 16

			pos.x = (pos.x - adjustment) / (1 - 2 * adjustment)
			pos.y = (pos.y - adjustment) / (1 - 2 * adjustment)

			local size = default * zoom

			local x = (width * 0.5) - (size * 0.5)
			local y = (height * 0.5) - (size * 0.5)

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

				if slices then
					for k, v in SortedPairs(pointcloud.RenderTargets) do
						if k > baseslice then
							continue
						end

						pointcloud.Material:SetTexture("$basetexture", v)

						surface.SetDrawColor(255, 255, 255)
						surface.SetMaterial(pointcloud.Material)
						surface.DrawTexturedRect(x + (pos.y * zoom), y + (pos.x * zoom), size, size)
					end
				else
					surface.SetDrawColor(255, 255, 255)
					surface.SetMaterial(pointcloud.Material)
					surface.DrawTexturedRect(x + (pos.y * zoom), y + (pos.x * zoom), size, size)
				end

				render.SetStencilEnable(false)

				surface.SetDrawColor(255, 0, 0)
				surface.DrawRect((width * 0.5) - 2, (height * 0.5) - 2, 4, 4)
			cam.End2D()
		cam.End()
	end
end)