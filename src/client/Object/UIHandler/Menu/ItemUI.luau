local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemData = require(ReplicatedStorage.Datas.ItemData :: ModuleScript)

local self : any = {}

function self.start()
    shared.LeftUI.ItemBtnClickedEvent:Connect(function()
        local data = shared.PlayerDataHandler.GetData()
        self.Update(data.Item.Inv)
        self:Open()
    end)
end

function self.Init(main)
	self.Main = shared.Frame.new(main.Menu.Items)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame.Frame
    self.ScrollingFrame = self.Frame.ScrollingFrame
    self.Title = self.Frame.Title

    self.Title.Close.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Fail')
        self:Close()
    end)
end

function self.Update(itemInv)
    for _, slot in self.ScrollingFrame:GetChildren() do
        if slot:IsA('ImageButton') then
            slot:Destroy()
        end
    end

    for id, amount in itemInv do
        id = tonumber(id)
        local staticData = ItemData[id]
        local slot = ReplicatedStorage.Assets.UI.ItemSlot:FindFirstChild(staticData.Quality):Clone()
        slot.Icon.Image = staticData.Icon
        slot.ItemNameText.Text = staticData.Name
        slot.ItemCountText.Text = 'x' .. tostring(amount)
        slot.Parent = self.ScrollingFrame
    end
end

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end


return self
