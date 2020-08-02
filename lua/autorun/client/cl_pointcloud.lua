local sprite = Material("sprites/gmdm_pickups/light")

local function shuffle(tab)
	for i = #tab, 2, -1 do
		local j = math.random(i)

		tab[i], tab[j] = tab[j], tab[i]
	end
end

local maxzoom = 5
local minzoom = 0.5

POINTCLOUD_MODE_CUBE 	= 1
POINTCLOUD_MODE_POINTS 	= 2

POINTCLOUD_SAMPLE_NONE 			= 0
POINTCLOUD_SAMPLE_NOISE 		= 1
POINTCLOUD_SAMPLE_FRONTFACING 	= 2

pointcloud = {
	Enabled = CreateClientConVar("pointcloud_enabled", "1", true, false),
	Resolution = CreateClientConVar("pointcloud_resolution", "64", true, false), -- Units per point
	SampleMode = CreateClientConVar("pointcloud_samplemode", "1", true, false),
	SampleRate = CreateClientConVar("pointcloud_samplerate", "90", true, false),

	Debug = {
		Enabled = CreateClientConVar("pointcloud_debug", "0", true, false),
		Filesize = pointcloud and pointcloud.Debug.Filesize or 0,
		MinimapTime = 0,
		ProjectionTime = 0,
		RenderTargets = 0,
		SampleTime = 0
	},

	Minimap = {
		Enabled = CreateClientConVar("pointcloud_minimap_enabled", "1", true, false),
		Width = CreateClientConVar("pointcloud_minimap_width", "300", true, false),
		Height = CreateClientConVar("pointcloud_minimap_height", "300", true, false),
		Zoom = CreateClientConVar("pointcloud_minimap_zoom", "1", true, false),
		ZoomOut = CreateClientConVar("pointcloud_minimap_zoomout", KEY_NONE, true, true),
		ZoomIn = CreateClientConVar("pointcloud_minimap_zoomin", KEY_NONE, true, true),
		ZoomStep = CreateClientConVar("pointcloud_minimap_zoomstep", 0.5, true, false),
		LayerDepth = CreateClientConVar("pointcloud_minimap_layerdepth", -1, true, false),
		DrawIndex = pointcloud and pointcloud.Minimap.DrawIndex or 0,
		RenderTargets = pointcloud and pointcloud.Minimap.RenderTargets or {},
		InfoLine = pointcloud and pointcloud.Minimap.InfoLine or {}
	},

	Projection = {
		Key = CreateClientConVar("pointcloud_projection_key", KEY_J, true, true),
		Scale = CreateClientConVar("pointcloud_projection_scale", "0.01", true, false, "How big to render projections with respect to the actual world"),
		Height = CreateClientConVar("pointcloud_projection_height", "32", true, false, "Height offset of a projection from the ground"),
		Mode = CreateClientConVar("pointcloud_projection_mode", POINTCLOUD_SAMPLE_NOISE, true, false, "The rendering method used for projections"),
		Position = pointcloud and pointcloud.Projection.Position or nil,
		Stored = pointcloud and pointcloud.Projection.Stored or nil,
		DrawIndex = pointcloud and pointcloud.Projection.DrawIndex or 0,
		IndexList = pointcloud and pointcloud.Projection.IndexList or nil,
		RenderTarget = GetRenderTarget("pointcloud", 1920, 1080, true)
	},

	Points = pointcloud and pointcloud.Points or {},
	PointList = pointcloud and pointcloud.PointList or {},

	SaveOffset = pointcloud and pointcloud.SaveOffset or 1,

	Material = CreateMaterial("pointcloud", "unlitgeneric", {
		["$basetexture"] = "color/white",
		["$vertexcolor"] = 1,
		["$vertexalpha"] = 1,
		["$translucent"] = 1,
		["$ignorez"] = 1
	})
}

hook.Add("AddToolMenuCategories", "pointcloud", function()
	spawnmenu.AddToolCategory("Options", "Pointcloud", "Pointcloud")
end)

hook.Add("PopulateToolMenu", "pointcloud", function()
	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_general", "General settings", "", "", function(pnl)
		pnl:ClearControls()

		pnl:CheckBox("Enable", "pointcloud_enabled")
		pnl:Help([[Changing the resolution might help alleviate performance issues caused by the size of the map and the amount of data being stored but will decrease clarity and accuracy.

			This option can cause your game to momentarily freeze as things are saved and loaded. Don't worry, this is normal.]])
		pnl:AddControl("ComboBox", {
			Label = "Resolution",
			MenuButton = 0,
			CVars = {"pointcloud_resolution"},
			Options = {
				["1. High (32 units/point)"] = {pointcloud_resolution = 32},
				["2. Medium (64 units/point)"] = {pointcloud_resolution = 64},
				["3. Low (128 units/point)"] = {pointcloud_resolution = 128}
			}
		})
		pnl:Help([[The sampler determines how the world around you is discovered and is easily the most performance intensive part of this addon.

			Performance issues can be helped by lowering the sample rate but doing so will slow the mapping process. The sample mode on the other hand is purely there for user preference and has no impact on performance whatsoever.]])
		pnl:AddControl("ComboBox", {
			Label = "Sample mode",
			MenuButton = 0,
			CVars = {"pointcloud_samplemode"},
			Options = {
				["0. Disabled"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_NONE},
				["1. Random noise"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_NOISE},
				["2. Front-facing noise"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_FRONTFACING}
			}
		})
		pnl:NumSlider("Sample rate", "pointcloud_samplerate", 20, 180, 0)

		pnl:CheckBox("Show debug info (Requires minimap)", "pointcloud_debug")
	end)

	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_minimap", "Minimap", "", "", function(pnl)
		pnl:ClearControls()

		pnl:CheckBox("Enable minimap", "pointcloud_minimap_enabled")

		pnl:NumSlider("Width", "pointcloud_minimap_width", 1, ScrW(), 0)
		pnl:NumSlider("Height", "pointcloud_minimap_height", 1, ScrH(), 0)
		pnl:NumSlider("Zoom", "pointcloud_minimap_zoom", minzoom, maxzoom, 1)
		pnl:Help([[Changing the layer depth will adjust how many layers the minimap can draw below you at any time, which may affect performance on maps with a lot of verticality.

			Setting this to -1 will make it render every layer instead.]])
		pnl:NumSlider("Layer depth", "pointcloud_minimap_layerdepth", -1, 100, 0)

		pnl:Help("")
		pnl:ControlHelp("Controls")
		pnl:AddControl("Numpad", {Label = "Zoom out", Command = "pointcloud_minimap_zoomout", Label2 = "Zoom in", Command2 = "pointcloud_minimap_zoomin"})
		pnl:NumSlider("Step size", "pointcloud_minimap_zoomstep", 0.1, 1, 1)
	end)

	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_projection", "Projection", "", "", function(pnl)
		pnl:ClearControls()

		pnl:NumSlider("Scale", "pointcloud_projection_scale", 0.01, 0.1, 2)
		pnl:NumSlider("Height offset", "pointcloud_projection_height", 0, 128, 0)

		pnl:AddControl("ComboBox", {
			Label = "Render mode",
			MenuButton = 0,
			CVars = {"pointcloud_projection_mode"},
			Options = {
				["1. Cubes"] = {pointcloud_projection_mode = POINTCLOUD_MODE_CUBE},
				["2. Points"] = {pointcloud_projection_mode = POINTCLOUD_MODE_POINTS}
			}
		})

		pnl:Help("")
		pnl:ControlHelp("Controls")
		pnl:AddControl("Numpad", {Label = "Toggle projection", Command = "pointcloud_projection_key", ButtonSize = 22})
	end)
end)

file.CreateDir("pointcloud")

function pointcloud:GetFileName(resolution)
	if not resolution then
		resolution = self.Resolution:GetInt()
	end

	return "pointcloud/" .. game.GetMap() .. "-" .. resolution .. ".dat"
end

function pointcloud:Save(resolution)
	timer.Remove("pointcloud")

	local filename = self:GetFileName(resolution)
	local f = file.Open(filename, "ab", "DATA")

	for i = self.SaveOffset, #self.PointList do
		local v = self.PointList[i]
		local col = v[2]:ToColor()

		f:WriteShort(v[1].x)
		f:WriteShort(v[1].y)
		f:WriteShort(v[1].z)

		f:WriteByte(col.r)
		f:WriteByte(col.g)
		f:WriteByte(col.b)
	end

	f:Close()

	self.SaveOffset = #self.PointList
	self.Debug.Filesize = file.Size(filename, "DATA")
end

function pointcloud:Load()
	local resolution = self.Resolution:GetInt()
	local filename = self:GetFileName(resolution)

	self:Clear()

	if not file.Exists(filename, "DATA") then
		return
	end

	local f = file.Open(filename, "rb", "DATA")

	while true do
		if f:EndOfFile() then
			break
		end

		local vec = Vector(f:ReadShort(), f:ReadShort(), f:ReadShort())
		local col = Vector(f:ReadByte(), f:ReadByte(), f:ReadByte())

		col:Div(255)

		self:AddLoadedPoint(vec, col)
	end

	f:Close()

	self.SaveOffset = #self.PointList + 1
	self.Debug.Filesize = file.Size(filename, "DATA")

	print(string.format("[Pointcloud] Loaded %s points for %s at resolution: %sx", #self.PointList, game.GetMap(), resolution))
end

function pointcloud:Clear()
	self.Points = {}
	self.PointList = {}

	self.SaveOffset = 1

	-- 2D map
	local minimap = self.Minimap

	minimap.RenderTargets = {}
	minimap.DrawIndex = 0

	-- 3D map
	local projection = self.Projection

	projection.DrawIndex = 0
	projection.Position = nil
end

local length = Vector(1, 1, 1):Length()

function pointcloud:Trace(pos, ang)
	local target = pos + (ang:Forward() * 20000)

	local tr = util.TraceLine({
		start = pos,
		endpos = target,
		mask = MASK_SOLID_BRUSHONLY
	})

	if tr.StartSolid or tr.Fraction == 1 then
		return
	end

	self:AddPoint(tr.HitPos, tr.HitNormal, tr.HitSky or tr.HitNoDraw)
end

function pointcloud:AddPoint(pos, normal, sky)
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

	local col = render.GetSurfaceColor(pos + normal * 1, pos - normal * 1)

	self.Points[tostring(pos)] = true

	local new = #self.PointList + 1

	if not sky and col:Length() <= length then
		local minimap = self.Minimap

		local rendertarget = minimap.RenderTargets[slice]

		if not rendertarget then
			rendertarget = GetRenderTarget("pointcloud" .. slice, 1024, 1024, true)

			minimap.RenderTargets[slice] = rendertarget

			render.PushRenderTarget(rendertarget)
				render.Clear(0, 0, 0, 0, true, true)
			render.PopRenderTarget()
		end

		self.PointList[new] = {pos, col}
	end

	if #self.PointList - self.SaveOffset >= 1000 then
		pointcloud:Save()
	else
		timer.Create("pointcloud", 10, 1, function()
			pointcloud:Save()
		end)
	end

	return true
end

function pointcloud:AddLoadedPoint(pos, col)
	local slice = pos.z * (1 / self.Resolution:GetInt())

	self.Points[tostring(pos)] = true

	local minimap = self.Minimap
	local rendertarget = minimap.RenderTargets[slice]

	if not rendertarget then
		rendertarget = GetRenderTarget("pointcloud" .. slice, 1024, 1024, true)

		minimap.RenderTargets[slice] = rendertarget

		render.PushRenderTarget(rendertarget)
			render.Clear(0, 0, 0, 0, true, true)
		render.PopRenderTarget()
	end

	self.PointList[#self.PointList + 1] = {pos, col}
end

function pointcloud:ToggleProjection()
	local projection = pointcloud.Projection

	local pos = projection.Position

	if pos then
		projection.Position = nil
	else
		local lp = LocalPlayer()
		local vec = lp:GetEyeTrace().HitPos

		vec.z = vec.z + projection.Height:GetInt()

		projection.Position = vec
		projection.IndexList = {}

		for i = 1, #self.PointList do
			projection.IndexList[i] = i
		end

		shuffle(projection.IndexList)
	end

	projection.Stored = nil
end

function pointcloud:MinimapZoom(dir)
	local minimap = self.Minimap
	local zoom = minimap.Zoom:GetFloat()
	local step = minimap.ZoomStep:GetFloat()

	if dir then
		zoom = math.min(zoom + step, maxzoom)
	else
		zoom = math.max(zoom - step, minzoom)
	end

	minimap.Zoom:SetFloat(zoom)
end

local function clearall(name, old, new)
	pointcloud:Save(tonumber(old))
	pointcloud:Load()
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
	net.Receive("nPointcloudProjection", function()
		pointcloud:ToggleProjection()
	end)

	net.Receive("nPointcloudZoom", function()
		pointcloud:MinimapZoom(net.ReadBool())
	end)
else
	hook.Add("PlayerButtonDown", "pointcloud", function(ply, key)
		if not IsFirstTimePredicted() or ply != LocalPlayer() then
			return
		end

		local projection = pointcloud.Projection
		local minimap = pointcloud.Minimap

		if key == projection.Key:GetInt() then
			pointcloud:ToggleProjection()
		elseif key == minimap.ZoomOut:GetInt() then
			pointcloud:MinimapZoom(false)
		elseif key == minimap.ZoomIn:GetInt() then
			pointcloud:MinimapZoom(true)
		end
	end)
end

hook.Add("PostGamemodeLoaded", "pointcloud", function()
	pointcloud:Load()
end)

hook.Add("Think", "pointcloud", function()
	if not pointcloud.Enabled:GetBool() then
		return
	end

	local start = SysTime()

	local lp = LocalPlayer()
	local lpos = lp:EyePos()
	local mode = pointcloud.SampleMode:GetInt()
	local rate = pointcloud.SampleRate:GetInt() + 1

	if mode == POINTCLOUD_SAMPLE_NOISE then
		for i = 1, rate do
			pointcloud:Trace(lpos, AngleRand())
		end
	elseif mode == POINTCLOUD_SAMPLE_FRONTFACING then
		for i = 1, rate do
			local ang = AngleRand(-45, 45)

			pointcloud:Trace(lpos, lp:LocalToWorldAngles(ang))
		end
	end

	pointcloud.Debug.SampleTime = SysTime() - start
end)

function pointcloud:DrawMinimap()
	local start = SysTime()
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

		local endpoint = minimap.LayerDepth:GetInt()

		if endpoint == -1 then
			endpoint = nil
		end

		local counter = 0

		for k, v in SortedPairs(minimap.RenderTargets) do
			if k > baseslice or (endpoint and k < baseslice - endpoint) then
				continue
			end

			counter = counter + 1

			self.Material:SetTexture("$basetexture", v)

			local col = 255

			if endpoint and endpoint > 0 then
				col = math.Remap(k, baseslice, baseslice - endpoint, 255, 0)
			end

			surface.SetDrawColor(col, col, col, col)
			surface.SetMaterial(self.Material)
			surface.DrawTexturedRect((width * 0.5) - (size * 0.5) + pos.y - 2, (height * 0.5) - (size * 0.5) + pos.x - 2, size, size)
		end

		render.SetStencilEnable(false)

		surface.SetDrawColor(255, 0, 0)
		surface.DrawRect((width * 0.5) - 2, (height * 0.5) - 2, 4, 4)
	cam.End2D()

	self.Debug.RenderTargets = counter
	self.Debug.MinimapTime = SysTime() - start
end

function pointcloud:AddInfoLine(str, ...)
	if str then
		draw.DrawText(string.format(str, ...), "BudgetLabel", 3, self.Minimap.InfoLine * 12, color_white, TEXT_ALIGN_LEFT)
	end

	self.Minimap.InfoLine = self.Minimap.InfoLine + 1
end

local function format_number(num)
	local _, _, minus, int, fraction = string.find(tostring(num), "([-]?)(%d+)([.]?%d*)")

	int = string.gsub(string.reverse(int), "(%d%d%d)", "%1,")

	return minus .. string.gsub(string.reverse(int), "^,", "") .. fraction
end

function pointcloud:DrawInfo()
	local minimap = self.Minimap

	minimap.InfoLine = 0

	cam.Start2D()
		local perc = math.Round((minimap.DrawIndex / #self.PointList) * 100)

		if perc < 100 then
			self:AddInfoLine("Loading... %s%%", perc)
		end

		local debugmode = self.Debug

		if debugmode.Enabled:GetBool() then
			self:AddInfoLine("Map: %s", game.GetMap())
			self:AddInfoLine("Resolution: %sx", self.Resolution:GetInt())
			self:AddInfoLine()
			self:AddInfoLine("Points: %s", format_number(#self.PointList))
			self:AddInfoLine("File size: %s", string.NiceSize(self.Debug.Filesize))
			self:AddInfoLine()
			self:AddInfoLine("Sample time: %.2fms", debugmode.SampleTime * 1000)
			self:AddInfoLine("Minimap render: %.2fms", debugmode.MinimapTime * 1000)
			self:AddInfoLine("Minimap rendertargets: %u", debugmode.RenderTargets)
			self:AddInfoLine("Projection render: %.2fms", self.Projection.Position and debugmode.ProjectionTime * 1000 or 0)
		end
	cam.End2D()
end

function pointcloud:DrawProjection()
	local start = SysTime()
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
				if projection.DrawIndex >= #projection.IndexList then
					break
				end

				projection.DrawIndex = projection.DrawIndex + 1

				local index = projection.IndexList[projection.DrawIndex]

				local vec = self.PointList[index][1]
				local col = self.PointList[index][2]:ToColor()

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

	self.Debug.ProjectionTime = SysTime() - start
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
		pointcloud:DrawInfo()
	end
end)