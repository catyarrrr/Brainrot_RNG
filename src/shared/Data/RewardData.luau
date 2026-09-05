local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RewardData = require(ReplicatedStorage.Datas.Reward :: ModuleScript)

local rng = Random.new()
local self = {}

function self.GetWeeklyDaily(day)
	local reward = RewardData.WeeklyLogin[day]
	if reward == nil then
		warn('get weekly daily reward error, day: '..day)
		return
	end

	return reward
end

function self.GachaBundle(key)
	local list = RewardData.Bundle[key]
	local totalWeight = 0

	for k, v in pairs(list) do
		totalWeight += v
	end

	local ranWeight = rng:NextNumber() * totalWeight
	local curWeight = 0

	for k, v in pairs(list) do
		curWeight += v
		if curWeight >= ranWeight then
			return k
		end
	end
	return nil
end

return self