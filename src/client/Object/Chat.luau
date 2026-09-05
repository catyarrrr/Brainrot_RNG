local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local self = {}

function self.init()
    self.TextChannels = TextChatService:WaitForChild('TextChannels')
    self.GeneralChannel = self.TextChannels:WaitForChild('RBXGeneral')
end

function self.start()
    ReplicatedStorage.Remote.Message.OnClientEvent:Connect(function(player)
        local name = player.DisplayName
	    local text = string.format('<font color="#00FF00"><b>%s</b></font> activated <font color="#FF0000">Server Luck</font>! Everyone now has a higher chance of getting rare Aliens!', name)
        self.Message(text)
    end)
    ReplicatedStorage.Remote.ServerMessage.OnClientEvent:Connect(function(text)
        text = string.format('<font color="#FF0004"><b>%s</b></font>', text)
        self.Message(text)
    end)
end

function self.Message(text)
    self.GeneralChannel:DisplaySystemMessage(text)
end

return self