local sprite = Material("sprites/gmdm_pickups/light")

POINTCLOUD_MODE_CUBE 	= 1
POINTCLOUD_MODE_POINTS 	= 2

pointcloud = {
	Enabled = CreateClientConVar("pointcloud_enabled", "1", true, false),
	Resolution = CreateClientConVar("pointcloud_resolution", "32", true, false, "The amount of source units contained per point", 32, 128), -- Units per point

	Minimap = {
		Enabled = CreateClientConVar("pointcloud_minimap_enabled", "1", true, false),
		Width = CreateClientConVar("pointcloud_minimap_width", "300", true, false, "How wide the minimap display should be", 0),
		Height = CreateClientConVar("pointcloud_minimap_height", "300", true, false, "How tall the minimap display should be", 0),
		Zoom = CreateClientConVar("pointcloud_minimap_zoom", "1", true, false, "How far to zoom in on the minimap"),
		DrawIndex = pointcloud and pointcloud.Minimap.DrawIndex or 0,
		RenderTargets = pointcloud and pointcloud.Minimap.RenderTargets or {},
	},

	Projection = {
		Key = CreateClientConVar("pointcloud_projection_key", KEY_J, true, true),
		Scale = CreateClientConVar("pointcloud_projection_scale", "0.01", true, false, "How big to render projections with respect to the actual world", 0.001, 0.1),
		Height = CreateClientConVar("pointcloud_projection_height", "32", true, false, "Height offset of a projection compared to the player"),
		Mode = CreateClientConVar("pointcloud_projection_mode", "1", true, false, "The rendering method used for projections", 1, 2),
		Position = pointcloud and pointcloud.Projection.Position or nil,
		Stored = pointcloud and pointcloud.Projection.Stored or nil,
		DrawIndex = pointcloud and pointcloud.Projection.DrawIndex or 0,
		RenderTarget = GetRenderTarget("pointcloud", 1920, 1080, true)
	},

	Points = pointcloud and pointcloud.Points or {},
	PointList = pointcloud and pointcloud.PointList or {},

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

	-- 2D map
	local minimap = self.Minimap

	for _, v in pairs(minimap.RenderTargets) do
		render.PushRenderTarget(v)
			render.Clear(0, 0, 0, 0, true, true)
		render.PopRenderTarget()
	end

	minimap.RenderTargets = {}
	minimap.DrawIndex = 0

	-- 3D map
	local projection = self.Projection

	render.PushRenderTarget(projection.RenderTarget)
		render.Clear(0, 0, 0, 0, true, true)
	render.PopRenderTarget()

	projection.DrawIndex = 0
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
		local minimap = self.Minimap

		if minimap.Enabled:GetBool() then
			local rendertarget = minimap.RenderTargets[slice]

			if not rendertarget then
				rendertarget = GetRenderTarget("pointcloud" .. slice, 1024, 1024, true)

				minimap.RenderTargets[slice] = rendertarget

				render.PushRenderTarget(rendertarget)
					render.Clear(0, 0, 0, 0, true, true)
				render.PopRenderTarget()
			end
		end

		self.PointList[#self.PointList + 1] = {pos, col}
	end

	return true
end

function pointcloud:ToggleProjection()
	local projection = pointcloud.Projection

	local pos = projection.Position

	if pos then
		projection.Position = nil
	else
		local lp = LocalPlayer()
		local vec = lp:GetEyeTrace().HitPos

		vec.z = lp:GetPos().z + projection.Height:GetInt()

		projection.Position = vec
	end

	projection.Stored = nil
end

local function clearall()
	pointcloud:Clear()
end

local function clearprojection()
	local projection = pointcloud.Projection

	render.PushRenderTarget(projection.RenderTarget)
		render.Clear(0, 0, 0, 0, true, true)
	render.PopRenderTarget()

	projection.DrawIndex = 0
end

cvars.AddChangeCallback("pointcloud_resolution", clearall, "pointcloud")
cvars.AddChangeCallback("pointcloud_projection_mode", clearprojection, "pointcloud")
cvars.AddChangeCallback("pointcloud_projection_scale", clearprojection, "pointcloud")

if game.SinglePlayer() then
	net.Receive("nPointcloudKey", function()
		pointcloud:ToggleProjection()
	end)
else
	hook.Add("PlayerButtonDown", "pointcloud", function(ply, key)
		if not IsFirstTimePredicted() or ply != LocalPlayer() then
			return
		end

		local projection = pointcloud.Projection

		if key == projection.Key:GetInt() then
			pointcloud:ToggleProjection()
		end
	end)
end

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

function pointcloud:DrawMinimap()
	local minimap = self.Minimap

	local lpos = LocalPlayer():EyePos()
	local resolution = self.Resolution:GetInt()

	local baseslice = math.Round(lpos.z * (1 / resolution))
	local i = 0

	repeat
		if minimap.DrawIndex >= #self.PointList then
			break
		end

		minimap.DrawIndex = minimap.DrawIndex + 1

		local vec = self.PointList[minimap.DrawIndex][1] * (1 / resolution)
		local col = self.PointList[minimap.DrawIndex][2]:ToColor()

		local rendertarget = minimap.RenderTargets[vec.z]

		render.PushRenderTarget(rendertarget)
			cam.Start2D()
				surface.SetDrawColor(col)
				surface.DrawRect(-vec.y + 512, -vec.x + 512, 1, 1)
			cam.End2D()
		render.PopRenderTarget()

		i = i + 1
	until i >= 2048

	local width = minimap.Width:GetInt()
	local height = minimap.Height:GetInt()
	local zoom = minimap.Zoom:GetFloat()

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

		for k, v in SortedPairs(minimap.RenderTargets) do
			if k > baseslice then
				continue
			end

			self.Material:SetTexture("$basetexture", v)

			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(self.Material)
			surface.DrawTexturedRect((width * 0.5) - (size * 0.5) + pos.y - 2, (height * 0.5) - (size * 0.5) + pos.x - 2, size, size)
		end

		render.SetStencilEnable(false)

		surface.SetDrawColor(255, 0, 0)
		surface.DrawRect((width * 0.5) - 2, (height * 0.5) - 2, 4, 4)
	cam.End2D()
end

function pointcloud:DrawProjection()
	local projection = self.Projection

	local resolution = self.Resolution:GetInt()
	local scale = projection.Scale:GetFloat()

	local lp = LocalPlayer()

	local lpos = lp:EyePos()
	local lang = lp:EyeAngles()
	local lfov = lp:GetFOV()

	local clear = not projection.Stored or (projection.Stored.Pos != lpos) or (projection.Stored.Ang != lang) or (projection.Stored.FOV != lfov)

	if not projection.Stored then
		projection.Stored = {
			Pos = lpos,
			Ang = lang,
			FOV = lfov
		}
	end

	if clear then
		render.PushRenderTarget(projection.RenderTarget)
			render.Clear(0, 0, 0, 0, true, true)
		render.PopRenderTarget()

		projection.DrawIndex = 0
	end

	local mode = projection.Mode:GetInt()

	cam.Start3D()
		local size = resolution * scale * 0.5

		local mins = Vector(-size, -size, -size)
		local maxs = -mins

		if mode == POINTCLOUD_MODE_CUBE then
			render.SetColorMaterial()

			render.OverrideDepthEnable(true, true)
			render.OverrideAlphaWriteEnable(true, true)
		else
			render.SetMaterial(sprite)
		end

		local i = 0

		render.PushRenderTarget(projection.RenderTarget)
			repeat
				if projection.DrawIndex >= #self.PointList then
					break
				end

				projection.DrawIndex = projection.DrawIndex + 1

				local vec = self.PointList[projection.DrawIndex][1]
				local col = self.PointList[projection.DrawIndex][2]:ToColor()

				if mode == POINTCLOUD_MODE_CUBE then
					render.DrawBox(projection.Position + (vec * scale), angle_zero, mins, maxs, col)
				else
					local hue, sat = ColorToHSV(col)

					col = HSVToColor(hue, sat, 1)

					render.DrawSprite(projection.Position + (vec * scale), size * 2, size * 2, col)
				end

				i = i + 1
			until i >= 2048
		render.PopRenderTarget()

		if mode == POINTCLOUD_MODE_CUBE then
			render.OverrideDepthEnable(false)
			render.OverrideAlphaWriteEnable(false)
		end
	cam.End3D()

	self.Material:SetTexture("$basetexture", projection.RenderTarget)

	cam.Start2D()
		if mode == POINTCLOUD_MODE_POINTS then
			render.OverrideBlend(true, BLEND_SRC_COLOR, BLEND_ONE, BLENDFUNC_ADD, BLEND_SRC_ALPHA, BLEND_DST_ALPHA, BLENDFUNC_SUBTRACT)
		end
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(self.Material)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())

		if mode == POINTCLOUD_MODE_POINTS then
			render.OverrideBlend(false)
		end
	cam.End2D()

	projection.Stored = {
		Pos = lpos,
		Ang = lang,
		FOV = lfov
	}
end

hook.Add("PreDrawViewModels", "pointcloud", function()
	if not pointcloud.Enabled:GetBool() then
		return
	end

	if pointcloud.Projection.Position then
		pointcloud:DrawProjection()
	end
end)

hook.Add("PreDrawHUD", "pointcloud", function()
	if not pointcloud.Enabled:GetBool() then
		return
	end

	if pointcloud.Minimap.Enabled:GetBool() then
		pointcloud:DrawMinimap()
	end
end)