local self : any = {}


function self.Init(frame)
	self.Main = shared.Frame.new(frame.DamageFrame)
    self.Main:Visible(false)
    
end

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end


return self
