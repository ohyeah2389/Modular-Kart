-- Modular Kart Class 2 CSP Graphics Script
-- Authored by ohyeah2389

local helpers = require("helpers")
local NodeAnimator = require("node_animator")
local Physics = require("physics_classes")


--local sharedData = ac.connect({
--    ac.StructItem.key('modkart_c2_shared_' .. car.index),
--    setupWheel = ac.StructItem.int8(),
--}, true, ac.SharedNamespace.CarDisplay)


local previousAngularVelocity = vec3(0, 0, 0)
local angularAcceleration = vec3(0, 0, 0)


local function updateAngularAcceleration(dt)
    local currentAngularVelocity = vec3(car.angularVelocity.x, car.angularVelocity.y, car.angularVelocity.z)
    previousAngularVelocity = currentAngularVelocity
    return helpers.calculateAngularAcceleration(currentAngularVelocity, previousAngularVelocity, dt)
end


local FrameRateChecker = class("FrameRateChecker")
function FrameRateChecker:initialize()
    self.sampleCount = 0
    self.sampleSum = 0
    self.sampleLimit = 10  -- Number of frames to average
    self.threshold = 1/40  -- if frametime is less than this threshold, isActive is set to false
    self.isActive = true
end


function FrameRateChecker:update(dt)
    if (dt == 0) or (math.abs(sim.timeToSessionStart) < 3000) then
        self.isActive = false
        return
    end

    self.sampleSum = self.sampleSum + dt
    self.sampleCount = self.sampleCount + 1

    if self.sampleCount >= self.sampleLimit then
        local averageDt = self.sampleSum / self.sampleCount
        self.isActive = averageDt < self.threshold
        self.sampleCount = 0
        self.sampleSum = 0
    end
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


local function nassauSelection()
    local setupItem = ac.load('modkart_c2_shared_' .. car.index .. '.nassau') or 0
    local nassauOTK = ac.findNodes("OTK M7 Nassau")
    local nassauKG = ac.findNodes("KG508_Nassau")
    local nassauEuro = ac.findNodes("Eurostar Dynamica Nassau")

    if setupItem == 0 then
        nassauOTK:setVisible(true)
        nassauKG:setVisible(false)
        nassauEuro:setVisible(false)
    elseif setupItem == 1 then
        nassauOTK:setVisible(false)
        nassauKG:setVisible(true)
        nassauEuro:setVisible(false)
    elseif setupItem == 2 then
        nassauOTK:setVisible(false)
        nassauKG:setVisible(false)
        nassauEuro:setVisible(true)
    end
end


local function frontBumperSelection()
    local setupItem = ac.load('modkart_c2_shared_' .. car.index .. '.frontBumper') or 0
    local frontBumperOTK = ac.findNodes("OTK M6 Nosecone")
    local frontBumperKG = ac.findNodes("KG506 Nosecone")

    if setupItem == 0 then
        frontBumperOTK:setVisible(true)
        frontBumperKG:setVisible(false)
    elseif setupItem == 1 then
        frontBumperOTK:setVisible(false)
        frontBumperKG:setVisible(true)
    end
end


local frameRateChecker = FrameRateChecker()
local DriverAnimator = require("driver_animator")
local KartAnimator = require("kart_animator")
local driverAnimator = DriverAnimator()
local kartAnimator = KartAnimator()

local antiResetAdder = 0


---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.boostFrameRate()
    ac.updateDriverModel()

    antiResetAdder = (antiResetAdder + 1) % 2
    ac.debug("antiResetAdder", antiResetAdder)

    frameRateChecker:update(dt)
    angularAcceleration = updateAngularAcceleration(dt)
    ac.debug("angularAcceleration.x", angularAcceleration.x)
    ac.debug("angularAcceleration.y", angularAcceleration.y)
    ac.debug("angularAcceleration.z", angularAcceleration.z)
    ac.debug("car.acceleration.x", car.acceleration.x)
    ac.debug("car.acceleration.y", car.acceleration.y)
    ac.debug("car.acceleration.z", car.acceleration.z)

    if frameRateChecker.isActive then
        if car.extraC then
            driverAnimator:setState("handUp", true, true)
        else
            driverAnimator:setState("handUp", false, true)
        end

        driverAnimator:update(dt, antiResetAdder)
        kartAnimator:update(dt, angularAcceleration)
    end

    local carNode = ac.findNodes("BODYTR")
    local tierodLTarget = ac.findNodes("DIR2_anim_tierodLF")
    local tierodRTarget = ac.findNodes("DIR2_anim_tierodRF")
    local tierodLControl = ac.findNodes("DIR_anim_tierodLF")
    local tierodRControl = ac.findNodes("DIR_anim_tierodRF")

    tierodLControl:setPosition(helpers.getPositionInCarFrame(tierodLTarget, carNode))
    tierodRControl:setPosition(helpers.getPositionInCarFrame(tierodRTarget, carNode))

    wheelSelection()
    nassauSelection()
    frontBumperSelection()
end