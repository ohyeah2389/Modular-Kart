local Physics = require("physics_classes")

local NodeAnimator = class("NodeAnimator")

function NodeAnimator:initialize(params)
    self.node = ac.findNodes(params.nodeName)
    self.node:storeCurrentTransformation()
    self.originalLook = self.node:getLook()
    self.originalUp = self.node:getUp()
    self.originalPosition = self.node:getPosition()
    self.physics = Physics(params)
    self.flipped = params.flipped or false
end


function NodeAnimator:update(forceInput, bounceDir, translationDir, dt)
    local force = forceInput * self.physics.mass
    local animationPos = self.physics:step(force, dt)

    local bounceValue = animationPos * (self.flipped and -1 or 1)
    self.node:setOrientation(self.originalLook + bounceValue * bounceDir, self.originalUp)
    self.node:setPosition(self.originalPosition + (translationDir * bounceValue))
end

return NodeAnimator 