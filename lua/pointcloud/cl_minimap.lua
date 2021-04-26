pointcloud.Minimap = pointcloud.Minimap or {}

pointcloud.Minimap.Enabled = CreateClientConVar("pointcloud_minimap_enabled", "1", true, false)
pointcloud.Minimap.Width = CreateClientConVar("pointcloud_minimap_width", "300", true, false)
pointcloud.Minimap.Height = CreateClientConVar("pointcloud_minimap_height", "300", true, false)
pointcloud.Minimap.Zoom = CreateClientConVar("pointcloud_minimap_zoom", "1", true, false)
pointcloud.Minimap.ZoomOut = CreateClientConVar("pointcloud_minimap_zoomout", KEY_NONE, true, true)
pointcloud.Minimap.ZoomIn = CreateClientConVar("pointcloud_minimap_zoomin", KEY_NONE, true, true)
pointcloud.Minimap.ZoomStep = CreateClientConVar("pointcloud_minimap_zoomstep", 0.5, true, false)
pointcloud.Minimap.LayerDepth = CreateClientConVar("pointcloud_minimap_layerdepth", -1, true, false)
pointcloud.Minimap.UseMask = CreateClientConVar("pointcloud_minimap_mask", "0", true, false)

pointcloud.Minimap.PointFilter = CreateClientConVar("pointcloud_minimap_pixelated", "1", true, false)
pointcloud.Minimap.MaskPointFilter = CreateClientConVar("pointcloud_minimap_mask_pixelated", "0", true, false)

pointcloud.Minimap.RenderTargets = pointcloud.Minimap.RenderTargets or {}
pointcloud.Minimap.RenderMask = GetRenderTarget("pointcloudmask", 1024, 1024, true)

pointcloud.Minimap.DrawIndex = pointcloud.Minimap.DrawIndex or 0

pointcloud.Input:AddHandler("minimap_zoomout", pointcloud.Minimap.ZoomOut, function()
	pointcloud.Minimap:HandleZoom(false)
end)

pointcloud.Input:AddHandler("minimap_zoomin", pointcloud.Minimap.ZoomIn, function()
	pointcloud.Minimap:HandleZoom(true)
end)

function pointcloud.Minimap:Clear()
	self.RenderTargets = {}
	self.DrawIndex = 0
end

function pointcloud.Minimap:HandleZoom(dir)
	local zoom = self.Zoom:GetFloat()
	local step = self.ZoomStep:GetFloat()

	if dir then
		zoom = math.min(zoom + step, POINTCLOUD_MAXZOOM)
	else
		zoom = math.max(zoom - step, POINTCLOUD_MINZOOM)
	end

	self.Zoom:SetFloat(zoom)
end

function pointcloud.Minimap:AddPoint(pos, col)
	local slice = pos.z
	local rendertarget = self.RenderTargets[slice]

	if not rendertarget then
		rendertarget = GetRenderTarget("pointcloud" .. slice, 1024, 1024, true)

		self.RenderTargets[slice] = rendertarget

		render.PushRenderTarget(rendertarget)
			render.Clear(0, 0, 0, 0, true, true)
		render.PopRenderTarget()
	end
end

function pointcloud.Minimap:Draw()
	local start = SysTime()

	local lpos = LocalPlayer():EyePos()
	local resolution = pointcloud:GetResolution()

	local baseslice = math.Round(lpos.z * (1 / resolution)) + 512
	local i = 0

	repeat
		if self.DrawIndex >= #pointcloud.Data.PointList then
			break
		end

		self.DrawIndex = self.DrawIndex + 1

		local vec = pointcloud.Data.PointList[self.DrawIndex][1]
		local col = pointcloud.Data.PointList[self.DrawIndex][2]:ToColor()

		local rendertarget = self.RenderTargets[vec.z]

		local x, y = math.Remap(vec.y, 0, 1024, 1024, 0), math.Remap(vec.x, 0, 1024, 1024, 0)

		render.PushRenderTarget(rendertarget)
			cam.Start2D()
				surface.SetDrawColor(col)
				surface.DrawRect(x, y, 1, 1)
			cam.End2D()
		render.PopRenderTarget()
	until i >= 2048

	local width = self.Width:GetInt()
	local height = self.Height:GetInt()
	local zoom = self.Zoom:GetFloat()

	local pos = lpos * (1 / resolution)
	local size = 1024 * zoom

	-- See: https://wiki.facepunch.com/gmod/surface.DrawTexturedRectUV
	local adjustment = 0.5 / 16 -- color/white's basetexture is 16x

	local u0, v0 = 0, 0
	local u1, v1 = 1, 1

	u0, v0 = (u0 - adjustment) / (1 - 2 * adjustment), (v0 - adjustment) / (1 - 2 * adjustment)
	u1, v1 = (u1 - adjustment) / (1 - 2 * adjustment), (v1 - adjustment) / (1 - 2 * adjustment)

	pos:Mul(zoom)

	cam.Start2D()
		surface.SetDrawColor(30, 30, 30)
		surface.DrawRect(0, 0, width, height)

		render.SetScissorRect(0, 0, width, height, true)

		local endpoint = self.LayerDepth:GetInt()

		if endpoint == -1 then
			endpoint = nil
		end

		local counter = 0

		local x = (width * 0.5) - (size * 0.5) + pos.y
		local y = (height * 0.5) - (size * 0.5) + pos.x

		if self.PointFilter:GetBool() then
			render.PushFilterMag(TEXFILTER.POINT)
			render.PushFilterMin(TEXFILTER.POINT)
		end

		for k, v in SortedPairs(self.RenderTargets) do
			if k > baseslice or (endpoint and k < baseslice - endpoint) then
				continue
			end

			counter = counter + 1

			pointcloud.Material:SetTexture("$basetexture", v)

			local col = 255

			if endpoint and endpoint > 0 then
				col = math.Remap(k, baseslice, baseslice - endpoint, 255, 0)
			end

			surface.SetDrawColor(col, col, col, col)
			surface.SetMaterial(pointcloud.Material)
			surface.DrawTexturedRectUV(x, y, size, size, u0, v0, u1, v1)
		end

		if self.PointFilter:GetBool() then
			render.PopFilterMin()
			render.PopFilterMag()
		end

		render.SetScissorRect(0, 0, 0, 0, false)

		if self.UseMask:GetBool() then
			self:UpdateMask()

			pointcloud.Material:SetTexture("$basetexture", self.RenderMask)

			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(pointcloud.Material)

			render.SetScissorRect(0, 0, width, height, true)

			if self.MaskPointFilter:GetBool() then
				render.PushFilterMag(TEXFILTER.POINT)
				render.PushFilterMin(TEXFILTER.POINT)
			end

			surface.DrawTexturedRectUV(x, y, size, size, u0, v0, u1, v1)

			if self.MaskPointFilter:GetBool() then
				render.PopFilterMin()
				render.PopFilterMag()
			end

			render.SetScissorRect(0, 0, 0, 0, false)
		end

		surface.SetDrawColor(255, 0, 0)
		surface.DrawRect((width * 0.5) - 2, (height * 0.5) - 2, 4, 4)
	cam.End2D()

	pointcloud.Debug.RenderTargets = counter
	pointcloud.Debug.MinimapTime = SysTime() - start
end

function pointcloud.Minimap:UpdateMask()
	render.PushRenderTarget(self.RenderMask)
		render.Clear(0, 0, 0, 0, true, true)

		local lpos = LocalPlayer():EyePos()
		local steps = 360

		local center = pointcloud.Data:FromWorld(lpos)

		local verts = {{
			x = math.Remap(center.y, 0, 1024, 1024, 0),
			y = math.Remap(center.x, 0, 1024, 1024, 0)
		}}

		for i = 1, steps do
			local offset = i * (360 / steps)

			local hit = util.TraceLine({
				start = lpos,
				endpos = lpos + (Angle(0, -offset, 0):Forward() * 32768),
				mask = MASK_SOLID_BRUSHONLY
			}).HitPos

			local pos = pointcloud.Data:FromWorld(hit)
			local x, y = math.Remap(pos.y, 0, 1024, 1024, 0), math.Remap(pos.x, 0, 1024, 1024, 0)

			verts[#verts + 1] = {x = x, y = y}
		end

		verts[#verts + 1] = verts[2]

		cam.Start2D()
			render.SetStencilEnable(true)

			render.SetStencilWriteMask(0xFF)
			render.SetStencilTestMask(0xFF)

			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetStencilReferenceValue(1)

			render.SetStencilPassOperation(STENCIL_REPLACE)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_KEEP)

			render.ClearStencil()

			surface.SetDrawColor(255, 255, 255)
			draw.NoTexture()
			surface.DrawPoly(verts)

			render.SetStencilPassOperation(STENCIL_KEEP)
			render.SetStencilCompareFunction(STENCIL_NOTEQUAL)

			render.Clear(0, 0, 0, 0, false, false)

			surface.SetDrawColor(30, 30, 30)

			surface.DrawRect(0, 0, 1024, 1024)

			render.SetStencilEnable(false)
		cam.End2D()
	render.PopRenderTarget()
end

function pointcloud.Minimap:AddInfoLine(str, ...)
	if str then
		draw.DrawText(string.format(str, ...), "BudgetLabel", 3, self.InfoLine * 12, color_white, TEXT_ALIGN_LEFT)
	end

	self.InfoLine = self.InfoLine + 1
end

local function format_number(num)
	local _, _, minus, int, fraction = string.find(tostring(num), "([-]?)(%d+)([.]?%d*)")

	int = string.gsub(string.reverse(int), "(%d%d%d)", "%1,")

	return minus .. string.gsub(string.reverse(int), "^,", "") .. fraction
end

function pointcloud.Minimap:DrawInfo()
	self.InfoLine = 0

	cam.Start2D()
		local debugdata = pointcloud.Debug

		if pointcloud.Persistence:IsLoading() then
			self:AddInfoLine("Loading map data... (%s)", string.NiceSize(debugdata.Filesize))
		end

		if debugdata.Enabled:GetBool() then
			local rendertargets = debugdata.RenderTargets

			if pointcloud.Projection.Position then
				rendertargets = rendertargets + 1
			end

			self:AddInfoLine("Map: %s", game.GetMap())
			self:AddInfoLine("Resolution: %sx", pointcloud.Resolution:GetInt())
			self:AddInfoLine()
			self:AddInfoLine("Points: %s", format_number(#pointcloud.Data.PointList))

			if pointcloud.Sampler.Queue:Count() > 0 then
				self:AddInfoLine("Automap queue: %s", format_number(pointcloud.Sampler.Queue:Count()))
			end

			self:AddInfoLine("File size: %s", string.NiceSize(debugdata.Filesize))
			self:AddInfoLine()
			self:AddInfoLine("Active rendertargets: %u", rendertargets)

			if pointcloud.Persistence:IsLoading() or pointcloud.Sampler.Mode:GetInt() == POINTCLOUD_SAMPLE_NONE then
				self:AddInfoLine("Samples: 0 (0ms)")
			else
				self:AddInfoLine("Samples: %u (%.2fms)", #pointcloud.Performance.Data.Sampler.Samples, debugdata.SamplerTime * 1000)
			end

			self:AddInfoLine("Minimap: %.2fms", debugdata.MinimapTime * 1000)

			if pointcloud.Projection.Position then
				self:AddInfoLine("Projection: %u (%.2fms)", #pointcloud.Performance.Data.Projection.Samples, debugdata.ProjectionTime * 1000)
			end
		end
	cam.End2D()
end