local ReplicatedStorage = game:GetService("ReplicatedStorage")

local self = {}

function self.Init(context)
    self.GetData = context.GetData
    self.SetPlayerData = context.SetPlayerData
    self.TowerModule = context.TowerModule
    self.GridModule = context.GridModule
    self.TotemModule = context.TotemModule
end

return self
