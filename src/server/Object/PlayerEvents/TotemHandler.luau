local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TotemData = require(ReplicatedStorage.Datas.TotemData :: ModuleScript)

local rng = Random.new()
local self = {}

function self.ClaimTotem(player, totemUID)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end
	if totemUID == nil then return end

	shared.DataStore.TotemController.Add(player, totemUID)
end
function self.PrayTotem(player)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	local cashChk = shared.DataStore.CoinController.CheckCash(player, TotemData.Cost)
	if cashChk == false then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Not enough Cash to pray')
		return
	end

	local roll = rng:NextNumber(0, 1)
	local count = 1
	if roll <= 0.001 then
		count = 3
	elseif roll <= 0.001 + 0.099 then
		count = 2
	end

	shared.DataStore.CoinController.Consume(player, TotemData.Cost)

	for i = 1, count do
		local totemUID = TotemData.Gacha()
		if totemUID == nil then break end
		ReplicatedStorage.Remote.Tower.PrayTotem:FireClient(player, totemUID)
		task.wait(.2)
	end

	shared.Area.PrayEvent:Fire(player)
end
function self.FeedTotem(player, feedUIDs, slot)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end
	if type(feedUIDs) ~= 'table' or #feedUIDs == 0 then return end
	if slot == nil then slot = 1 end

	local equippedTotem = shared.DataStore.TotemController.GetEquippedBySlot(player, slot)
	if equippedTotem == nil then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Equip a Totem first !!!')
		return
	end

	local totalPoints = 0
	for _, uid in feedUIDs do
		local totemData = playerData.Totem.Inv[uid]
		if not totemData then continue end
		local points = TotemData.GetConsumePointByPoints(totemData.Point)
		if not points then continue end
		shared.DataStore.TotemController.Remove(player, uid)
		totalPoints += points
	end
	shared.DataStore.TotemController.AddPoint(player, totalPoints, slot)

	local pathId = shared.DataStore.GetPlayerCurPath(player)
	local area = shared.Area.collections[pathId]
	if area then
		area:UpdateTotem(shared.DataStore.TotemController.GetEquippedSlots(player))
	end
end
function self.EquipTotem(player, uid, slot)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end
	if uid == nil then return end
	if slot == nil then slot = 1 end

	local result = shared.DataStore.TotemController.Equip(player, uid, slot)
	if result == nil then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Slot locked or Totem not found !!!')
		return
	end

	local pathId = shared.DataStore.GetPlayerCurPath(player)
	local area = shared.Area.collections[pathId]
	if area then
		area:UpdateTotem(shared.DataStore.TotemController.GetEquippedSlots(player))
	end
end

return self
