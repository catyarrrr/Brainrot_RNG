
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local self = {}
self.CameraConn = nil
self.Camera = workspace.CurrentCamera
self.Camera.CameraType = Enum.CameraType.Scriptable

function self.GetCamera()
    local camera = workspace.CurrentCamera

    return camera
end

function self.SetCamera(cframe)
    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Scriptable

    camera.CFrame = cframe
end

function self.TweenCamera(targetCFrame, duration)
    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Scriptable

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(camera, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
end

function self.TweenFOV(oriFOV, newFOV, duration)
    local camera = workspace.CurrentCamera
    camera.FieldOfView = oriFOV or camera.FieldOfView
    TweenService:Create(camera, TweenInfo.new(duration), {
        FieldOfView = newFOV
    }):Play()
end

function self.LookAtPart(targetPart)
    local camera = self.GetCamera()
    if camera.CameraType ~= Enum.CameraType.Scriptable then 
        warn('camera not scriptable'); return 
    end

    if self.CameraConn then
        self.CameraConn:Disconnect()
    end

    if targetPart:IsA('Model') then targetPart = targetPart.PrimaryPart end
    self.CameraConn = RunService.RenderStepped:Connect(function()
        local pos = camera.CFrame.Position
        camera.CFrame = CFrame.lookAt(pos, targetPart.Position)
    end)
end

function self.ResetCamera()
    if self.CameraConn ~= nil then 
        self.CameraConn:Disconnect()
        self.CameraConn = nil
    end
    self.Camera.FieldOfView = 70
    self.Camera.CameraType = Enum.CameraType.Custom
end

function self.InitOri()
    local camera = self.GetCamera()

    camera.CFrame = CFrame.new(camera.CFrame.Position)*CFrame.fromOrientation(math.rad(-30), 0, 0)
end

return self
