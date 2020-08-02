if game.SinglePlayer() then
	util.AddNetworkString("nPointcloudProjection")
	util.AddNetworkString("nPointcloudZoom")

	hook.Add("PlayerButtonDown", "pointcloud", function(ply, key)
		if key == ply:GetInfoNum("pointcloud_projection_key", KEY_NONE) then
			net.Start("nPointcloudProjection")
			net.Send(ply)
		elseif key == ply:GetInfoNum("pointcloud_minimap_zoomout", KEY_NONE) then
			net.Start("nPointcloudZoom")
				net.WriteBool(false)
			net.Send(ply)
		elseif key == ply:GetInfoNum("pointcloud_minimap_zoomin", KEY_NONE) then
			net.Start("nPointcloudZoom")
				net.WriteBool(true)
			net.Send(ply)
		end
	end)
end