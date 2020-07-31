if game.SinglePlayer() then
	util.AddNetworkString("nPointcloudKey")

	hook.Add("PlayerButtonDown", "pointcloud", function(ply, key)
		if key == ply:GetInfoNum("pointcloud_projection_key", KEY_J) then
			net.Start("nPointcloudKey")
			net.Send(ply)
		end
	end)
end