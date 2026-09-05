local ReplicatedStorage = game:GetService("ReplicatedStorage")
local self = {}

function self.init()
	
end

function self.start()
    game.ServerRestartScheduled:Connect(function(restartTime: DateTime, source: Enum.CloseReason, attributes: { [string]: any })
        local message = attributes and attributes.message or ""

        ReplicatedStorage.Remote.ServerMessage:FireAllClients(message)
    end)
end 

return self