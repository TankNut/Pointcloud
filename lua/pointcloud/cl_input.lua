pointcloud.Input = pointcloud.Input or {}

pointcloud.Input.Handlers = pointcloud.Input.Handlers or {}

function pointcloud.Input:AddHandler(key, convar, callback)
	self.Handlers[key] = {Convar = convar, Callback = callback}
end

function pointcloud.Input:Fire(key)
	self.Handlers[key].Callback()
end

function pointcloud.Input:Handle(keycode)
	for k, v in pairs(self.Handlers) do
		if keycode == v.Convar:GetInt() then
			self:Fire(k)
		end
	end
end

if game.SinglePlayer() then
	net.Receive("nPointcloudKey", function()
		pointcloud.Input:Handle(net.ReadUInt(8))
	end)
else
	hook.Add("PlayerButtonDown", "pointcloud.Input", function(ply, keycode)
		if not IsFirstTimePredicted() then
			return
		end

		pointcloud.Input:Handle(keycode)
	end)
end