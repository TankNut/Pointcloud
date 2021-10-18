pointcloud.Projection = pointcloud.Projection or {}

pointcloud.Projection.Key = CreateClientConVar("pointcloud_projection_key", KEY_J, true, true)
pointcloud.Projection.Scale = CreateClientConVar("pointcloud_projection_scale", "0.01", true, false)
pointcloud.Projection.Mode = CreateClientConVar("pointcloud_projection_mode", POINTCLOUD_MODE_CUBE, true, false)

pointcloud.Projection.ColorRed = CreateClientConVar("pointcloud_projection_color_r", "0", true, false)
pointcloud.Projection.ColorGreen = CreateClientConVar("pointcloud_projection_color_g", "161", true, false)
pointcloud.Projection.ColorBlue = CreateClientConVar("pointcloud_projection_color_b", "255", true, false)

pointcloud.Projection.DrawIndex = pointcloud.Projection.DrawIndex or 0
pointcloud.Projection.RenderTarget = GetRenderTarget("pointcloud_projection", 1920, 1080, true)

local sprite = Material("sprites/gmdm_pickups/light")

pointcloud.Input:AddHandler("projection_toggle", pointcloud.Projection.Key, function()
	pointcloud.Projection:Toggle()
end)

function pointcloud.Projection:Clear()
	self.DrawIndex = 0
	self.Position = nil
end

local function shuffle(tab)
	for i = #tab, 2, -1 do
		local j = math.random(i)

		tab[i], tab[j] = tab[j], tab[i]
	end
end

function pointcloud.Projection:Toggle()
	if self.Position then
		self.Position = nil
	else
		local vec = LocalPlayer():GetEyeTrace().HitPos

		self.Position = vec
		self.IndexList = {}

		for i = 1, #pointcloud.Data.PointList do
			self.IndexList[i] = i
		end

		shuffle(self.IndexList)
	end

	self.Stored = nil
end

function pointcloud.Projection:AddPoint(index)
	if not self.Position then
		return
	end

	self.IndexList[#self.IndexList + 1] = index
end

function pointcloud.Projection:Draw()
	local start = SysTime()
	local pData = pointcloud.Data

	local resolution = pointcloud:GetResolution()
	local scale = self.Scale:GetFloat()

	local lp = LocalPlayer()

	local lpos = lp:EyePos()
	local lang = lp:EyeAngles()
	local lfov = lp:GetFOV()

	local clear = not self.Stored or (self.Stored.Pos != lpos) or (self.Stored.Ang != lang) or (self.Stored.FOV != lfov)

	if not self.Stored then
		self.Stored = {
			Pos = lpos,
			Ang = lang,
			FOV = lfov
		}
	end

	if clear then
		render.PushRenderTarget(self.RenderTarget)
			render.Clear(0, 0, 0, 0, true, true)
		render.PopRenderTarget()

		self.DrawIndex = 0
	end

	local mode = self.Mode:GetInt()
	local bounds = game.GetWorld():GetModelBounds()

	pointcloud.Performance:UpdateBudget("Projection")

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

		render.PushRenderTarget(self.RenderTarget)
			while pointcloud.Performance:HasBudget("Projection") do
				local time = SysTime()

				if self.DrawIndex >= #self.IndexList then
					break
				end

				self.DrawIndex = self.DrawIndex + 1

				local index = self.IndexList[self.DrawIndex]
				local vec = pData:FromData(pData.PointList[index][1])

				vec.z = vec.z - bounds.z

				local col = pData.PointList[index][2]:ToColor()

				if mode == POINTCLOUD_MODE_CUBE then
					render.DrawBox(self.Position + (vec * scale), angle_zero, mins, maxs, col)
				else
					if mode == POINTCLOUD_MODE_HOLOGRAM then
						col = Color(self.ColorRed:GetInt(), self.ColorGreen:GetInt(), self.ColorBlue:GetInt())
					else
						local hue, sat = ColorToHSV(col)

						col = HSVToColor(hue, sat, 1)
					end

					render.DrawSprite(self.Position + (vec * scale), size * 4, size * 4, col)
				end

				pointcloud.Performance:AddSample("Projection", SysTime() - time)
			end
		render.PopRenderTarget()

		if mode == POINTCLOUD_MODE_CUBE then
			render.OverrideDepthEnable(false)
			render.OverrideAlphaWriteEnable(false)
		end
	cam.End3D()

	pointcloud.Material:SetTexture("$basetexture", self.RenderTarget)

	cam.Start2D()
		if mode != POINTCLOUD_MODE_CUBE then
			render.OverrideBlend(true, BLEND_SRC_COLOR, BLEND_ONE, BLENDFUNC_ADD, BLEND_SRC_ALPHA, BLEND_DST_ALPHA, BLENDFUNC_SUBTRACT)
		end

		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(pointcloud.Material)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())

		if mode != POINTCLOUD_MODE_CUBE then
			render.OverrideBlend(false)
		end
	cam.End2D()

	self.Stored = {
		Pos = lpos,
		Ang = lang,
		FOV = lfov
	}

	pointcloud.Debug.ProjectionTime = SysTime() - start
end
