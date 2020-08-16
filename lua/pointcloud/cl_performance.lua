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

	if #data.Samples == 0 then
		data.Cost = 0
	else
		local cost = 0

		for _, v in ipairs(data.Samples) do
			cost = cost + v
		end

		data.Cost = cost / #data.Samples
	end

	table.Empty(data.Samples)

	data.Start = SysTime()
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

	return time + data.Cost <= (data.Convar:GetInt() * 0.001)
end