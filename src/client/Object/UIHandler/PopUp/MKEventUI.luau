local self : any = {}


function self.Init(frame)
	self.Main = shared.Frame.new(frame.PopUp.MKEvent)
    self.Main:Visible(false)
    
    
    self.Frame = self.Main.Frame.Frame.Frame
    self.Foods = {
        [1] = self.Frame.Mealworm,
        [2] = self.Frame.FriedEgg,
        [3] = self.Frame.SheepTongue,
        [4] = self.Frame.CockroachSalad,
        [5] = self.Frame.OctopusBurger,
    }

    for k, v in self.Foods do v.Locked.Visible = true end
end

function self.Update(dict)
    -- print(dict)
    if dict then self.Main:Visible(true) else self.Main:Visible(false); return end

    for i=1, 5 do
        if dict[tostring(i)] == true then
            self.Foods[i].Locked.Visible = false
            self.Foods[i].ItemCountText.Text = '1/1'
        else
            self.Foods[i].Locked.Visible = true
            self.Foods[i].ItemCountText.Text = '0/1'
        end
    end
end

return self
