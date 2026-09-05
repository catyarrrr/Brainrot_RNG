local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)

local self = {}
local GenerateTowerVisual = nil

function self.start()
	shared.DataStore.PlayerDataLoadedEvent:Connect(self.InitBackpack, self)
	--print(shared.EnemyDatas.GetData(1))
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(char: Model)
			char.ChildAdded:Connect(function(child: Instance)
				if child:IsA('Tool') then
					-- print('equip tool')
					shared.DataStore.PlayerConfirmGuide(player, 2)
				end
			end)
			
		end)
	end)
end

function self.InitBackpack(self, player, towers)
	-- print('start init bp')
	local function init()
		local backpack = player:WaitForChild('Backpack')

		local cot = 0
		for k, v in towers do
			-- print('set tool')
			if v.IsTool == false then continue end
			cot += 1
			if cot >= shared.Config.BACKPACK_MAXTOOL then break end
			local tarTool = Instance.new('Tool')
			local staticData = TowerData.GetData(v.TowerUID)
			local assetId = TowerData.GetAssetIdByTowerUID(v.TowerUID)
			tarTool.RequiresHandle = false

			tarTool.Name = staticData.DisplayName
			tarTool.TextureId = AssetsData[assetId].Icon

			tarTool:SetAttribute('TowerUID', v.TowerUID)
			tarTool:SetAttribute('Quality', staticData.Quality)
			tarTool:SetAttribute('UID', v.UID)
			tarTool:SetAttribute('MutId', TowerData.GetMutIdByTowerUID(v.TowerUID))
			tarTool:SetAttribute('Level', TowerData.GetLvlByTowerUID(v.TowerUID))
			tarTool:SetAttribute('DisplayName', staticData.DisplayName)
			if v.Trait then tarTool:SetAttribute('Trait', v.Trait) end
			GenerateTowerVisual(tarTool, v.TowerUID)
			tarTool.Parent = backpack
		end
	end

	if player.Character then init() end
	player.CharacterAdded:Once(init)
end

function self.GetPlayerBackpack(player)
	local backpack = player:FindFirstChild('Backpack')
	if not backpack then warn('backpack not found for player:', player); return end
	return backpack
end
function self.RemovePlayerBackpackTool(player, uid)
    local function destroyIn(parent)
        if not parent then return false end
        for _, tool in ipairs(parent:GetChildren()) do
            if tool:IsA('Tool') and tool:GetAttribute('UID') == uid then
                tool:Destroy()
                return true
            end
        end
        return false
    end

    if destroyIn(self.GetPlayerBackpack(player)) then return end
    if player.Character then
        destroyIn(player.Character)
    end
end
function self.AddPlayerBackpackTool(player, uid)
	local backpack = player:FindFirstChild('Backpack')
	if not backpack then return end
	local cot = 0
	for _, child in backpack:GetChildren() do cot += 1 end
	if cot >= shared.Config.BACKPACK_MAXTOOL then return end
	local playerData = shared.DataStore.GetData(player)
	local towerData = playerData and playerData.Tower
	local backpackData = towerData and towerData.Inv
	if backpackData == nil then warn('player data fetch fail for uid', uid); return end
	
	local tarData = backpackData[uid]
	if tarData == nil then warn('towerData not found in backapck for uid', uid); return end
	local staticData = TowerData.GetData(tarData.TowerUID)
	local assetId = TowerData.GetAssetIdByTowerUID(tarData.TowerUID)
	local tarTool = Instance.new('Tool')
	-- tarTool.RequiresHandle = true
	tarTool.Name = staticData.DisplayName
	tarTool.TextureId = AssetsData[assetId].Icon
	
	tarTool:SetAttribute('TowerUID', tarData.TowerUID)
	tarTool:SetAttribute('Quality', staticData.Quality)
	tarTool:SetAttribute('UID', tarData.UID)
	tarTool:SetAttribute('MutId', TowerData.GetMutIdByTowerUID(tarData.TowerUID))
	tarTool:SetAttribute('Level', TowerData.GetLvlByTowerUID(tarData.TowerUID))
	tarTool:SetAttribute('DisplayName', staticData.DisplayName)
	if tarData.Trait then tarTool:SetAttribute('Trait', tarData.Trait) end
	GenerateTowerVisual(tarTool, tarData.TowerUID)
	tarTool.Parent = backpack
end
function self.ClearPlayerBackpack(player, uid)
    local backpack = player:FindFirstChild('Backpack')
    if backpack then
        for _, tool in backpack:GetChildren() do
            if tool:IsA('Tool') then tool:Destroy() end
        end
    end

    local character = player.Character
    if character then
        for _, tool in character:GetChildren() do
            if tool:IsA('Tool') then tool:Destroy() end
        end
    end
end
function self.CheckPlayerBackpack(player, uid)
	local backpack = player:FindFirstChild('Backpack')
	if not backpack then return end

	local target = backpack:FindFirstChild('Tool' .. tostring(uid))
	if target then 
		return true 
	else 
		return false 
	end
end

function GenerateTowerVisual(tool, towerUID)
	local handle = Instance.new('Part')
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.CanCollide = false
	handle.CanQuery = false
	handle.Transparency = 1
	handle.Parent = tool
	tool.RequiresHandle = true

	local assetId = TowerData.GetAssetIdByTowerUID(towerUID)
	local model = ReplicatedStorage.Assets.Towers:FindFirstChild(AssetsData[assetId].Model)
	local offset = model:GetPivot('CF') or CFrame.new(0, 0, 0)
    local clone = model:FindFirstChildOfClass('Model'):Clone()
	local towerData = TowerData.GetData(towerUID)
	
	shared.VFXHandler.GenerateMutParticle(clone, TowerData.GetMutIdByTowerUID(towerUID))
    for _, child in clone:GetDescendants() do
		if child:IsA('BasePart') then
			child.Anchored = false
			child.Massless = true
			child.CanCollide = false
			
			if child ~= clone.PrimaryPart then
				local weld = Instance.new('WeldConstraint')
				weld.Part0 = clone.PrimaryPart
				weld.Part1 = child
				weld.Parent = child
			end
		end
	end
	clone:PivotTo(handle.CFrame)
	
	
	local weld = Instance.new('WeldConstraint')
	weld.Part1 = clone.PrimaryPart	
	weld.Part0 = handle
	weld.Parent = handle
	
	shared.VFXHandler.GenerateTowerGui(clone, towerData)
	
	clone.Parent = tool
end

return self
