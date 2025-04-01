local Physics = require("physics_classes")
local helpers = require("helpers")

local NodeAnimator = class("NodeAnimator")

function NodeAnimator:initialize(params)
    self.node = ac.findNodes(params.nodeName)
    self.node:storeCurrentTransformation()
    self.originalLook = self.node:getLook()
    self.originalUp = self.node:getUp()
    self.originalPosition = self.node:getPosition()
    self.physics = Physics(params)
    self.vibration = params.vibration or 0
    self.flipped = params.flipped or false

    self.vibration_angle = 0
end


function NodeAnimator:update(forceInput, bounceDir, translationDir, dt)
    local force = forceInput * self.physics.mass

    local angular_velocity = (car.rpm / 60 / 2) * (2 * math.pi)
    self.vibration_angle = self.vibration_angle + angular_velocity * dt
    self.vibration_angle = math.fmod(self.vibration_angle, 2 * math.pi)

    local vibration_force = self.vibration * math.sin(self.vibration_angle) * helpers.mapRange(car.rpm, 0, 200, 0, 1, true) * helpers.mapRange(car.rpm, 4000, 6000, 1, 0, true)

    local animationPos = self.physics:step(force + vibration_force, dt)

    local bounceValue = animationPos * (self.flipped and -1 or 1)
    self.node:setOrientation(self.originalLook + bounceValue * bounceDir, self.originalUp)
    self.node:setPosition(self.originalPosition + (translationDir * bounceValue))
end

return NodeAnimator 