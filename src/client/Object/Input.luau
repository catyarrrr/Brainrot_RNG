local UserInputService = game:GetService('UserInputService')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)

local player = Players.LocalPlayer
local CheckAlienMerge, CreatePlatformRaycastParams = nil
local self = {PlatformRaycastParams = nil}
self.State, self.SelectedTower = nil
local toolConnection = nil

local EnumState = {

	Idle = {
		name = 'Idle',

		enter = function(self)
			shared.UIHandler.TriggerTowerDetailEvent:Fire(false)
		end,
	},
	
	Selected = {
		name = 'Selected',

		enter = function(self)
			if self.SelectedTower ~= nil and self.SelectedTower.Destroyed == false then 
				-- print('ui')
				-- print('seletedtower uid:', self.SelectedTower.UID)
				shared.UIHandler.TriggerTowerDetailEvent:Fire(true, self.SelectedTower)
				shared.VFXHandler.SetTowerHighlight(self.SelectedTower.Rig)
				self.SelectedTower.Model.Circle.Transparency = 0

				local towerType = TowerData.GetTowerTypeByTowerUID(self.SelectedTower.TowerUID)
				if towerType then
					shared.SoundHandler:PlayGroupSound('BrainrotAction', 'Action_BR' .. tostring(towerType))
				end
			end
		end,

		exit = function(self)
			shared.VFXHandler.ClearTowerHighlight()
			if self.SelectedTower ~= nil and self.SelectedTower.Destroyed == false then
				self.SelectedTower.Model.Circle.Transparency = 1
			end
		end,

	},
}

--------  设置状态，执行进入、退出状态的函数
function self.SetState(newState, optionalTarget)
	-- print(newState)
	local state = EnumState[newState]
	if not state then warn('state not found');  return end
	
	if self.State == state and self.SelectedTower == optionalTarget then return end

	if self.State and self.State.exit then self.State.exit(self) end

	self.State = state
	-- print('set state:', self.State.name)
	self.SelectedTower = optionalTarget

	if state.enter then state.enter(self) end
end

function self.init()
	self.SpawnAreaHighlight = ReplicatedStorage.Assets.VFX.SpawnAreaHighlight
	self.TowerClickedEvent = shared.Event.new()
	self.MouseDetectConnection = nil
	self.PlayerInputConnection = nil
	self.CurrentHighlight = nil
	self.SelectedTower = nil
	self.State = nil
end

function self.start()
	local function SetupInput()
		if self.PlayerInputConnection then return end
		self.PlayerInputConnection = UserInputService.InputBegan:Connect(InputBegan)
		--shared.UIHandler.InitPriceUI()
		player.Character.ChildAdded:Connect(ToolAdded)
		player.Character.ChildRemoved:Connect(ToolRemoved)
		
	end

	player.CharacterAdded:Connect(SetupInput)

	if player.Character then
		SetupInput()
	end

	-- shared.Game.GameOverEvent:Connect(InputStopped)
end

-- 返回沿鼠标位置发射的射线和射线击中的物体
function self:RayCast()
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {player.Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = workspace.CurrentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	return workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams), ray
end

function self:PlatformRayCast()
	if self.PlatformRaycastParams == nil then
		CreatePlatformRaycastParams()
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = workspace.CurrentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	return workspace:Raycast(ray.Origin, ray.Direction * 1000, self.PlatformRaycastParams), ray
end
function self.CentralPlatformRayCast()
	if self.PlatformRaycastParams == nil then
		CreatePlatformRaycastParams()
	end
	
	local camera = workspace.CurrentCamera
	local center = camera.ViewportSize/ 2
	local ray = workspace.CurrentCamera:ViewportPointToRay(center.X, center.Y)
	return workspace:Raycast(ray.Origin, ray.Direction * 1000, self.PlatformRaycastParams), ray
end

-- 根据输入发射events中的事件
function InputBegan(input, process)
	if process then return end
	
	if input.KeyCode == Enum.KeyCode.X then
		-- 删除所选中的塔
		
		if self.SelectedTower then
			if not self.SelectedTower.Destroyed or self.SelectedTower.Upgraded then
				shared.TowerHandler.DespawnEvent:Fire(self.SelectedTower.Id)
				self.SelectedTower = nil
			end
		end
	elseif input.KeyCode == Enum.KeyCode.ButtonR1 then

		GuiService.SelectedObject = shared.UIHandler.TowersControlBtn.ImageButton

	elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonX then
		-- 取消所装备的塔
		
		local tool = player.Character:FindFirstChildWhichIsA('Tool')
		if tool then tool.Parent = player.Backpack; GuiService.SelectedObject = nil end

	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonR2 then
		-- 选中塔
		
		if player.Character:FindFirstChildWhichIsA('Tool') then return end

		local raycastHit, _ = self:RayCast()
		if raycastHit then
			--------------------------------- 点击时开启或者关闭选中塔高亮, 攻击范围视觉, 防御塔详情ui
			
			local model = raycastHit.Instance:FindFirstAncestorOfClass('Model')
			
			if model and game.CollectionService:HasTag(model, 'Tower') then 
				------- 选中tower的model
				-- print(model)

				local tower = shared.Tower.collections[model:FindFirstAncestorOfClass('Model')]

				-- print(tower)
				self.SetState('Selected', tower)

			else
				------- 未选中tower的model

				self.SetState('Idle')
			end
			---------------------------------
		end
	end
	
end

function ToolAdded(childAdded)
	if not childAdded:IsA('Tool') then return end
	--print('tooladded')

	self.SetState('Idle')
	GuiService.SelectedObject = nil
	shared.VFXHandler.ToggleAllPrompt(true)

	if UserInputService.TouchEnabled == true and UserInputService.KeyboardEnabled == false then
		-- shared.UIHandler.TouchFrame.Visible = true
		shared.UIHandler.TouchUI:Open()
		childAdded.ManualActivationOnly = true
	end
	
	-- 断开鼠标监听事件
	if self.MouseDetectConnection ~= nil then
		self.MouseDetectConnection:Disconnect()
		self.MouseDetectConnection = nil
	end

	local towerUID = childAdded:GetAttribute('TowerUID')
	local uid = childAdded:GetAttribute('UID')
	local assetId = TowerData.GetAssetIdByTowerUID(towerUID)
	local assets = AssetsData[assetId]
	
	local towerStaticData = TowerData.GetCloneData(towerUID)
	local playerData = shared.PlayerDataHandler.GetData()
	local towerInvData = playerData and playerData.Tower.Inv[uid]
	local traitId = towerInvData and towerInvData.Trait
	towerStaticData.Trait = traitId
	towerStaticData.UID = uid
	towerStaticData.TowerUID = towerUID
	shared.CalculateData.ApplyModifiers(towerStaticData, traitId)
	shared.UIHandler.TriggerTowerDetailEvent:Fire(true, towerStaticData, true)

	-- self.SpawnAreaHighlight.Enabled = true 
	-- self.SpawnAreaHighlight.Adornee = shared.GridHandler.SpawnArea
	shared.VFXHandler.ShowTowerOnMouse(assets.Model, towerUID)
	shared.Tower.CheckMergeEvent:Fire(childAdded)
	
	toolConnection = childAdded.Activated:Connect(function()
		-- print('tool activated')

		if UserInputService.TouchEnabled == true and UserInputService.KeyboardEnabled == false then
			if shared.UIHandler.IsTouchSpawn ~= nil and os.clock() - shared.UIHandler.IsTouchSpawn > .2 then
				return
			end
		end

		shared.TowerHandler.SpawnEvent:Fire(TowerData.GetData(towerUID), shared.VFXHandler.CurGrid, uid)
		childAdded.Parent = player.Backpack
	end)

end

function ToolRemoved(childAdded)
	if not childAdded:IsA('Tool') then return end
	--print('toolremoved')
	

	if UserInputService.TouchEnabled == true and UserInputService.KeyboardEnabled == false then
		shared.UIHandler.TouchUI:Close()
	end

	-- 连接鼠标监听事件
	if self.MouseDetectConnection then return end
	if UserInputService.KeyboardEnabled == true then
		-- self.MouseDetectConnection = RunService.Heartbeat:Connect(MouseDetect)
	end

	shared.UIHandler.TriggerTowerDetailEvent:Fire(false)
	shared.UIHandler.MergeBtn.Visible = false
	
	-- self.SpawnAreaHighlight.Enabled = false 
	-- self.SpawnAreaHighlight.Adornee = nil
	shared.VFXHandler.ToggleAllPrompt(false)
	shared.VFXHandler.HideTowerOnMouse()
	shared.VFXHandler.HideMergeBeam()
	shared.GridHandler.DespawnGhostCell()
	
	if toolConnection ~= nil then
		toolConnection:Disconnect()
		toolConnection = nil
	end
end

function CreatePlatformRaycastParams()
	local curPath = shared.PlayerDataHandler.GetCurPath()
	if curPath == nil then warn('curPath fetch error'); return end


	self.PlatformRaycastParams = RaycastParams.new()
	self.PlatformRaycastParams.FilterDescendantsInstances = {workspace.Platforms:WaitForChild(tostring(curPath))}
	self.PlatformRaycastParams.FilterType = Enum.RaycastFilterType.Include
end

return self