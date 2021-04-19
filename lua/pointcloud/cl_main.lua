pointcloud = pointcloud or {}

pointcloud.Enabled = CreateClientConVar("pointcloud_enabled", "1", true, false)
pointcloud.Resolution = CreateClientConVar("pointcloud_resolution", "64", true, false) -- Units per point

pointcloud.Material = CreateMaterial("pointcloud", "unlitgeneric", {
	["$basetexture"] = "color/white",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$translucent"] = 1,
	["$ignorez"] = 1
})

include("cl_input.lua")
include("cl_debug.lua")
include("cl_minimap.lua")
include("cl_persistence.lua")
include("cl_projection.lua")
include("cl_sampler.lua")
include("cl_performance.lua")
include("cl_data.lua")

function pointcloud:GetResolution()
	return self.Resolution:GetInt()
end

function pointcloud:Clear()
	self.Minimap:Clear()
	self.Projection:Clear()
	self.Sampler:Clear()
	self.Data:Clear()
end