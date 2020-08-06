if CLIENT then
	include("pointcloud/cl_enums.lua")
	include("pointcloud/cl_main.lua")
	include("pointcloud/cl_ui.lua")
	include("pointcloud/cl_hooks.lua")
else
	for _, v in pairs(file.Find("pointcloud/cl_*.lua", "LUA")) do
		AddCSLuaFile("pointcloud/" .. v)
	end

	include("pointcloud/sv_input.lua")
end