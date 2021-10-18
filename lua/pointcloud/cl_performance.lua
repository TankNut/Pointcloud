pointcloud.Performance = pointcloud.Performance or {}

pointcloud.Performance.Data = {}

local function register(key, budget)
	pointcloud.Performance.Data[key] = {
		Samples = {},
		Cost = 0,
		Start = SysTime(),
		Convar = budget
	}
end

register("Load", CreateClientConVar("pointcloud_budget_load", "40", true, false))
register("Sampler", CreateClientConVar("pointcloud_budget_sampler", "20", true, false))
register("Projection", CreateClientConVar("pointcloud_budget_projection", "10", true, false))

function pointcloud.Performance:UpdateBudget(key)
	local data = self.Data[key]
	local samples = data.Samples

	if #samples == 0 then
		data.Cost = 0
	else
		local cost = 0

		for i = 1, #samples do
			cost = cost + samples[i]
		end

		data.Cost = cost / #samples
	end

	data.Samples = {}

	data.Start = SysTime()
	data.Cache = data.Convar:GetInt()
end

function pointcloud.Performance:AddSample(key, time)
	local data = self.Data[key]

	data.Samples[#data.Samples + 1] = time

	if data.Cost == 0 then
		data.Cost = time
	end
end

function pointcloud.Performance:HasBudget(key)
	local data = self.Data[key]
	local time = SysTime() - data.Start

	if data.Cost == 0 then
		return true
	end

	return time + data.Cost <= (data.Cache * 0.001)
end
