local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionData = require(ReplicatedStorage.Datas.CollectionData :: ModuleScript)
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)

local self : any = {}

function self.start()
    shared.LeftUI.IndexBtnClickedEvent:Connect(function()
        self.Update()
        self:Open()
    end)
end

function self.Init(frame)
	self.Main = shared.Frame.new(frame.Menu.Index)
    self.Main:Visible(false)

    self.Frame = self.Main.Frame.Frame
    self.ScrollingFrame = self.Frame.ScrollingFrame
    self.CollectionFrame = self.Frame.Collect

    self.Frame.Title.Close.MouseButton1Click:Connect(function()
        self:Close()
    end)
    self.Frame.Tab.NormalBtn.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Success')
        self.Update(1)
    end)
    self.Frame.Tab.GoldBtn.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Success')
        self.Update(2)
    end)
    self.Frame.Tab.DiamondBtn.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Success')
        self.Update(3)
    end)
    self.Frame.Tab.DragonbornBtn.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Success')
        self.Update(4)
    end)
    self.Frame.Tab.BeastBtn.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Success')
        self.Update(5)
    end)
    self.Frame.Tab.TitanBtn.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Success')
        self.Update(6)
    end)

end

function self.Update(newIndex)
    local playerData = shared.PlayerDataHandler.GetData()
    local collection = playerData.Tower.Collection

    local needUpdate = false
    if self.Index == nil then 
        self.Index = 1 
        needUpdate = true
    elseif self.Index == newIndex then
        needUpdate = false 
    elseif newIndex == nil then
        needUpdate = false
    else
        self.Index = newIndex
        needUpdate = true
    end
    
    --  槽位更新
    if needUpdate then
        for _, slot in pairs(self.ScrollingFrame:GetChildren()) do
            if slot:IsA('ImageButton') then
                slot:Destroy()
            end
        end
        local dict = CollectionData[self.Index]
        for _, towerUID in pairs(dict) do
            local staticData = TowerData.GetData(towerUID)

            local collectionUID, notCollect = math.floor(towerUID/100) * 100, nil
            if collection[tostring(collectionUID)] then notCollect = nil else notCollect = true end
            local slot = shared.TowerListHelper.GetSlotByStaticData(staticData, nil, notCollect)
            if slot == nil then continue end

            slot:SetAttribute('TowerUID', staticData.TowerUID)
            slot.Parent = self.ScrollingFrame
        end
    end

    for _, slot in pairs(self.ScrollingFrame:GetChildren()) do
        if slot:IsA('ImageButton') then
            local towerUID = slot:GetAttribute('TowerUID')
            local collectionUID = math.floor(towerUID/100) * 100
            if collection[tostring(collectionUID)] == true then 
                slot.Icon.ImageColor3 = Color3.fromRGB(255, 255, 255) 
            else
                slot.Icon.ImageColor3 = Color3.fromRGB(0, 0, 0) 
            end
        end
    end
    
    local cur, total, boost = collection.Total, CollectionData.TOTAL, math.floor(collection.Total / shared.Config.COIN_COLLECTIONBOOST)
    self.Frame.Title.Complete.Text = string.format('%d%% Complete', cur / total * 100)
    self.Frame.Title.Discovered.Text = string.format('%d/%d Discovered', cur, total)

    self.CollectionFrame.CollectText.Text = string.format('%d/%d(Cash + %d%%)', cur, total , boost * shared.Config.COIN_COLLECTIONBOOST)
    self.CollectionFrame.InnerBarFrame.Size = UDim2.new(math.min(1, cur / total), 0, 1, 0)
end

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end

return self
