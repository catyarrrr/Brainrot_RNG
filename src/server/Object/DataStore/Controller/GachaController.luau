local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SummonData = require(ReplicatedStorage.Datas.SummonData :: ModuleScript)

local QUALITY_LEGENDARY, QUALITY_MYTHIC, QUALITY_SECRET, SPIN_INTERVAL  = 4, 5, 6, 60 * 10
local self = {}

function self.Init(context)
    self.GetData = context.GetData
    self.SetPlayerData = context.SetPlayerData
    self.TowerModule = context.TowerModule
    self.ItemModule = context.ItemModule
end


function self.Gacha(player, luck)
    local tarData = self.GetData(player)
    if not tarData then return end

    local quality = nil

    local legendaryPity = tarData.Gacha.LegendaryPity + 1
    local mythicPity = tarData.Gacha.MythicPity + 1
    local secretPity = tarData.Gacha.SecretPity + 1
    if secretPity >= SummonData.Pitys.Secret then
        quality = QUALITY_SECRET
        secretPity = 0
    elseif mythicPity >= SummonData.Pitys.Mythic then 
        quality = QUALITY_MYTHIC
        mythicPity = 0
    elseif legendaryPity >= SummonData.Pitys.Legendary then
        quality = QUALITY_LEGENDARY
        legendaryPity = 0
    else
        quality = SummonData.GetTowerDictKeyByLuck(luck)
        if quality == QUALITY_LEGENDARY then legendaryPity = 0 end
        if quality == QUALITY_MYTHIC then mythicPity = 0 end
        if quality == QUALITY_SECRET then secretPity = 0 end
    end
    
    tarData.Gacha.LegendaryPity = legendaryPity
    tarData.Gacha.MythicPity = mythicPity
    tarData.Gacha.SecretPity = secretPity

    return quality
end

function self.UpgradeLuck(player, cost)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Gacha.Luck += 1 
    tarData.Coin.Cash -= cost

    self.SetPlayerData(player, 'Cash')
    shared.GachaMachine.GachaDataUpdateEvent:Fire(player)
end

function self.BuyLuckUpgrade(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Gacha.Luck += 1

    self.SetPlayerData(player)
    shared.GachaMachine.GachaDataUpdateEvent:Fire(player)
end


function self.BuyDoubleLuck(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Gacha.Luck += 1
    tarData.VIP.DoubleLuck = true

    self.SetPlayerData(player, 'VIP')
    shared.GachaMachine.GachaDataUpdateEvent:Fire(player)
end
function self.BuyTripleLuck(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Gacha.Luck += 1
    tarData.VIP.TripleLuck = true

    self.SetPlayerData(player, 'VIP')
    shared.GachaMachine.GachaDataUpdateEvent:Fire(player)
end
function self.BuyPass(player, vip)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.VIP[vip] = true

    self.SetPlayerData(player, 'VIP')
end

--  转盘
function self.BuySpin(player, amount)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Gacha.Spins += amount

    self.SetPlayerData(player, 'Wheel')
end
function self.CheckWheel(player)  --  校验wheel数据
    local tarData = self.GetData(player)
    if not tarData then return end

    self.SpinUpdate(player)

    self.SetPlayerData(player, 'WheelUpdate')
end
function self.ClaimWheelReward(player, type, reward, amount)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Gacha.Spins -= 1

    if type == 1 then
        -- print('cash')
        tarData.Coin.Cash += reward
    elseif type == 2 or type == 3 then
        -- print('item')
        self.ItemModule.AddItem(tarData.Item, reward, amount)
    elseif type == 4 then
        -- print('alien')
        local newUID = HttpService:GenerateGUID(false)
        self.TowerModule.AddTower(tarData.Tower, reward, newUID)
        
        shared.BackpackHandler.AddPlayerBackpackTool(player, newUID)
        ReplicatedStorage.Remote.Tower.Summon:FireClient(player, reward)
    end
    self.SpinUpdate(player)

    self.SetPlayerData(player, 'Wheel')
end

-- Boss挑战
function self.StartChallenge(player, multi)
    local tarData = self.GetData(player)
    if not tarData then return end
    
    self.ChallengeUpdate(player)

    local challengeData = tarData.BossChallenge
	local curCount = challengeData.Count - multi
    local chk
	if curCount < 0 then
		chk = false
    else
        challengeData.Count = curCount
        if challengeData.RecoverTime == 0 and curCount < shared.Config.BOSSCHALLENGE_MAXCOUNT then
            challengeData.RecoverTime = workspace:GetServerTimeNow() + shared.Config.BOSSCHALLENGE_RECOVER
        end
        chk = true
	end

    self.SetPlayerData(player, 'Rush')

    return chk, math.abs(curCount)
end
function self.ChallengeUpdate(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    local challengeData = tarData.BossChallenge
    local now = workspace:GetServerTimeNow()

    if challengeData.Count < shared.Config.BOSSCHALLENGE_MAXCOUNT and now >= challengeData.RecoverTime then
        local recoverCount = math.floor((now - challengeData.RecoverTime) / shared.Config.BOSSCHALLENGE_RECOVER + 1)

        challengeData.Count = math.min(shared.Config.BOSSCHALLENGE_MAXCOUNT, challengeData.Count + recoverCount)

        if challengeData.Count >= shared.Config.BOSSCHALLENGE_MAXCOUNT then
            challengeData.RecoverTime = 0
        else
            challengeData.RecoverTime += recoverCount * shared.Config.BOSSCHALLENGE_RECOVER
        end
    end
end
function self.BuyChallenge(player, amount)
    local tarData = self.GetData(player)
    if not tarData then return end

    self.ChallengeUpdate(player)

    local challengeData = tarData.BossChallenge
    challengeData.Count += amount
    challengeData.Count = math.min(shared.Config.BOSSCHALLENGE_MAXCOUNT, challengeData.Count)

    if challengeData.Count >= shared.Config.BOSSCHALLENGE_MAXCOUNT then
        challengeData.RecoverTime = 0
    elseif challengeData.RecoverTime == 0 then
        challengeData.RecoverTime = workspace:GetServerTimeNow() + shared.Config.BOSSCHALLENGE_RECOVER
    end

    self.SetPlayerData(player, 'Rush')
end

function self.SpinUpdate(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    local now = workspace:GetServerTimeNow()

    local count = math.floor(
        (now - tarData.Gacha.LastSpin) / SPIN_INTERVAL
    )

    if count > 0 then
        tarData.Gacha.Spins += count
        tarData.Gacha.LastSpin += count * SPIN_INTERVAL
    end
end
return self
