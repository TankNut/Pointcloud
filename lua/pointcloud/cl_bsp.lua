pointcloud.BSP = pointcloud.BSP or {}

local meta = {}

meta.__index = meta

function meta:Init()
	self.File = file.Open(string.format("maps/%s.bsp", game.GetMap()), "rb", "GAME")

	self.Header = self:ReadHeader()
	self.Leafs = self:ReadLeafs()

	return self
end

function meta:Close()
	self.File:Close()
	self.File = nil
end

-- Wrap funcs

function meta:Tell()
	return self.File:Tell()
end

function meta:Seek(pos)
	self.File:Seek(pos)
end

function meta:Skip(amt)
	self.File:Skip(amt)
end

function meta:Read(len)
	return self.File:Read(len)
end

function meta:Long()
	return self.File:ReadLong()
end

meta.Int = meta.Long

function meta:Short()
	return self.File:ReadShort()
end

function meta:UShort()
	return self.File:ReadUShort()
end

-- Bsp specific funcs

function meta:ReadHeader()
	return {
		Ident = self:Int(),
		Version = self:Int(),
		Lumps = self:LoadLumps(),
		Revision = self:Int()
	}
end

function meta:LoadLumps()
	local lumps = {}

	for i = 0, 63 do
		lumps[i] = {
			Offset = self:Int(),
			Length = self:Int(),
			Version = self:Int(),
			FourCC = self:Read(4)
		}
	end

	return lumps
end

function meta:GetLump(i)
	return self.Header.Lumps[i]
end

function meta:ReadLeafs()
	local lump = self:GetLump(10)
	local leafs = {}

	local padding = 24

	if self.Header.Version == 20 then
		padding = 0
	end

	self:Seek(lump.Offset)

	for i = 0, lump.Length / (32 + padding) do
		leafs[i] = {
			Contents = self:Int(),
			Cluster = self:Short(),
			Area = self:Short(),
			Mins = Vector(self:Short(), self:Short(), self:Short()),
			Maxs = Vector(self:Short(), self:Short(), self:Short()),
			FirstLeafFace = self:UShort(),
			NumLeafFaces = self:UShort(),
			FirstLeafBrush = self:UShort(),
			NumLeafBrushes = self:UShort(),
			LeafWaterDataID = self:Short(),
			Padding = self:Short()
		}

		self:Skip(padding)
	end

	return leafs
end

function meta:GetLeaf(i)
	return self.Leafs[i]
end

function pointcloud.BSP:Load()
	self.Leafs = {}

	local reader = setmetatable({}, meta):Init()

	for _, v in ipairs(reader.Leafs) do
		if bit.band(v.Contents, CONTENTS_SOLID) != CONTENTS_SOLID then
			self.Leafs[#self.Leafs + 1] = v
		end
	end

	reader:Close()
end
