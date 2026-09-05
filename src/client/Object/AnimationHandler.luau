local self = {}

function self.init()
end

function self.start()
end

function self.GetAnimationTrack(model: Model, animatonId)
	local animationController = model:FindFirstChild('AnimationController')
	if not animationController then print('animationController not found'); return end

	local targetAnimation = nil
	if animatonId then
		targetAnimation = Instance.new('Animation')
		targetAnimation.AnimationId = animatonId
	else
		targetAnimation = animationController:FindFirstChild('Animation')
	end

	if not targetAnimation then print('animation not found'); return end 
	
	
	local animator: Animator = animationController.Animator
	local animationTrack : AnimationTrack = animator:LoadAnimation(targetAnimation)
	
	return animationTrack
end

return self
