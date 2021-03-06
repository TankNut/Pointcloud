pointcloud.Data = pointcloud.Data or {}

pointcloud.Data.Points = pointcloud.Data.Points or {}
pointcloud.Data.PointList = pointcloud.Data.PointList or {}

function pointcloud.Data:Clear()
	self.Points = {}
	self.PointList = {}
end

function pointcloud.Data:Exists(pos)
	return self.Points[tostring(pos)] and true or false
end

function pointcloud.Data:Mark(pos, index)
	self.Points[tostring(pos)] = index or true
end

function pointcloud.Data:GetColor(pos)
	local index = self.Points[tostring(pos)]

	if index == true then
		return -- Marked by hitting the sky or something like that
	end

	return self.Points[index][2]
end

local offset = Vector(512, 512, 512)

function pointcloud.Data:FromWorld(pos)
	pos = Vector(pos)

	pos:Mul(1 / pointcloud:GetResolution())
	pos:Add(offset)

	pos.x = math.Round(pos.x)
	pos.y = math.Round(pos.y)
	pos.z = math.Round(pos.z)

	return pos
end

function pointcloud.Data:FromData(pos)
	pos = Vector(pos)

	pos:Sub(offset)
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

function pointcloud.Data:AddTracePoint(pos, col)
	pos = self:FromWorld(pos)

	self:AddPoint(pos, col)
end

function pointcloud.Data:AddSavePoint(pos, col)
	self:AddPoint(pos, col)
end