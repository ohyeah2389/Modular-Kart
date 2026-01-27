-- Modular Kart Class 2 CSP Graphics Script
-- Authored by ohyeah2389

local helpers = require("helpers")
local physObj = require("physics_object")
local cphys = ac.getCarPhysics(car.index) or {}

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
            [8] = {"CIK02 Nassau Plastic"},
            [9] = {"Oval Nassau Polycarbonate"},
            [10] = {"Metal Fairing Nassau Metal"},
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
            [6] = {"CIK02 Nosecone Plastic"},
            [7] = {"OvalNosecone"},
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
            [3] = {"OldArrow SidepodBraceBar Left", "OldArrow SidepodBraceBar Right"},
            [4] = {"OvalSidepodRight", "OvalSidepodLeft"},
            [5] = {"SidepodMetal_L", "SidepodMetal_R"},
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

local tires = {
    {
        name = "FrontLeft",
        textureName = "FrontLeft",
        base = ac.findNodes("BASE_LF"),
        baseLocalOffset = vec3(0.5, 0.087, 0.466),
        flex = ac.findNodes("FLEX_LF"),
        flexPivotLocal = vec3(0.5, 0.1, 0),
        flexAxisLocal = vec3(0, 0, 1),
        flexAngle = 0,
        susp = ac.findNodes("SUSP_LF"),
        canvas = ui.ExtraCanvas(vec2(1024, 512)),
        canvasNormal = ui.ExtraCanvas(vec2(1024, 512)),
        canvasMaps = ui.ExtraCanvas(vec2(1024, 512)),
        surface = ac.findSkinnedMeshes("Tire_FrontLeft"),
        angle = 0
    },
    {
        name = "FrontRight",
        textureName = "FrontLeft",
        base = ac.findNodes("BASE_RF"),
        baseLocalOffset = vec3(-0.5, 0.087, 0.466),
        flex = ac.findNodes("FLEX_RF"),
        flexPivotLocal = vec3(-0.5, 0.1, 0),
        flexAxisLocal = vec3(0, 0, 1),
        flexAngle = 0,
        susp = ac.findNodes("SUSP_RF"),
        canvas = ui.ExtraCanvas(vec2(1024, 512)),
        canvasNormal = ui.ExtraCanvas(vec2(1024, 512)),
        canvasMaps = ui.ExtraCanvas(vec2(1024, 512)),
        surface = ac.findSkinnedMeshes("Tire_FrontRight"),
        angle = 1
    },
    {
        name = "RearLeft",
        textureName = "RearLeft",
        base = ac.findNodes("BASE_LR"),
        baseLocalOffset = vec3(0.6085, 0.087, -0.584),
        flex = ac.findNodes("FLEX_LR"),
        flexPivotLocal = vec3(0.6085, 0.1, 0),
        flexAxisLocal = vec3(0, 0, 1),
        flexAngle = 0,
        susp = ac.findNodes("SUSP_LR"),
        canvas = ui.ExtraCanvas(vec2(1024, 512)),
        canvasNormal = ui.ExtraCanvas(vec2(1024, 512)),
        canvasMaps = ui.ExtraCanvas(vec2(1024, 512)),
        surface = ac.findSkinnedMeshes("Tire_RearLeft"),
        angle = 2
    },
    {
        name = "RearRight",
        textureName = "RearLeft",
        base = ac.findNodes("BASE_RR"),
        baseLocalOffset = vec3(-0.6085, 0.087, -0.584),
        flex = ac.findNodes("FLEX_RR"),
        flexPivotLocal = vec3(-0.6085, 0.1, 0),
        flexAxisLocal = vec3(0, 0, 1),
        flexAngle = 0,
        susp = ac.findNodes("SUSP_RR"),
        canvas = ui.ExtraCanvas(vec2(1024, 512)),
        canvasNormal = ui.ExtraCanvas(vec2(1024, 512)),
        canvasMaps = ui.ExtraCanvas(vec2(1024, 512)),
        surface = ac.findSkinnedMeshes("Tire_RearRight"),
        angle = 3
    }
}

for _, tire in ipairs(tires) do
    tire.base:storeCurrentTransformation()
    tire.flex:storeCurrentTransformation()
    tire.surface:ensureUniqueMaterials()
    tire.flexBaseTransform = tire.flex:getTransformationRaw():clone()
end

local lastDT = 1
local dtSmoothing = 0.9

local function drawTireSurface_Diffuse(tireSpeed, tireAngle, textureName)
    local rotationScalar = (1 / (2 * math.pi)) * 1024
    local texturePath = "Textures/Tires/MK_Tire_" .. textureName .. "_Diffuse.dds"
    ui.beginBlurring()
    ui.drawImage(texturePath, vec2(-1024 + (tireAngle * rotationScalar), 0), vec2(0 + (tireAngle * rotationScalar), 512), ui.ImageFit.Stretch)
    ui.drawImage(texturePath, vec2(0 + (tireAngle * rotationScalar), 0), vec2(1024 + (tireAngle * rotationScalar), 512), ui.ImageFit.Stretch)
    ui.drawImage(texturePath, vec2(1024 + (tireAngle * rotationScalar), 0), vec2(2048 + (tireAngle * rotationScalar), 512), ui.ImageFit.Stretch)
    texturePath = "Textures/Tires/MK_Tire_" .. textureName .. "_Diffuse_Blur_Diffuse.dds"
    local fadeFactor = math.clamp((0.03 * (math.abs(tireSpeed) + 0.001)) ^ 2.5, 0, 1)
    ui.drawImage(texturePath, vec2(-1024 + (tireAngle * rotationScalar), 0), vec2(0 + (tireAngle * rotationScalar), 512), rgbm(1, 1, 1, fadeFactor), ui.ImageFit.Stretch)
    ui.drawImage(texturePath, vec2(0 + (tireAngle * rotationScalar), 0), vec2(1024 + (tireAngle * rotationScalar), 512), rgbm(1, 1, 1, fadeFactor), ui.ImageFit.Stretch)
    ui.drawImage(texturePath, vec2(1024 + (tireAngle * rotationScalar), 0), vec2(2048 + (tireAngle * rotationScalar), 512), rgbm(1, 1, 1, fadeFactor), ui.ImageFit.Stretch)
    ui.endBlurring(vec2(
        (0.005 * (math.abs(tireSpeed) + 0.001)) ^ 3.5,
        0
    ))
end

local function drawTireSurface_Normal(tireSpeed, tireAngle, textureName)
    local rotationScalar = (1 / (2 * math.pi)) * 1024
    local texturePath = "Textures/Tires/MK_Tire_" .. textureName .. "_Normal_AC.dds"
    ui.beginBlurring()
    ui.drawImage(texturePath, vec2(-1024 + (tireAngle * rotationScalar), 0), vec2(0 + (tireAngle * rotationScalar), 512), ui.ImageFit.Stretch)
    ui.drawImage(texturePath, vec2(0 + (tireAngle * rotationScalar), 0), vec2(1024 + (tireAngle * rotationScalar), 512), ui.ImageFit.Stretch)
    ui.drawImage(texturePath, vec2(1024 + (tireAngle * rotationScalar), 0), vec2(2048 + (tireAngle * rotationScalar), 512), ui.ImageFit.Stretch)
    texturePath = "Textures/Tires/MK_Tire_" .. textureName .. "_Diffuse_Blur_Normal_AC.dds"
    local fadeFactor = math.clamp((0.03 * (math.abs(tireSpeed) + 0.001)) ^ 2.5, 0, 1)
    ui.drawImage(texturePath, vec2(-1024 + (tireAngle * rotationScalar), 0), vec2(0 + (tireAngle * rotationScalar), 512), rgbm(1, 1, 1, fadeFactor), ui.ImageFit.Stretch)
    ui.drawImage(texturePath, vec2(0 + (tireAngle * rotationScalar), 0), vec2(1024 + (tireAngle * rotationScalar), 512), rgbm(1, 1, 1, fadeFactor), ui.ImageFit.Stretch)
    ui.drawImage(texturePath, vec2(1024 + (tireAngle * rotationScalar), 0), vec2(2048 + (tireAngle * rotationScalar), 512), rgbm(1, 1, 1, fadeFactor), ui.ImageFit.Stretch)
    ui.endBlurring(vec2(
        (0.005 * (math.abs(tireSpeed) + 0.001)) ^ 3.5,
        0
    ))
end

local function drawTireSurface_Maps(tireSpeed, tireAngle, textureName)
    local rotationScalar = (1 / (2 * math.pi)) * 1024
    local texturePath = "Textures/Tires/MK_Tire_" .. textureName .. "_ksPPMM_Maps.dds"
    ui.beginBlurring()
    ui.drawImage(texturePath, vec2(-1024 + (tireAngle * rotationScalar), 0), vec2(0 + (tireAngle * rotationScalar), 512), ui.ImageFit.Stretch)
    ui.drawImage(texturePath, vec2(0 + (tireAngle * rotationScalar), 0), vec2(1024 + (tireAngle * rotationScalar), 512), ui.ImageFit.Stretch)
    ui.drawImage(texturePath, vec2(1024 + (tireAngle * rotationScalar), 0), vec2(2048 + (tireAngle * rotationScalar), 512), ui.ImageFit.Stretch)
    texturePath = "Textures/Tires/MK_Tire_" .. textureName .. "_Diffuse_Blur_ksPPMM_Maps.dds"
    local fadeFactor = math.clamp((0.03 * (math.abs(tireSpeed) + 0.001)) ^ 2.5, 0, 1)
    ui.drawImage(texturePath, vec2(-1024 + (tireAngle * rotationScalar), 0), vec2(0 + (tireAngle * rotationScalar), 512), rgbm(1, 1, 1, fadeFactor), ui.ImageFit.Stretch)
    ui.drawImage(texturePath, vec2(0 + (tireAngle * rotationScalar), 0), vec2(1024 + (tireAngle * rotationScalar), 512), rgbm(1, 1, 1, fadeFactor), ui.ImageFit.Stretch)
    ui.drawImage(texturePath, vec2(1024 + (tireAngle * rotationScalar), 0), vec2(2048 + (tireAngle * rotationScalar), 512), rgbm(1, 1, 1, fadeFactor), ui.ImageFit.Stretch)
    ui.endBlurring(vec2(
        (0.005 * (math.abs(tireSpeed) + 0.001)) ^ 3.5,
        0
    ))
end

local function rotateTransformAroundLocalPivot(localTransform, pivotLocal, axisLocal, angleRad)
    if not pivotLocal or not axisLocal or angleRad == 0 then
        return localTransform
    end

    local pivotMatrix = mat4x4.translation(pivotLocal)
    local pivotInverseMatrix = mat4x4.translation(vec3(-pivotLocal.x, -pivotLocal.y, -pivotLocal.z))
    local rotationMatrix = mat4x4.rotation(angleRad, axisLocal)

    return pivotMatrix:mul(rotationMatrix):mul(pivotInverseMatrix):mul(localTransform)
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

        local flexOffset = vec3(
            cphys.scriptControllerInputs[0 + (tireIndex - 1)] * 0.4,
            cphys.scriptControllerInputs[4 + (tireIndex - 1)],
            0
        )
        local flexTransform = tire.flexBaseTransform:clone()
        flexTransform.position = flexTransform.position + flexOffset
        flexTransform = rotateTransformAroundLocalPivot(
            flexTransform,
            tire.flexPivotLocal,
            tire.flexAxisLocal,
            tire.flexAngle + (cphys.scriptControllerInputs[0 + (tireIndex - 1)] * 2)
        )
        tire.flex:getTransformationRaw():set(flexTransform)

        local flexParentWorld = tire.flex:getParent():getWorldTransformationRaw()
        local flexPivotWorld = flexParentWorld:transformPoint(tire.flexPivotLocal)
        render.debugCross(flexPivotWorld, 0.1, rgbm(0, 1, 0, 1))

        -- Update tire canvas and rotation tracking
        tire.angle = tire.angle + (car.wheels[tireIndex - 1].angularSpeed * dt)
        tire.angle = tire.angle - math.floor(tire.angle / (2 * math.pi)) * (2 * math.pi)
        tire.canvas:clear()
        tire.canvas:update(function()
            drawTireSurface_Diffuse(
                car.wheels[tireIndex - 1].angularSpeed,
                tire.angle * (tireIndex <= 2 and -1 or 1),
                tire.textureName or tire.name
            )
        end)
        tire.surface:setMaterialTexture('txDiffuse', tire.canvas)
        tire.canvasNormal:clear()
        tire.canvasNormal:update(function()
            drawTireSurface_Normal(
                car.wheels[tireIndex - 1].angularSpeed,
                tire.angle * (tireIndex <= 2 and -1 or 1),
                tire.textureName or tire.name
            )
        end)
        tire.surface:setMaterialTexture('txNormal', tire.canvasNormal)
        tire.canvasMaps:clear()
        tire.canvasMaps:update(function()
            drawTireSurface_Maps(
                car.wheels[tireIndex - 1].angularSpeed,
                tire.angle * (tireIndex <= 2 and -1 or 1),
                tire.textureName or tire.name
            )
        end)
        tire.surface:setMaterialTexture('txMaps', tire.canvasMaps)

        ac.debug("tire angle " .. tireIndex, tire.angle)
    end

    lastDT = dt
end