pointcloud.Persistence = pointcloud.Persistence or {}

pointcloud.Persistence.Budget = CreateClientConVar("pointcloud_loadbudget", "40", true, false)

pointcloud.Persistence.Offset = 0

file.CreateDir("pointcloud")

function pointcloud.Persistence:Clear()
	if self:IsLoading() then
		self:FinishLoading()
	end

	self.Offset = 0
end

function pointcloud.Persistence:IsLoading()
	return tobool(self.FileHandle)
end

function pointcloud.Persistence:GetFileName(resolution)
	if not resolution then
		resolution = pointcloud:GetResolution()
	end

	return "pointcloud/" .. game.GetMap() .. "-" .. resolution .. ".dat"
end

local function bitPack(vec)
	return bit.bor(bit.lshift(vec.x, 20), bit.lshift(vec.y, 10), vec.z)
end

local function bitUnpack(num)
	return Vector(
		bit.band(bit.arshift(num, 20), 1023),
		bit.band(bit.arshift(num, 10), 1023),
		bit.band(num, 1023)
	)
end

function pointcloud.Persistence:Save(resolution)
	timer.Remove("pointcloud.Save")

	local filename = self:GetFileName(resolution)
	local handle = file.Open(filename, "ab", "DATA")

	if handle:Size() == 0 then
		handle:Write("pointcloud")
		handle:WriteByte(1) -- Bump this if we ever update the format
	end

	for i = self.Offset, #pointcloud.Data.PointList do
		local v = pointcloud.Data.PointList[i]

		if not v then
			continue
		end

		local col = v[2]:ToColor()

		handle:WriteULong(bitPack(v[1]))

		handle:WriteByte(col.r)
		handle:WriteByte(col.g)
		handle:WriteByte(col.b)
	end

	handle:Close()

	self.Offset = #pointcloud.Data.PointList

	pointcloud.Debug.Filesize = file.Size(filename, "DATA")
end

function pointcloud.Persistence:StartLoader()
	if self.FileHandle then
		self.FileHandle:Close()
	end

	local resolution = pointcloud:GetResolution()
	local filename = self:GetFileName(resolution)

	pointcloud:Clear()

	pointcloud.Debug.Filesize = 0

	print(string.format("[Pointcloud] Starting map loader for %s at resolution: %sx", game.GetMap(), resolution))

	if not file.Exists(filename, "DATA") then
		print("[Pointcloud] Aborting map loader: No map file found")

		return
	end

	self.FileHandle = file.Open(filename, "rb", "DATA")

	print("[Pointcloud] Map file found: " .. filename)

	pointcloud.Debug.Filesize = self.FileHandle:Size()

	if self.FileHandle:Read(10) != "pointcloud" then
		print("[Pointcloud] Aborting map loader: Unknown or outdated file format")

		self.FileHandle:Close()
		self.FileHandle = nil

		file.Delete(filename) -- Sorry

		return
	end

	self.FileVersion = self.FileHandle:ReadByte()
end

function pointcloud.Persistence:ProcessLoader()
	pointcloud.Performance:UpdateBudget("Load")

	local handle = self.FileHandle
	local time = SysTime()

	while pointcloud.Performance:HasBudget("Load") do
		if handle:EndOfFile() then
			self:FinishLoading()

			return
		end

		local vec = bitUnpack(handle:ReadULong())
		local col = Vector(handle:ReadByte(), handle:ReadByte(), handle:ReadByte())

		col:Div(255)

		pointcloud.Data:AddSavePoint(vec, col)

		pointcloud.Performance:AddSample("Load", SysTime() - time)
	end
end

function pointcloud.Persistence:FinishLoading()
	local resolution = pointcloud:GetResolution()

	self.FileHandle:Close()
	self.FileHandle = nil

	self.Offset = #pointcloud.Data.PointList + 1

	print(string.format("[Pointcloud] Loaded %s points for %s at resolution: %sx", #pointcloud.Data.PointList, game.GetMap(), resolution))
end
