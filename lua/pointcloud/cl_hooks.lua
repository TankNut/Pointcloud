hook.Add("Think", "pointcloud", function()
	if not pointcloud.Enabled:GetBool() then
		return
	end

	if pointcloud.Persistence:IsLoading() then
		pointcloud.Persistence:ProcessLoader()

		return
	end

	pointcloud.Sampler:Run()
end)

hook.Add("PreDrawHUD", "pointcloud", function()
	if not pointcloud.Enabled:GetBool() then
		return
	end

	if pointcloud.Minimap.Enabled:GetBool() then
		pointcloud.Minimap:Draw()
		pointcloud.Minimap:DrawInfo()
	end
end)

hook.Add("PreDrawViewModels", "pointcloud", function()
	if not pointcloud.Enabled:GetBool() then
		return
	end

	if pointcloud.Projection.Position then
		pointcloud.Projection:Draw()
	end
end)

hook.Add("PostGamemodeLoaded", "pointcloud", function()
	if pointcloud.Enabled:GetBool() then
		pointcloud.Persistence:StartLoader()
	end
end)

local function enable(name, old, new)
	if old == new then
		return
	end

	if tobool(new) then
		pointcloud.Persistence:StartLoader()
	else
		if pointcloud.Persistence:IsLoading() then
			pointcloud:FinishLoading()
		else
			pointcloud.Persistence:Save()
		end

		pointcloud:Clear()
	end
end

local function clearall(name, old, new)
	pointcloud.Persistence:Save(tonumber(old))
	pointcloud.Persistence:StartLoader()
end

local function clearprojection()
	local projection = pointcloud.Projection

	render.PushRenderTarget(projection.RenderTarget)
		render.Clear(0, 0, 0, 0, true, true)
	render.PopRenderTarget()

	projection.DrawIndex = 0
end

cvars.AddChangeCallback("pointcloud_enabled", enable, "pointcloud")
cvars.AddChangeCallback("pointcloud_resolution", clearall, "pointcloud")
cvars.AddChangeCallback("pointcloud_projection_mode", clearprojection, "pointcloud")
cvars.AddChangeCallback("pointcloud_projection_scale", clearprojection, "pointcloud")