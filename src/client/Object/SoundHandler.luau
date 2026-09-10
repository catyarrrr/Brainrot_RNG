local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService('SoundService')
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local soundFolder = Instance.new('Folder')
soundFolder.Parent = workspace
soundFolder.Name = 'Sounds'

local BGMPLAY = nil
local self = {Sounds = {}}
self.Channels = { BGM = {}, SFX = {}, UI = {}, }

function self.init()
	self.TowerHitEvent = shared.Event.new()
	-- self:Register(name, assetId, channel, volume, looped, minDistance, maxDistance)
	self:RegisterSound('Operate_Fail', 'SFX')
	self:RegisterSound('Operate_Success', 'SFX')
	self:RegisterSound('Collect_Coin', 'SFX')
	self:RegisterSound('Collect_Loot', 'SFX')

	self:RegisterSound('UI_Success', 'UI')
	self:RegisterSound('UI_Fail', 'UI')
	self:RegisterSound('Wheel_Spin', 'UI')

	self:RegisterSound('Clone', 'UI')

	self:RegisterSound('UFO', 'UI')
	self:RegisterSound('UFO_Reward', 'UI')

	self:RegisterSound('Trait_Result', 'UI')
	self:RegisterSound('Trait_Inhale', 'UI')

	self:RegisterSound('PrayTotem', 'UI')
	self:RegisterSound('FeedTotem', 'UI')

	self:RegisterFolder('LobbyBGM', 'BGM')
	self:RegisterFolder('BrainrotAction', 'UI')

	RegisterAlienHitSound()
end

function self.start()
	shared.Game.GameEndedEvent:Connect(function() self:Play('Operate_Fail') end)

	ReplicatedStorage.Remote.PlayerSpin.OnClientEvent:Connect(function()
		self:Play('Wheel_Spin')
	end)
	ReplicatedStorage.Remote.ServerWarn.OnClientEvent:Connect(function()
		self:Play('Operate_Fail')
	end)
	shared.PlayerDataHandler.DataChangedEvent:Connect(function(self, tag)
		if tag and (table.find(tag, 'Area') or table.find(tag, 'VIPDaily')) then self:Play('Operate_Success') end
	end, self)
	self.TowerHitEvent:Connect(function(self, towerUID, pos)
		local towerType = TowerData.GetTowerTypeByTowerUID(towerUID)
		if towerType == nil then return end
		self:PlayAt('Hit_BR' .. tostring(towerType), pos)
	end, self)

	BGMPLAY()
end

function self:Register(name, assetId, channel, volume, looped, minDistance, maxDistance)
	local sound = Instance.new('Sound')
	sound.Name = name
	sound.SoundId = assetId
	sound.Parent = SoundService
	sound.Volume = volume or .5
	sound.Looped = looped or false
	if maxDistance then sound.RollOffMaxDistance = maxDistance end
	if minDistance then sound.RollOffMinDistance = minDistance end
	
	self.Sounds[name] = sound
	self.Channels[channel][name] = sound
end

function self:RegisterSound(soundName, channel)
	if not self.Channels[channel] then warn('invalid channel:', channel); return end
	if self.Sounds[soundName] then warn('sound already registered:', soundName); return end

	local template = ReplicatedStorage.Assets.Sounds:FindFirstChild(soundName)
	if template == nil then warn('sound not found for name:', soundName); return end

	local clone = template:Clone()
	clone.Parent = SoundService

	self.Sounds[soundName] = clone
	self.Channels[channel][soundName] = clone
end

function self:RegisterInstance(instance, channel)
	local soundName = instance.Name
	if not self.Channels[channel] then warn('invalid channel:', channel); return end
	if self.Sounds[soundName] then warn('sound already registered:', soundName); return end

	local clone = instance:Clone()
	clone.Parent = SoundService

	self.Sounds[soundName] = clone
	self.Channels[channel][soundName] = clone

end

function self:RegisterFolder(folderName, channel)
	if not self.Channels[channel] then warn('invalid channel:', channel); return end
	if self.Sounds[folderName] then warn('sound already registered:', folderName); return end

	local folder = ReplicatedStorage.Assets.Sounds:FindFirstChild(folderName)
	if folder == nil then warn('folder not found for name:', folderName); return end

	local group = {}
	for _, child in folder:GetChildren() do
		if child:IsA('Sound') then
			local clone = child:Clone()
			clone.Parent = SoundService
			table.insert(group, clone)
		end
	end

	self.Sounds[folderName] = group
	self.Channels[channel][folderName] = group
end

function self:RegisterGroup(name, assetId, channel, volume, looped, minDistance, maxDistance)
	local sound = Instance.new('Sound')
	sound.Name = name
	sound.SoundId = assetId
	sound.Parent = SoundService
	sound.Volume = volume or .5
	sound.Looped = looped or false
	if maxDistance then sound.RollOffMaxDistance = maxDistance end
	if minDistance then sound.RollOffMinDistance = minDistance end

	self.Sounds[name] = self.Sounds[name] or {}
	table.insert(self.Sounds[name], sound)
	
	self.Channels[channel][name] = sound
end

function self:Play(name)
	local sound = self.Sounds[name]
	if not sound then warn('sound not found for name:', name); return end

	sound:Play()
end
function self:PlayAsync(name)
	local sound = self.Sounds[name]
	if not sound then warn('sound not found for name:', name); return end

	sound = sound:Clone()
	sound.Parent = SoundService

	sound:Play()
	sound.Ended:Connect(function() sound:Destroy() end)
end

function self:PlayRanAt(name, pos)
	local list = self.Sounds[name]
	if not list then warn('sound not found for name:', name); return end
	
	local sound = list[math.random(#list)]:Clone()
	local part = Instance.new('Part')
	part.Position = pos
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Anchored = true
	part.Parent = soundFolder

	sound.Parent = part

	sound:Play()

	sound.Ended:Connect(function() part:Destroy() end)
end

function self:PlayRan(name)
	local list = self.Sounds[name]
	if not list then warn('sound not found for name:', name); return end
	
	local sound = list[math.random(#list)]

	sound:Play()
end

function self:PlayGroupSound(groupName, soundName)
	local group = self.Sounds[groupName]
	if not group then warn('sound group not found for name:', groupName); return end

	local target : Sound = nil
	for _, sound : Sound in group do
		if sound.Name == soundName then target = sound end
	end
	if target == nil then return end

	for _, sound : Sound in group do
		if sound ~= target and sound.IsPlaying then sound:Stop() end
	end

	target:Play()
end

function self:PlayAt(name, pos)
	local sound = self.Sounds[name]
	if not sound then warn('sound not found for name:', name); return end

	sound = sound:Clone()
	local part = Instance.new('Part')
	part.Position = pos
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Anchored = true
	part.Parent = soundFolder
	
	sound.Parent = part
	
	sound:Play()
	
	sound.Ended:Connect(function() part:Destroy() end)
end

function self:CheckIsPlaying(name)
	local sound = self.Sounds[name]
	if sound == nil or sound.IsPlaying == false then return false end

	return true
end

function self:Stop(name)
	local sound = self.Sounds[name]
	if not sound or not sound.Playing then return end

	sound:Stop()
end

function self:StopGroup(name)
	local list = self.Sounds[name]
	if list == nil then warn('stop groupmusic error for name:', name) end
	for _, music in list do
		music:Stop()
	end
end	

function RegisterAlienHitSound()
	for _, sound in ReplicatedStorage.Assets.Sounds.BrainrotHit:GetChildren() do
		if sound:IsA('Sound') then
			self:RegisterInstance(sound, 'SFX')
		end
	end
end

function BGMPLAY()
	local list : {Sound} = self.Sounds['LobbyBGM']
	if not list or #list == 0 then warn('no BGM sounds in folder: LobbyBGM'); return end

	local lastPlayed : Sound = nil

	local function playNext()
		local bgm : Sound
		repeat
			bgm = list[math.random(#list)]
		until #list <= 1 or bgm ~= lastPlayed

		lastPlayed = bgm
		bgm:Play()

		bgm.Ended:Once(playNext)
	end

	playNext()
end

return self
