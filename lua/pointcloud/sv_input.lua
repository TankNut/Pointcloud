if game.SinglePlayer() then
	util.AddNetworkString("nPointcloudKey")

	hook.Add("PlayerButtonDown", "pointcloud", function(ply, key)
		net.Start("nPointcloudKey")
			net.WriteUInt(key, 8)
		net.Send(ply)
	end)
end