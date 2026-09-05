local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local self = {}

function self.init()
	
end

function self.start()
    
end


function self.TrackOnce(player, eventName)
    local analyticsData = shared.DataStore.GetData(player).Analytics
    if analyticsData and analyticsData[eventName] == false then
        analyticsData[eventName] = true
        AnalyticsService:LogCustomEvent(player, eventName)
    end
end

function self.TrackFunnelOnce(player, step, funnelName, eventName)
    local analyticsData = shared.DataStore.GetData(player).Analytics
    if analyticsData and analyticsData[eventName] == false then
        analyticsData[eventName] = true
        AnalyticsService:LogFunnelStepEvent(player, funnelName, nil, step, eventName)
        -- warn('log event:' .. eventName)
    end
end

return self