pointcloud.Persistence = pointcloud.Persistence or {}

pointcloud.Persistence.Budget = CreateClientConVar("pointcloud_loadbudget", "40", true, false)

pointcloud.Persistence.Offset = 1

file.CreateDir("pointcloud")

function pointcloud.Persistence:IsLoading()
	return tobool(self.FileHandle)
end

function pointcloud.Persistence:GetFileName(resolution)
	if not resolution then
		resolution = pointcloud:GetResolution()
	end

	return "pointcloud/" .. game.GetMap() .. "-" .. resolution .. ".dat"
end

function pointcloud.Persistence:Save(resolution)
	timer.Remove("pointcloud.Save")

	local filename = self:GetFileName(resolution)
	local handle = file.Open(filename, "ab", "DATA")

	for i = self.Offset, #pointcloud.PointList do
		local v = pointcloud.PointList[i]
		local col = v[2]:ToColor()

		handle:WriteShort(v[1].x)
		handle:WriteShort(v[1].y)
		handle:WriteShort(v[1].z)

		handle:WriteByte(col.r)
		handle:WriteByte(col.g)
		handle:WriteByte(col.b)
	end

	handle:Close()

	self.Offset = #pointcloud.PointList

	pointcloud.Debug.Filesize = file.Size(filename, "DATA")
end

function pointcloud.Persistence:StartLoader()
	if self.FileHandle then
		self.FileHandle:Close()
	end

	local resolution = pointcloud:GetResolution()
	local filename = self:GetFileName(resolution)

	pointcloud:Clear()

	if not file.Exists(filename, "DATA") then
		pointcloud.Debug.Filesize = 0

		print(string.format("[Pointcloud] No map data found for %s at resolution: %sx", game.GetMap(), resolution))

		return
	end

	pointcloud.Debug.Filesize = file.Size(filename, "DATA")

	self.FileHandle = file.Open(filename, "rb", "DATA")
end

function pointcloud.Persistence:ProcessLoader()
	local handle = self.FileHandle

	local budget = self.Budget:GetInt() * 0.001
	local start = SysTime()

	while true do
		if handle:EndOfFile() then
			self:FinishLoading()

			return
		end

		local vec = Vector(handle:ReadShort(), handle:ReadShort(), handle:ReadShort())
		local col = Vector(handle:ReadByte(), handle:ReadByte(), handle:ReadByte())

		col:Div(255)

		self:AddLoadedPoint(vec, col)

		if SysTime() - start > budget then
			break
		end
	end
end

function pointcloud.Persistence:FinishLoading()
	local resolution = pointcloud:GetResolution()

	self.FileHandle:Close()
	self.FileHandle = nil

	self.Offset = #pointcloud.PointList + 1

	print(string.format("[Pointcloud] Loaded %s points for %s at resolution: %sx", #pointcloud.PointList, game.GetMap(), resolution))
end

function pointcloud.Persistence:AddLoadedPoint(pos, col)
	local slice = pos.z * (1 / pointcloud:GetResolution())

	pointcloud.Points[tostring(pos)] = true

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
end