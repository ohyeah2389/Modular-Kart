-- Modular Kart Class 2 CSP Graphics Script
-- Authored by ohyeah2389

DEBUG = false

local helpers = require("helpers")
local cphys = ac.getCarPhysics(car.index) or {}

local previousAngularVelocity = vec3(0, 0, 0)
local angularAcceleration = vec3(0, 0, 0)

local function updateAngularAcceleration(dt)
    local currentAngularVelocity = vec3(car.angularVelocity.x, car.angularVelocity.y, car.angularVelocity.z)
    previousAngularVelocity = currentAngularVelocity
    return helpers.calculateAngularAcceleration(currentAngularVelocity, previousAngularVelocity, dt)
end

local function findNode(name)
    local ref = ac.findNodes(name)
    return not ref:empty() and ref or nil
end

local DriverAnimator = require("driver_animator")
local KartAnimator = require("kart_animator")
local driverAnimator = DriverAnimator()
local kartAnimator = KartAnimator()

local antiResetAdder = 0

local carNode = findNode("BODYTR")
local tierodLTarget = findNode("DIR2_anim_tierodLF")
local tierodRTarget = findNode("DIR2_anim_tierodRF")
local tierodLControl = findNode("DIR_anim_tierodLF")
local tierodRControl = findNode("DIR_anim_tierodRF")
local tierodLPos = vec3()
local tierodRPos = vec3()
local drawTireSurface_Diffuse
local drawTireSurface_Normal
local drawTireSurface_Maps

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
        angle = 0,
        reverseAngle = false
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
        angle = 1,
        reverseAngle = false
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
        angle = 2,
        reverseAngle = true
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
        angle = 3,
        reverseAngle = false
    }
}

for tireIndex, tire in ipairs(tires) do
    tire.base:storeCurrentTransformation()
    tire.flex:storeCurrentTransformation()
    tire.surface:ensureUniqueMaterials()
    tire.flexBaseTransform = tire.flex:getTransformationRaw():clone()
    tire.mapsUpdateClock = 1
    tire.currentWheelSpeed = 0
    tire.currentSignedAngle = 0
    tire.currentTextureName = tire.textureName or tire.name
    tire.updateDiffuseCallback = function()
        drawTireSurface_Diffuse(tire.currentWheelSpeed, tire.currentSignedAngle, tire.currentTextureName)
    end
    tire.updateNormalCallback = function()
        drawTireSurface_Normal(tire.currentWheelSpeed, tire.currentSignedAngle, tire.currentTextureName)
    end
    tire.updateMapsCallback = function()
        drawTireSurface_Maps(tire.currentWheelSpeed, tire.currentSignedAngle, tire.currentTextureName, tireIndex)
    end
end

local lastDT = 1
local dtSmoothing = 0.9

local tireRotationScalar = (1 / (2 * math.pi)) * 1024
local colorLUTSize = 256
local mapsUpdateInterval = 1 / 30

local function buildColorLUT(r, g, b, maxAlpha)
    local lut = {}
    for i = 0, colorLUTSize do
        lut[i] = rgbm(r, g, b, (i / colorLUTSize) * maxAlpha)
    end
    return lut
end

local function getLUTColor(lut, value)
    local index = math.floor(math.clamp(value, 0, 1) * colorLUTSize + 0.5)
    return lut[index]
end

local fadeColorLUT = buildColorLUT(1, 1, 1, 1)
local scrubColorLUT = buildColorLUT(1, 0, 0.5, 1)
local grainColorLUT = buildColorLUT(1, 0, 0.2, 0.4)
local edgeColor = rgbm(1, 0, 1, 0)

local tireSpanMin = { vec2(), vec2(), vec2() }
local tireSpanMax = { vec2(), vec2(), vec2() }
local blurVector = vec2()
local rectTopMin = vec2(0, 0)
local rectTopMax = vec2(1024, 0.25 * 512)
local rectCenterMin = vec2(0, 0.25 * 512)
local rectCenterMax = vec2(1024, 0.75 * 512)
local rectBottomMin = vec2(0, 0.75 * 512)
local rectBottomMax = vec2(1024, 512)

local function updateTireSpanBounds(tireAngle)
    local x = tireAngle * tireRotationScalar
    tireSpanMin[1].x, tireSpanMin[1].y = x - 1024, 0
    tireSpanMax[1].x, tireSpanMax[1].y = x, 512
    tireSpanMin[2].x, tireSpanMin[2].y = x, 0
    tireSpanMax[2].x, tireSpanMax[2].y = x + 1024, 512
    tireSpanMin[3].x, tireSpanMin[3].y = x + 1024, 0
    tireSpanMax[3].x, tireSpanMax[3].y = x + 2048, 512
end

local function drawTireSpans(texturePath, color)
    if color then
        ui.drawImage(texturePath, tireSpanMin[1], tireSpanMax[1], color, ui.ImageFit.Stretch)
        ui.drawImage(texturePath, tireSpanMin[2], tireSpanMax[2], color, ui.ImageFit.Stretch)
        ui.drawImage(texturePath, tireSpanMin[3], tireSpanMax[3], color, ui.ImageFit.Stretch)
    else
        ui.drawImage(texturePath, tireSpanMin[1], tireSpanMax[1], ui.ImageFit.Stretch)
        ui.drawImage(texturePath, tireSpanMin[2], tireSpanMax[2], ui.ImageFit.Stretch)
        ui.drawImage(texturePath, tireSpanMin[3], tireSpanMax[3], ui.ImageFit.Stretch)
    end
end

local function updateBlurVector(tireSpeed)
    blurVector.x = (0.005 * (math.abs(tireSpeed) + 0.001)) ^ 3.5
    blurVector.y = 0
end

drawTireSurface_Diffuse = function(tireSpeed, tireAngle, textureName)
    updateTireSpanBounds(tireAngle)
    local texturePath = "Textures/Tires/MK_Tire_" .. textureName .. "_Diffuse.dds"
    ui.beginBlurring()
    drawTireSpans(texturePath)
    texturePath = "Textures/Tires/MK_Tire_" .. textureName .. "_Diffuse_Blur_Diffuse.dds"
    local fadeFactor = math.clamp((0.03 * (math.abs(tireSpeed) + 0.001)) ^ 2.5, 0, 1)
    drawTireSpans(texturePath, getLUTColor(fadeColorLUT, fadeFactor))
    updateBlurVector(tireSpeed)
    ui.endBlurring(blurVector)
end

drawTireSurface_Normal = function(tireSpeed, tireAngle, textureName)
    updateTireSpanBounds(tireAngle)
    local texturePath = "Textures/Tires/MK_Tire_" .. textureName .. "_Normal_AC.dds"
    ui.beginBlurring()
    drawTireSpans(texturePath)
    texturePath = "Textures/Tires/MK_Tire_" .. textureName .. "_Diffuse_Blur_Normal_AC.dds"
    local fadeFactor = math.clamp((0.03 * (math.abs(tireSpeed) + 0.001)) ^ 2.5, 0, 1)
    drawTireSpans(texturePath, getLUTColor(fadeColorLUT, fadeFactor))
    updateBlurVector(tireSpeed)
    ui.endBlurring(blurVector)
end

drawTireSurface_Maps = function(tireSpeed, tireAngle, textureName, tireIndex)
    updateTireSpanBounds(tireAngle)
    local texturePath = "Textures/Tires/MK_Tire_" .. textureName .. "_ksPPMM_Maps.dds"
    ui.beginBlurring()

    drawTireSpans(texturePath)

    texturePath = "Textures/Tires/MK_Tire_" .. textureName .. "_Diffuse_Blur_ksPPMM_Maps.dds"
    local fadeFactor = math.clamp((0.03 * (math.abs(tireSpeed) + 0.001)) ^ 2.5, 0, 1)

    drawTireSpans(texturePath, getLUTColor(fadeColorLUT, fadeFactor))

    local scrubFactor = math.clamp(math.remap(car.wheels[tireIndex - 1].tyreVirtualKM, 0, 0.01, 0, 1), 0, 1)
    local grainFactor = math.clamp(math.remap(car.wheels[tireIndex - 1].tyreVirtualKM, 0, 1.3, 0, 1), 0, 1) ^ 0.5

    if DEBUG then
        ac.debug("scrubFactor" .. tireIndex - 1, scrubFactor)
        ac.debug("grainFactor" .. tireIndex - 1, grainFactor)
    end

    local colorCenter = getLUTColor(scrubColorLUT, scrubFactor)
    ui.drawRectFilled(rectCenterMin, rectCenterMax, colorCenter)
    ui.drawRectFilledMultiColor(rectTopMin, rectTopMax, edgeColor, edgeColor, colorCenter, colorCenter)
    ui.drawRectFilledMultiColor(rectBottomMin, rectBottomMax, colorCenter, colorCenter, edgeColor, edgeColor)

    texturePath = "dirt.dds"
    drawTireSpans(texturePath, getLUTColor(grainColorLUT, grainFactor))

    updateBlurVector(tireSpeed)
    ui.endBlurring(blurVector)
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

    angularAcceleration = updateAngularAcceleration(dt)

    if DEBUG then
        ac.debug("angularAcceleration.x", angularAcceleration.x)
        ac.debug("angularAcceleration.y", angularAcceleration.y)
        ac.debug("angularAcceleration.z", angularAcceleration.z)
        ac.debug("car.acceleration.x", car.acceleration.x)
        ac.debug("car.acceleration.y", car.acceleration.y)
        ac.debug("car.acceleration.z", car.acceleration.z)
    end

    if not ((sim.isPaused) or (sim.isReplayActive and (sim.replayPlaybackRate < 0.01))) then
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

    if tierodLControl and tierodLTarget and carNode then
        tierodLPos:set(helpers.getPositionInCarFrame(tierodLTarget, carNode))
        tierodLControl:setPosition(tierodLPos)
    end
    if tierodRControl and tierodRTarget and carNode then
        tierodRPos:set(helpers.getPositionInCarFrame(tierodRTarget, carNode))
        tierodRControl:setPosition(tierodRPos)
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
            cphys.scriptControllerInputs[0 + (tireIndex - 1)] * 0.25,
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

        if DEBUG then
            local flexParentWorld = tire.flex:getParent():getWorldTransformationRaw()
            local flexPivotWorld = flexParentWorld:transformPoint(tire.flexPivotLocal)
            render.debugCross(flexPivotWorld, 0.1, rgbm(0, 1, 0, 1))
        end

        -- Update tire canvas and rotation tracking
        local wheel = car.wheels[tireIndex - 1]
        tire.angle = tire.angle + (wheel.angularSpeed * dt * (tire.reverseAngle and -1 or 1))
        tire.angle = tire.angle - math.floor(tire.angle / (2 * math.pi)) * (2 * math.pi)
        tire.currentWheelSpeed = wheel.angularSpeed
        tire.currentSignedAngle = tire.angle * (tireIndex <= 2 and -1 or 1)
        tire.currentTextureName = tire.textureName or tire.name
        tire.canvas:clear()
        tire.canvas:update(tire.updateDiffuseCallback)
        tire.surface:setMaterialTexture('txDiffuse', tire.canvas)
        tire.canvasNormal:clear()
        tire.canvasNormal:update(tire.updateNormalCallback)
        tire.surface:setMaterialTexture('txNormal', tire.canvasNormal)
        tire.mapsUpdateClock = tire.mapsUpdateClock + dt
        if tire.mapsUpdateClock >= mapsUpdateInterval then
            tire.mapsUpdateClock = tire.mapsUpdateClock - mapsUpdateInterval
            tire.canvasMaps:clear()
            tire.canvasMaps:update(tire.updateMapsCallback)
            tire.surface:setMaterialTexture('txMaps', tire.canvasMaps)
        end

        if DEBUG then
            ac.debug("tire angle " .. tireIndex, tire.angle)
        end
    end

    lastDT = dt
end