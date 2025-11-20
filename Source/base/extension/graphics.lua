-- Modular Kart Class 2 CSP Graphics Script
-- Authored by ohyeah2389

local helpers = require("helpers")

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
    self.sampleSum = self.sampleSum + dt
    self.sampleCount = self.sampleCount + 1

    if self.sampleCount >= self.sampleLimit then
        local averageDt = self.sampleSum / self.sampleCount
        self.isActive = averageDt < self.threshold
        self.sampleCount = 0
        self.sampleSum = 0
    end
end


-- Configuration table for customizable parts
local partConfigurations = {
    wheel = {
        setupKeySuffix = '.wheel',
        options = {
            [0] = {"SteeringWheelClassic"},
            [1] = {"SteeringWheelModern"},
            [2] = {"SteeringWheelOTK"},
            [3] = {"SteeringWheelRetro"}
        }
    },
    nassau = {
        setupKeySuffix = '.nassau',
        options = {
            [0] = {"OTK M11 Nassau"},
            [1] = {"OTK M7 Nassau"},
            [2] = {"OTK M6 Nassau"},
            [3] = {"KG508_Nassau"},
            [4] = {"Eurostar Dynamica Nassau"},
            [5] = {"KG Buru Nassau"},
            [6] = {"KG 509 Nassau"},
            [7] = {"KR DynEvo Nassau"},
            [8] = {"OvalNassau"},
            [9] = {"MetalFairingNassau"},
            [100] = {} -- hide all
        }
    },
    frontBumper = {
        setupKeySuffix = '.frontBumper',
        options = {
            [0] = {"OTK M11 Nosecone"},
            [1] = {"OTK M6 Nosecone"},
            [2] = {"KG506 Nosecone"},
            [3] = {"KG Buru Nosecone"},
            [4] = {"KG FP7 Nosecone"},
            [5] = {"KR DynEvo Nosecone"},
            [6] = {"OvalNosecone"},
            [100] = {} -- hide all
        }
    },
    rearBumper = {
        setupKeySuffix = '.rearBumper',
        options = {
            [0] = {"RearBumperMount"},
            [1] = {"RearBumperMetalNew"},
            [2] = {"RearBumperMetalOld"},
            [100] = {} -- hide all
        }
    },
    sidepod = {
        setupKeySuffix = '.sidepod',
        options = {
            [0] = {"OTK M10 Sidepod Left", "OTK M10 Sidepod Right"},
            [1] = {"OTK M6 Sidepod Left", "OTK M6 Sidepod Right"},
            [2] = {"KR DynEvo Sidepod Right", "KR DynEvo Sidepod Left"},
            [3] = {"OvalSidepodRight", "OvalSidepodLeft"},
            [4] = {"SidepodMetal_L", "SidepodMetal_R"},
            [100] = {} -- hide all
        }
    }
}

local baseSetupKey = 'modkart_c2_shared_' .. car.index


local function updatePartVisibility(partConfig)
    local setupItem = ac.load(baseSetupKey .. partConfig.setupKeySuffix) or 0 -- Default to 0

    -- Iterate through all defined options for this part type
    for optionValue, nodeNames in pairs(partConfig.options) do
        -- Determine if this option is the one selected in the setup
        local isVisible = (optionValue == setupItem)
        -- Set visibility for all nodes associated with this option
        for _, nodeName in ipairs(nodeNames) do
            local node = ac.findNodes(nodeName)
            -- Check if node exists before trying to set visibility
            if node then
                node:setVisible(isVisible)
            end
        end
    end
end


local frameRateChecker = FrameRateChecker()
local DriverAnimator = require("driver_animator")
local KartAnimator = require("kart_animator")
local driverAnimator = DriverAnimator()
local kartAnimator = KartAnimator()

local antiResetAdder = 0

local carNode = ac.findNodes("BODYTR")
local tierodLTarget = ac.findNodes("DIR2_anim_tierodLF")
local tierodRTarget = ac.findNodes("DIR2_anim_tierodRF")
local tierodLControl = ac.findNodes("DIR_anim_tierodLF")
local tierodRControl = ac.findNodes("DIR_anim_tierodRF")


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

        if car.extraD then
            driverAnimator:setState("leanForward", true, true)
        else
            driverAnimator:setState("leanForward", false, true)
        end

        driverAnimator:update(dt, antiResetAdder)
        kartAnimator:update(dt, angularAcceleration)
    end

    tierodLControl:setPosition(helpers.getPositionInCarFrame(tierodLTarget, carNode))
    tierodRControl:setPosition(helpers.getPositionInCarFrame(tierodRTarget, carNode))

    -- Update visibility for all configured parts
    if sim.isInMainMenu then
        for _, partConfig in pairs(partConfigurations) do
            updatePartVisibility(partConfig)
        end
    end
end