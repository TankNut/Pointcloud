pointcloud.Data = pointcloud.Data or {}

pointcloud.Data.Points = pointcloud.Data.Points or {}
pointcloud.Data.PointList = pointcloud.Data.PointList or {}

function pointcloud.Data:Clear()
	self.Points = {}
	self.PointList = {}
end

local function bitPack(vec)
	return bit.bor(bit.lshift(vec.x, 20), bit.lshift(vec.y, 10), vec.z)
end

function pointcloud.Data:Exists(pos)
	return self.Points[bitPack(pos)] and true or false
end

function pointcloud.Data:Mark(pos, index)
	self.Points[bitPack(pos)] = index or true
end

function pointcloud.Data:GetColor(pos)
	local index = self.Points[bitPack(pos)]

	if index == true then
		return -- Marked by hitting the sky or something like that
	end

	return self.Points[index][2]
end

local offset = 512

function pointcloud.Data:FromWorld(pos)
	pos = Vector(pos)

	pos:Mul(1 / pointcloud:GetResolution())

	pos.x = math.Round(pos.x) + offset
	pos.y = math.Round(pos.y) + offset
	pos.z = math.Round(pos.z) + offset

	return pos
end

function pointcloud.Data:FromData(pos)
	pos = Vector(pos)

	pos.x = pos.x - offset
	pos.y = pos.y - offset
	pos.z = pos.z - offset

	pos:Mul(pointcloud:GetResolution())

	return pos
end

function pointcloud.Data:AddPoint(pos, col)
	if self:Exists(pos) then
		return
	end

	local index = #self.PointList + 1

	self:Mark(pos, index)
	self.PointList[index] = {pos, col}

	pointcloud.Minimap:AddPoint(pos, col)
	pointcloud.Projection:AddPoint(index)

	if not pointcloud.Persistence:IsLoading() then
		if #self.PointList - pointcloud.Persistence.Offset >= 1000 then
			pointcloud.Persistence:Save()
		else
			timer.Create("pointcloud.Save", 10, 1, function()
				pointcloud.Persistence:Save()
			end)
		end
	end

	return true
end

function pointcloud.Data:AddSavePoint(pos, col)
	self:AddPoint(pos, col)
end
