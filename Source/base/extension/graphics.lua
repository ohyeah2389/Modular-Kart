-- Modular Kart Class 2 CSP Graphics Script
-- Authored by ohyeah2389

local helpers = require("helpers")
local Physics = require("physics_object")

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
            [0] = {"OTK M11 Nassau Plastic"},
            [1] = {"OTK M7 Nassau Plastic"},
            [2] = {"OTK M6 Nassau Plastic"},
            [3] = {"KG 508 Nassau Plastic"},
            [4] = {"Eurostar Dynamica Nassau Plastic"},
            [5] = {"KG Buru Nassau Plastic"},
            [6] = {"KG 509 Nassau Plastic"},
            [7] = {"KR DynEvo Nassau"},
            [8] = {"Oval Nassau Polycarbonate"},
            [9] = {"Metal Fairing Nassau Metal"},
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

local testLatFlexPhys = {
    posMax = 0.05,
    posMin = -0.05,
    center = 0.0,
    mass = 20.0,
    frictionCoef = 0,
    staticFrictionCoef = 0,
    dampingCoef = 40000,
    springCoef = 80000,
    forceMax = 10000,
    constantForce = 0
}

local testVertFlexPhys = {
    posMax = 0.05,
    posMin = -0.05,
    center = 0.0,
    mass = 40.0,
    frictionCoef = 0,
    staticFrictionCoef = 0,
    dampingCoef = 40000,
    springCoef = 80000,
    forceMax = 10000,
    constantForce = 0
}

local tires = {
    {
        name = "LF",
        base = ac.findNodes("BASE_LF"),
        baseLocalOffset = vec3(0.5, 0.087, 0.466),
        flex = ac.findNodes("FLEX_LF"),
        susp = ac.findNodes("SUSP_LF"),
        latFlexPhys = Physics(testLatFlexPhys),
        vertFlexPhys = Physics(testVertFlexPhys),
        filteredLatFlexInput = 0,
        filteredVertFlexInput = 0,
        canvas = ui.ExtraCanvas(vec2(512, 256)),
        surface = ac.findSkinnedMeshes("Tire_FrontLeft"),
        angle = 0
    },
    {
        name = "RF",
        base = ac.findNodes("BASE_RF"),
        baseLocalOffset = vec3(-0.5, 0.087, 0.466),
        flex = ac.findNodes("FLEX_RF"),
        susp = ac.findNodes("SUSP_RF"),
        latFlexPhys = Physics(testLatFlexPhys),
        vertFlexPhys = Physics(testVertFlexPhys),
        filteredLatFlexInput = 0,
        filteredVertFlexInput = 0,
        canvas = ui.ExtraCanvas(vec2(512, 256)),
        surface = ac.findSkinnedMeshes("Tire_FrontRight"),
        angle = 1
    },
    {
        name = "LR",
        base = ac.findNodes("BASE_LR"),
        baseLocalOffset = vec3(0.6085, 0.087, -0.584),
        flex = ac.findNodes("FLEX_LR"),
        susp = ac.findNodes("SUSP_LR"),
        latFlexPhys = Physics(testLatFlexPhys),
        vertFlexPhys = Physics(testVertFlexPhys),
        filteredLatFlexInput = 0,
        filteredVertFlexInput = 0,
        canvas = ui.ExtraCanvas(vec2(512, 256)),
        surface = ac.findSkinnedMeshes("Tire_RearLeft"),
        angle = 2
    },
    {
        name = "RR",
        base = ac.findNodes("BASE_RR"),
        baseLocalOffset = vec3(-0.6085, 0.087, -0.584),
        flex = ac.findNodes("FLEX_RR"),
        susp = ac.findNodes("SUSP_RR"),
        latFlexPhys = Physics(testLatFlexPhys),
        vertFlexPhys = Physics(testVertFlexPhys),
        filteredLatFlexInput = 0,
        filteredVertFlexInput = 0,
        canvas = ui.ExtraCanvas(vec2(512, 256)),
        surface = ac.findSkinnedMeshes("Tire_RearRight"),
        angle = 3
    }
}

for _, tire in ipairs(tires) do
    tire.base:storeCurrentTransformation()
    tire.flex:storeCurrentTransformation()
    tire.surface:ensureUniqueMaterials()
end

local lastDT = 1
local dtSmoothing = 0.9

local function applyFlexFilter(prev, input, dt, tau)
    -- Exponential smoothing filter (lowpass)
    local alpha = dt / (tau + dt)
    return prev + alpha * (input - prev)
end

local function drawTireSurface(tireSpeed, tireAngle)
    local rotationScalar = (1 / (2 * math.pi)) * 512
    ui.beginBlurring()
    ui.drawImage("dirt.dds", vec2(0 + (tireAngle * rotationScalar), 0), vec2(512 + (tireAngle * rotationScalar), 256), ui.ImageFit.Stretch)
    ui.drawImage("dirt.dds", vec2(-512 + (tireAngle * rotationScalar), 0), vec2(0 + (tireAngle * rotationScalar), 256), ui.ImageFit.Stretch)
    ui.endBlurring(vec2((0.005 * (math.abs(tireSpeed) + 0.001)) ^ 2.5, 0.0))
end

---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.boostFrameRate()
    ac.updateDriverModel()

    dt = math.min(dt, 0.016)

    local smoothDT = (lastDT * dtSmoothing) + (dt * (1 - dtSmoothing))

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

    if frameRateChecker.isActive and not ((sim.isPaused) or (sim.isReplayActive and (sim.replayPlaybackRate < 0.01))) then
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

        driverAnimator:update(smoothDT, antiResetAdder)
        kartAnimator:update(smoothDT, angularAcceleration)
    end

    tierodLControl:setPosition(helpers.getPositionInCarFrame(tierodLTarget, carNode))
    tierodRControl:setPosition(helpers.getPositionInCarFrame(tierodRTarget, carNode))

    -- Update visibility for all configured parts
    if sim.isInMainMenu then
        for _, partConfig in pairs(partConfigurations) do
            updatePartVisibility(partConfig)
        end
    end

    for tireIndex, tire in ipairs(tires) do
        local parentTransform = tire.base:getParent():getWorldTransformationRaw()
        local localTransform = tire.susp:getWorldTransformationRaw():mul(parentTransform:inverse())

        -- Apply local offset in the bone's local space
        if tire.baseLocalOffset then
            -- Transform the offset from bone's local space to parent space using the rotation part
            local rotatedOffset = localTransform:transformVector(tire.baseLocalOffset)
            -- Add the rotated offset to the position
            localTransform.position = localTransform.position + rotatedOffset
        end

        tire.base:getTransformationRaw():set(localTransform)

        tire.filteredLatFlexInput = applyFlexFilter(tire.filteredLatFlexInput, car.wheels[tireIndex - 1].fy, smoothDT, 0.05)
        tire.filteredVertFlexInput = applyFlexFilter(tire.filteredVertFlexInput, car.wheels[tireIndex - 1].load, smoothDT, 0.05)

        tire.latFlexPhys:step(tire.filteredLatFlexInput, smoothDT)
        tire.vertFlexPhys:step(tire.filteredVertFlexInput, smoothDT)

        tire.flex:setPosition(vec3(tire.latFlexPhys.position, 0.2 + tire.vertFlexPhys.position, 0))

        -- Update tire canvas and rotation tracking
        tire.angle = tire.angle + (car.wheels[tireIndex - 1].angularSpeed * dt)
        tire.angle = tire.angle - math.floor(tire.angle / (2 * math.pi)) * (2 * math.pi)
        tire.canvas:clear()
        tire.canvas:update(function() drawTireSurface(car.wheels[tireIndex - 1].angularSpeed, tire.angle) end)
        tire.surface:setMaterialTexture('txDiffuse', tire.canvas)

        ac.debug("tire angle " .. tireIndex, tire.angle)
    end

    lastDT = dt
end