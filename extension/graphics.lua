-- Modular Kart Class 2 CSP Graphics Script
-- Authored by ohyeah2389

local helpers = require("graphics_helpers")


local physObj = class("PhysObj")


function physObj:initialize(params)
    self.posMax = params.posMax
    self.posMin = params.posMin
    self.center = params.center
    self.position = params.center
    self.speed = 0
    self.force = 0
    self.accel = 0
    self.frictionCoef = params.frictionCoef or 0.1
    self.friction = self.speed * self.frictionCoef
    self.mass = params.mass
    self.springCoef = params.springCoef
    self.forceMax = params.forceMax
    self.constantForce = params.constantForce or 0
    self.endstopRate = params.endstopRate or 1  -- Default value if not provided
end


function physObj:step(force, dt)
    local distanceFromCenter = self.position - self.center
    self.force = math.clamp(-force * self.mass, -self.forceMax, self.forceMax) + (distanceFromCenter * -self.springCoef) + self.constantForce
    self.position = self.position + (self.speed * dt)
    
    if self.position > self.posMax then
        local overshoot = self.position - self.posMax
        local endstopForce = overshoot * self.endstopRate
        self.force = math.clamp(self.force - endstopForce, -self.forceMax, self.forceMax)
    elseif self.position < self.posMin then
        local overshoot = self.posMin - self.position
        local endstopForce = overshoot * self.endstopRate
        self.force = math.clamp(self.force + endstopForce, -self.forceMax, self.forceMax)
    end
    
    self.accel = self.force / self.mass
    self.speed = self.speed + self.accel
    self.friction = self.speed * self.frictionCoef
    self.speed = self.speed - self.friction

    return self.position
end


local BouncerObject = class("BouncerObject")


function BouncerObject:initialize(params)
    self.node = ac.findNodes(params.nodeName)
    self.node:storeCurrentTransformation()
    self.originalLook = self.node:getLook()
    self.originalUp = self.node:getUp()
    self.physics = physObj(params)
    self.flipped = params.flipped or false
end


function BouncerObject:update(forceInput, dt)
    local bounceValue = self.physics:step(forceInput, dt) * (self.flipped and -1 or 1)
    self.node:setOrientation(self.originalLook + vec3(bounceValue, 0, 0), self.originalUp)
end


local driverBodyPhys_lat = physObj{
    posMax = 1,
    posMin = 0,
    center = 0.5,
    mass = 4,
    frictionCoef = 0.2,
    springCoef = 16,
    forceMax = 20,
    constantForce = 0,
    endstopRate = 8
}

local driverBodyPhys_vert = physObj{
    posMax = 1,
    posMin = 0,
    center = 0.5,
    mass = 5,
    frictionCoef = 0.25,
    springCoef = 10,
    forceMax = 10,
    constantForce = 0,
    endstopRate = 10
}

local sidepodBouncerRight = BouncerObject{
    nodeName = "SidepodBouncerRight",
    posMax = 0.008,
    posMin = -0.008,
    center = 0,
    mass = 2,
    frictionCoef = 0.25,
    springCoef = 0,
    forceMax = 50,
    constantForce = -0.2,
    endstopRate = 30,
    flipped = false
}

local sidepodBouncerLeft = BouncerObject{
    nodeName = "SidepodBouncerLeft",
    posMax = 0.008,
    posMin = -0.008,
    center = 0,
    mass = 2,
    frictionCoef = 0.25,
    springCoef = 0,
    forceMax = 50,
    constantForce = -0.2,
    endstopRate = 30,
    flipped = true
}


-- Store the previous angular velocity
local previousAngularVelocity = vec3(0, 0, 0)

-- Function to update angular acceleration
local function updateAngularAcceleration(dt)
    local currentAngularVelocity = vec3(car.angularVelocity.x, car.angularVelocity.y, car.angularVelocity.z)
    local angularAcceleration = helpers.calculateAngularAcceleration(currentAngularVelocity, previousAngularVelocity, dt)
    previousAngularVelocity = currentAngularVelocity
    return angularAcceleration
end


local function getPositionInCarFrame(node, carNode)
    local carTransform = carNode:getTransformationRaw()
    local carTransformInv = carTransform:inverse()
    local nodeWorldPos = node:getWorldTransformationRaw():transformPoint(vec3())
    return carTransformInv:transformPoint(nodeWorldPos)
end


local function getOrientationInCarFrame(node, carNode)
    local carTransform = carNode:getTransformationRaw()
    local nodeWorldTransform = node:getWorldTransformationRaw()
    
    -- Extract rotation matrices
    local carRotation = mat3x3(
        vec3(carTransform.row1.x, carTransform.row1.y, carTransform.row1.z),
        vec3(carTransform.row2.x, carTransform.row2.y, carTransform.row2.z),
        vec3(carTransform.row3.x, carTransform.row3.y, carTransform.row3.z)
    )
    local nodeRotation = mat3x3(
        vec3(nodeWorldTransform.row1.x, nodeWorldTransform.row1.y, nodeWorldTransform.row1.z),
        vec3(nodeWorldTransform.row2.x, nodeWorldTransform.row2.y, nodeWorldTransform.row2.z),
        vec3(nodeWorldTransform.row3.x, nodeWorldTransform.row3.y, nodeWorldTransform.row3.z)
    )
    
    -- Manually transpose carRotation
    local carRotationTransposed = mat3x3(
        vec3(carRotation.row1.x, carRotation.row2.x, carRotation.row3.x),
        vec3(carRotation.row1.y, carRotation.row2.y, carRotation.row3.y),
        vec3(carRotation.row1.z, carRotation.row2.z, carRotation.row3.z)
    )
    
    -- Manually multiply matrices
    local relativeRotation = mat3x3(
        vec3(
            carRotationTransposed.row1.x * nodeRotation.row1.x + carRotationTransposed.row1.y * nodeRotation.row2.x + carRotationTransposed.row1.z * nodeRotation.row3.x,
            carRotationTransposed.row1.x * nodeRotation.row1.y + carRotationTransposed.row1.y * nodeRotation.row2.y + carRotationTransposed.row1.z * nodeRotation.row3.y,
            carRotationTransposed.row1.x * nodeRotation.row1.z + carRotationTransposed.row1.y * nodeRotation.row2.z + carRotationTransposed.row1.z * nodeRotation.row3.z
        ),
        vec3(
            carRotationTransposed.row2.x * nodeRotation.row1.x + carRotationTransposed.row2.y * nodeRotation.row2.x + carRotationTransposed.row2.z * nodeRotation.row3.x,
            carRotationTransposed.row2.x * nodeRotation.row1.y + carRotationTransposed.row2.y * nodeRotation.row2.y + carRotationTransposed.row2.z * nodeRotation.row3.y,
            carRotationTransposed.row2.x * nodeRotation.row1.z + carRotationTransposed.row2.y * nodeRotation.row2.z + carRotationTransposed.row2.z * nodeRotation.row3.z
        ),
        vec3(
            carRotationTransposed.row3.x * nodeRotation.row1.x + carRotationTransposed.row3.y * nodeRotation.row2.x + carRotationTransposed.row3.z * nodeRotation.row3.x,
            carRotationTransposed.row3.x * nodeRotation.row1.y + carRotationTransposed.row3.y * nodeRotation.row2.y + carRotationTransposed.row3.z * nodeRotation.row3.y,
            carRotationTransposed.row3.x * nodeRotation.row1.z + carRotationTransposed.row3.y * nodeRotation.row2.z + carRotationTransposed.row3.z * nodeRotation.row3.z
        )
    )
    
    -- Extract the forward and up vectors from the relative rotation
    local forward = vec3(relativeRotation.row3.x, relativeRotation.row3.y, relativeRotation.row3.z):normalize()
    local up = vec3(relativeRotation.row2.x, relativeRotation.row2.y, relativeRotation.row2.z):normalize()
    
    return forward, up
end


---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.boostFrameRate()

    local debugAddition = (math.sin(os.clock() * 2.0))

    local angularAcceleration = updateAngularAcceleration(dt)

    ac.updateDriverModel()

    local driverModel = ac.findNodes("DRIVER:DRIVER")

    --ac.findNodes("DRIVER:DRIVER"):setAnimation("../animations/carb.ksanim", animTest) -- needs proper easing instead of snapping to value
    --if animTest == 0 then ac.findNodes("DRIVER:DRIVER"):setAnimation("../animations/steer.ksanim", (car.steer / -720) + 0.5) end
    driverModel:setAnimation("../animations/brake.ksanim", 1 - car.brake)
    driverModel:setAnimation("../animations/throttle.ksanim", 1 - car.gas)
    driverModel:setAnimation("../animations/latG.ksanim", driverBodyPhys_lat:step(car.acceleration.x, dt))
    driverModel:setAnimation("../animations/vertG.ksanim", driverBodyPhys_vert:step(-car.acceleration.y, dt))

    sidepodBouncerRight:update((car.acceleration.y * 0.06) + (angularAcceleration.z * 0.03), dt)
    sidepodBouncerLeft:update((car.acceleration.y * 0.06) + (angularAcceleration.z * -0.03), dt)

    local carNode = ac.findNodes("BODYTR")
    local tierodL_target = ac.findNodes("DIR2_anim_tierodLF")
    local tierodR_target = ac.findNodes("DIR2_anim_tierodRF")
    local tierodL_control = ac.findNodes("DIR_anim_tierodLF")
    local tierodR_control = ac.findNodes("DIR_anim_tierodRF")

    tierodL_control:setPosition(getPositionInCarFrame(tierodL_target, carNode))
    tierodR_control:setPosition(getPositionInCarFrame(tierodR_target, carNode))
end