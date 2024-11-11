-- Modular Kart Class 2 CSP Graphics Script
-- Authored by ohyeah2389

local helpers = require("graphics_helpers")
local physObj = class("PhysObj")


--local sharedData = ac.connect({
--    ac.StructItem.key('modkart_c2_shared_' .. car.index),
--    setupWheel = ac.StructItem.int8(),
--}, true, ac.SharedNamespace.CarDisplay)


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

    if math.isnan(self.position) or math.isnan(self.speed) or math.isnan(self.force) or math.isnan(self.accel) then
        self.position = self.center
        self.speed = 0
        self.force = 0
        self.accel = 0
        self.friction = 0
    end

    return self.position
end


local BouncerObject = class("BouncerObject")


function BouncerObject:initialize(params)
    self.node = ac.findNodes(params.nodeName)
    self.node:storeCurrentTransformation()
    self.originalLook = self.node:getLook()
    self.originalUp = self.node:getUp()
    self.originalPosition = self.node:getPosition()
    self.physics = physObj(params)
    self.flipped = params.flipped or false
end


function BouncerObject:update(forceInput, bounceDir, translationDir, dt)
    local bounceValue = self.physics:step(forceInput, dt) * (self.flipped and -1 or 1)
    local bounceAmount = bounceDir * bounceValue
    self.node:setOrientation(self.originalLook + bounceAmount, self.originalUp)
    self.node:setPosition(self.originalPosition + (translationDir * bounceValue))
end


local driverBodyPhys_lat = physObj{
    posMax = 0.9,
    posMin = 0.1,
    center = 0.5,
    mass = 2,
    frictionCoef = 0.4,
    springCoef = 10,
    forceMax = 20,
    constantForce = 0,
    endstopRate = 30
}

local driverBodyPhys_vert = physObj{
    posMax = 0.9,
    posMin = 0.1,
    center = 0.5,
    mass = 3,
    frictionCoef = 0.3,
    springCoef = 30,
    forceMax = 20,
    constantForce = 5,
    endstopRate = 40
}

local driverLegPhys_L = physObj{
    posMax = 0.8,
    posMin = 0.2,
    center = 0.5,
    mass = 2,
    frictionCoef = 0.4,
    springCoef = 15,
    forceMax = 20,
    constantForce = 0,
    endstopRate = 50
}

local driverLegPhys_R = physObj{
    posMax = 0.8,
    posMin = 0.2,
    center = 0.5,
    mass = 3,
    frictionCoef = 0.3,
    springCoef = 30,
    forceMax = 20,
    constantForce = 0,
    endstopRate = 50
}

local brakeDiscPhys = physObj{
    posMax = 1,
    posMin = -1,
    center = 0,
    mass = 0.5,
    frictionCoef = 0.3,
    springCoef = 0,
    forceMax = 30,
    constantForce = 0,
    endstopRate = 50
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

local bumperRearBouncer = BouncerObject{
    nodeName = "RearBumperPlastic",
    posMax = 0.05,
    posMin = -0.05,
    center = 0,
    mass = 1,
    frictionCoef = 0.2,
    springCoef = 0,
    forceMax = 50,
    constantForce = -0.5,
    endstopRate = 50,
    flipped = false
}

local bumperRearVerticalBouncer = BouncerObject{
    nodeName = "RearBumperBracket",
    posMax = 0.02,
    posMin = -0.01,
    center = 0,
    mass = 0.5,
    frictionCoef = 0.4,
    springCoef = 0,
    forceMax = 100,
    constantForce = -0.1,
    endstopRate = 100,
    flipped = false
}

local bumperRearAxialRotatorBouncer = BouncerObject{
    nodeName = "RearBumperBracketRotator",
    posMax = 0.0,
    posMin = -0.0,
    center = 0,
    mass = 0.5,
    frictionCoef = 0.6,
    springCoef = 0.2,
    forceMax = 100,
    constantForce = 0,
    endstopRate = 50,
    flipped = false
}


local previousAngularVelocity = vec3(0, 0, 0)


local function updateAngularAcceleration(dt)
    local currentAngularVelocity = vec3(car.angularVelocity.x, car.angularVelocity.y, car.angularVelocity.z)
    local angularAcceleration = helpers.calculateAngularAcceleration(currentAngularVelocity, previousAngularVelocity, dt)
    previousAngularVelocity = currentAngularVelocity
    return angularAcceleration
end


local function driverAnimation(dt)
    local driverModel = ac.findNodes("DRIVER:DRIVER")

    driverModel:setAnimation("../animations/latG.ksanim", driverBodyPhys_lat:step(car.acceleration.x, dt))
    driverModel:setAnimation("../animations/vertG.ksanim", driverBodyPhys_vert:step(-car.acceleration.y, dt))
end


local function bumperAnimation(dt)
    local angularAcceleration = updateAngularAcceleration(dt)

    sidepodBouncerRight:update((car.acceleration.y * 0.1) + (angularAcceleration.z * 0.01), vec3(1, 0, 0), vec3(0, 0, 0), dt)
    sidepodBouncerLeft:update((car.acceleration.y * 0.1) + (angularAcceleration.z * -0.01), vec3(1, 0, 0), vec3(0, 0, 0), dt)

    bumperRearBouncer:update((car.acceleration.y * 0.2), vec3(0, 1, 0), vec3(0, 0, 0), dt)

    bumperRearAxialRotatorBouncer:update((angularAcceleration.z * 0.03), vec3(1, 0, 0), vec3(0, 0, 0), dt)

    bumperRearVerticalBouncer:update((car.acceleration.y * 0.1), vec3(0, 0, 0), vec3(0, 0, 1), dt)
end


local function wheelSelection()
    local setupItem = ac.load('modkart_c2_shared_' .. car.index .. '.wheel') or 0
    local wheelClassic = ac.findNodes("SteeringWheelClassic")
    local wheelModern = ac.findNodes("SteeringWheelModern")

    if setupItem == 0 then
        wheelClassic:setVisible(true)
        wheelModern:setVisible(false)
    elseif setupItem == 1 then
        wheelClassic:setVisible(false)
        wheelModern:setVisible(true)
    end
end


local driverFoot_L = ac.findNodes("DRIVER:RIG_Hill_L")
local driverFoot_R = ac.findNodes("DRIVER:RIG_Hill_R")

local driverShin_L = ac.findNodes("DRIVER:RIG_Shin_L")
local driverShin_R = ac.findNodes("DRIVER:RIG_Shin_R")

local driverLeg_L = ac.findNodes("DRIVER:RIG_Leg_L")
local driverLeg_R = ac.findNodes("DRIVER:RIG_Leg_R")

local pedalGas = ac.findNodes("PedalGas")
local pedalBrake = ac.findNodes("PedalBrake")

local brakeLever = ac.findNodes("BrakeLever")
local brakeDisc = ac.findNodes("BrakeDiscTabs")
local brakePad1 = ac.findNodes("BrakePad.001")
local brakePad2 = ac.findNodes("BrakePad.002")

driverFoot_L:storeCurrentTransformation()
driverFoot_R:storeCurrentTransformation()

driverShin_L:storeCurrentTransformation()
driverShin_R:storeCurrentTransformation()

driverLeg_L:storeCurrentTransformation()
driverLeg_R:storeCurrentTransformation()

pedalGas:storeCurrentTransformation()
pedalBrake:storeCurrentTransformation()

brakeLever:storeCurrentTransformation()
brakeDisc:storeCurrentTransformation()
brakePad1:storeCurrentTransformation()
brakePad2:storeCurrentTransformation()

local driverFoot_L_forward, driverFoot_L_up = driverFoot_L:getLook(), driverFoot_L:getUp()
local driverFoot_R_forward, driverFoot_R_up = driverFoot_R:getLook(), driverFoot_R:getUp()

local driverShin_L_forward, driverShin_L_up = driverShin_L:getLook(), driverShin_L:getUp()
local driverShin_R_forward, driverShin_R_up = driverShin_R:getLook(), driverShin_R:getUp()

local driverLeg_L_forward, driverLeg_L_up = driverLeg_L:getLook(), driverLeg_L:getUp()
local driverLeg_R_forward, driverLeg_R_up = driverLeg_R:getLook(), driverLeg_R:getUp()

local pedalGas_forward, pedalGas_up = pedalGas:getLook(), pedalGas:getUp()
local pedalBrake_forward, pedalBrake_up = pedalBrake:getLook(), pedalBrake:getUp()

local brakeLever_forward, brakeLever_up = brakeLever:getLook(), brakeLever:getUp()
local brakeDisc_position = brakeDisc:getPosition()
local brakePad1_position = brakePad1:getPosition()
local brakePad2_position = brakePad2:getPosition()


local function driverLegsAnimation(dt)
    local driverBodyVertPos = driverBodyPhys_vert.position - 0.5
    local driverBodyLatPos = driverBodyPhys_lat.position - 0.5

    local driverLeg_L_pos = driverLegPhys_L:step(car.acceleration.x, dt) - 0.5
    local driverLeg_R_pos = driverLegPhys_R:step(car.acceleration.x, dt) - 0.5

    driverFoot_L:setOrientation(driverFoot_L_forward + vec3(0, 0, (car.brake * 0.15) - 0.03), driverFoot_L_up)
    driverFoot_R:setOrientation(driverFoot_R_forward + vec3(0, 0, (car.gas * 0.32) + 0.05), driverFoot_R_up)

    driverShin_L:setOrientation(driverShin_L_forward + vec3(0 + (driverLeg_L_pos * 0.2), 0, (car.brake * 0.05) - 0.1 + (driverBodyVertPos * -0.2)), driverShin_L_up)
    driverShin_R:setOrientation(driverShin_R_forward + vec3(0 + (driverLeg_R_pos * 0.2), 0, (car.gas * 0.2) - 0.2 + (driverBodyVertPos * -0.2)), driverShin_R_up)

    driverLeg_L:setOrientation(driverLeg_L_forward + vec3(0 + (driverLeg_L_pos * 0.15), 0, (car.brake * 0.025) - 0.1), driverLeg_L_up + vec3(driverLeg_L_pos * -0.25, driverLeg_L_pos * -0.6, 0))
    driverLeg_R:setOrientation(driverLeg_R_forward + vec3(-0.03 + (driverLeg_R_pos * 0.15), 0, (car.gas * 0.08) - 0.15), driverLeg_R_up + vec3(driverLeg_R_pos * -0.3, driverLeg_R_pos * 0.6, 0))

    pedalBrake:setOrientation(pedalBrake_forward + vec3(0, 0, car.brake * 0.2), pedalBrake_up)
    pedalGas:setOrientation(pedalGas_forward + vec3(0, 0, car.gas * 0.4), pedalGas_up)
end


local function brakeDiscAnimation(dt)
    brakeDisc:setPosition(brakeDisc_position + vec3(0, 0, brakeDiscPhys:step(math.random(-1, 1) * car.speedKmh, dt) * helpers.mapRange(car.brake, 0, 0.2, 1, 0, true) * 0.0003))

    brakePad1:setPosition(brakePad1_position + vec3(helpers.mapRange(car.brake, 0, 0.2, 0, -0.001, true), 0, 0))
    brakePad2:setPosition(brakePad2_position + vec3(helpers.mapRange(car.brake, 0, 0.2, 0, 0.001, true), 0, 0))
end


local function nonPhysicsAnimation(dt)
    brakeLever:setOrientation(brakeLever_forward, brakeLever_up + vec3(0, car.brake * 0.47, 0))
end


local frameRateCheck = {
    sampleCount = 0,
    sampleSum = 0,
    sampleLimit = 10,  -- Number of frames to average
    threshold = 1/40,  -- Threshold for activating/deactivating animations
    isActive = true
}


---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.boostFrameRate()
    ac.updateDriverModel()

    if (dt == 0) or (math.abs(sim.timeToSessionStart) < 3000) then
        frameRateCheck.isActive = false
    else
        frameRateCheck.sampleSum = frameRateCheck.sampleSum + dt
        frameRateCheck.sampleCount = frameRateCheck.sampleCount + 1

        if frameRateCheck.sampleCount >= frameRateCheck.sampleLimit then
            local averageDt = frameRateCheck.sampleSum / frameRateCheck.sampleCount

            if averageDt < frameRateCheck.threshold then
                frameRateCheck.isActive = true
            else
                frameRateCheck.isActive = false
            end

            frameRateCheck.sampleCount = 0
            frameRateCheck.sampleSum = 0
        end
    end

    if frameRateCheck.isActive then
        bumperAnimation(dt)
        driverAnimation(dt)
        brakeDiscAnimation(dt)
        driverLegsAnimation(dt)
    end

    nonPhysicsAnimation(dt)

    local carNode = ac.findNodes("BODYTR")
    local tierodL_target = ac.findNodes("DIR2_anim_tierodLF")
    local tierodR_target = ac.findNodes("DIR2_anim_tierodRF")
    local tierodL_control = ac.findNodes("DIR_anim_tierodLF")
    local tierodR_control = ac.findNodes("DIR_anim_tierodRF")

    tierodL_control:setPosition(helpers.getPositionInCarFrame(tierodL_target, carNode))
    tierodR_control:setPosition(helpers.getPositionInCarFrame(tierodR_target, carNode))

    wheelSelection()
end