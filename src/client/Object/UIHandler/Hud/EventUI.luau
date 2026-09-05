local self : any = {WinTime = 0, PowerTime = 0, LuckTime = 0}

function self.Init(main)
	self.Main = shared.Frame.new(main.Hud.Event)
    self.Main:Visible(true)

    self.TimerFrame = self.Main.Frame.Timer
    self.BuffFrame = self.Main.Frame.Buff
    self.EventLabel = self.Main.Frame.Timer.desc
    self.TimerLabel = self.Main.Frame.Timer.timer

    for k, child in self.BuffFrame:GetChildren() do
        if child:IsA('ImageButton') then
            child.Visible = false
            child.MouseButton1Click:Connect(function()
                for _, v in self.BuffFrame:GetChildren() do if v:IsA('ImageButton') then v.Tips.Visible = false end end

                child.Tips.Visible = true

                task.delay(2, function() child.Tips.Visible = false end)
            end)
        end
    end
end

function self.Update(eventData)
    -- print(eventData)
    StartEventTick(eventData)
    if eventData.CurEvent ~= nil then
        self.Event(eventData.CurEvent, eventData.EventEndTime)
    end
    if eventData.ServerLuckEndTime then
        self.Event('Luck', eventData.ServerLuckEndTime)
    end
end

function self.EndEvent(buffName)
    local frame = self.BuffFrame:FindFirstChild(buffName)
    if not frame then return end

    self[buffName .. 'Time'] = 0
end

function self.Event(buffName, time)
    -- print('start task')
    if buffName == nil or time == nil then return end
    local frame = self.BuffFrame:FindFirstChild(buffName)
    if not frame then return end
    frame.Visible = true
    
    self[buffName .. 'Time'] = time 

    if self[buffName .. 'Running'] == true then return end
    self[buffName .. 'Running'] = true

    while true do
        local remain = math.ceil(self[buffName .. 'Time'] - workspace:GetServerTimeNow())
        if remain <= 0 then break end

        frame.Time.Text = shared.Tool.FormatTime(remain)

        task.wait(.2)
    end

    self[buffName .. 'Running'] = false
    frame.Visible = false
end

function StartEventTick(event)
    self.TimerFrame.Visible = true
    self.EventLabel.Text = event.NextEvent .. ' In'
    if self.FreeTickTask then return end
    self.FreeTickTask = task.spawn(function()
        local endTime = event.NextEventTime
        while true do
            local remain = math.ceil(endTime - workspace:GetServerTimeNow())
            if remain <= 0 then 
                endTime += shared.Config.EVENT_INTERVAL
            end

            self.TimerLabel.Text = shared.Tool.FormatTime(remain)

            task.wait(.2)
        end 
    end)
end

return self
