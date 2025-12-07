-- Modular Kart Class 2 CSP Physics Script - Main Module
-- Authored by ohyeah2389


DEBUG = false


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local sharedData = require('script_sharedData')
local ffb = require('script_ffb')
local throttle = require('script_throttle')


local lastDebugTime = os.clock()
local lastSteer = 0.0
local filteredAiSteer = 0.0
local aiSteerRateLimit = 100
local aiSteerDampingHz = 20
local filteredAccelWant = 0
local filteredSpeedWant = 0

local accelRiseHz = 40
local accelFallHz = 40

local speedRiseHz = 2
local speedFallHz = 8

local lastAngleSum = 0
local lookaheadConfig = {
    {distance = 3},
    {distance = 6},
    {distance = 10},
    {distance = 15},
    {distance = 25},
}
local lookaheadPoints = {}

-- check for limiter being lower than threshold for LO206, etc
local useLimiter = ac.INIConfig.carData(car.index, "engine.ini"):get("ENGINE_DATA", "LIMITER", 20000) < 10000 and true or false

-- Shows specific variables in debug
local function showDebugValues()
    if os.clock() - lastDebugTime > 0.05 then
        lastDebugTime = os.clock()
        ac.debug("useLimiter", useLimiter)
        ac.debug("LIMITER", ac.INIConfig.carData(car.index, "engine.ini"):get("ENGINE_DATA", "LIMITER", 20000))
        ac.debug("state.engine.torque", state.engine.torque)
        ac.debug("state.engine.compressionTorque", state.engine.compressionTorque)
        ac.debug("state.engine.compressionWave", state.engine.compressionWave)
        ac.debug("state.engine.angle", state.engine.angle)
        ac.debug("state.starter.rpm", state.starter.rpm)
        ac.debug("state.starter.engaged", state.starter.engaged)
        ac.debug("state.starter.torque", state.starter.torque)
        ac.debug("state.starter.voltageDraw", state.starter.voltageDraw)
    end
end


local function brakeAutoHold()
    if game.car_cphys.speedKmh < config.misc.brakeAutoHold.speed and not (game.car_cphys.gas > 0.05) then
        --ac.overrideBrakesTorque(2, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque) -- not functional due to ext brakes
        --ac.overrideBrakesTorque(3, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque) -- not functional due to ext brakes
        game.car_cphys.brake = math.max(0.1, game.car_cphys.brake) -- instead, we use this
        if DEBUG then ac.debug("brakeAutoHold", "brakes engaged") end
    else
        ac.overrideBrakesTorque(2, math.nan, math.nan)
        ac.overrideBrakesTorque(3, math.nan, math.nan)
        if DEBUG then ac.debug("brakeAutoHold", "brakes disengaged") end
    end
end


local function runCustomAIControl(dt)
    for i = 1, #lookaheadConfig do
        local distanceAhead = lookaheadConfig[i].distance
        local targetSplinePos = ((car.splinePosition * sim.trackLengthM) + distanceAhead) / sim.trackLengthM
        lookaheadPoints[i] = ac.trackProgressToWorldCoordinate(targetSplinePos % 1.0)
    end

    local angleChangeSum = 0
    local prevPos = car.position
    local prevDir = car.look
    for i = 2, #lookaheadPoints do
        local point = lookaheadPoints[i]
        if point then
            local segment = point - prevPos
            local segmentLength = segment:length()
            if segmentLength > 0.01 then
                local dir = segment * (1 / segmentLength)
                local prevYaw = math.atan2(prevDir:dot(car.side), prevDir:dot(car.look))
                local dirYaw = math.atan2(dir:dot(car.side), dir:dot(car.look))
                local diff = math.atan2(math.sin(dirYaw - prevYaw), math.cos(dirYaw - prevYaw))
                angleChangeSum = angleChangeSum + diff
                prevDir = dir
                prevPos = point
            end
        end
    end

    local signedAngleSum = angleChangeSum
    local absAngleSum = math.abs(signedAngleSum)

    local deltaAngle = signedAngleSum - lastAngleSum
    local changePerSecond = math.abs(deltaAngle) / math.max(dt, 1e-3)
    local speedNorm = math.max(car.speedKmh, 1)
    local bendChangeNorm = changePerSecond / speedNorm

    ac.debug("bendChangeNorm", bendChangeNorm, -0.1, 0.1, 4)
    ac.debug("absAngleSum", absAngleSum, 0, 3, 4)
    lastAngleSum = signedAngleSum

    local targetIndices = {1, 2}
    local sumPoint = vec3(0, 0, 0)
    local used = 0
    for i = 1, #targetIndices do
        local point = lookaheadPoints[targetIndices[i]]
        if point then
            sumPoint = sumPoint + point
            used = used + 1
        end
    end
    local targetPoint = used > 0 and (sumPoint * (1 / used)) or car.position

    ac.debug("targetPoint", targetPoint)
    ac.debug("car.position", car.position)

    local toTarget = targetPoint - car.position
    if toTarget:length() < 0.01 then
        toTarget = car.look  -- avoid zero-length and keep steering stable
    end

    -- Signed yaw error using car basis; avoids 90° flips from unsigned angles
    local lateral = toTarget:dot(car.side)
    local longitudinal = toTarget:dot(car.look)
    local angleToTarget = math.atan2(lateral, longitudinal)

    ac.debug("angleToTarget", angleToTarget)

    for i = 1, #lookaheadPoints do
        local point = lookaheadPoints[i]
        if point then
            ac.drawDebugLine(point, point + vec3(0, 1, 0), rgbm(1, 0, 0, 1))
        end
    end

    ac.drawDebugLine(targetPoint, targetPoint + vec3(0, 1, 0), rgbm(0.5, 0, 1, 1))
    ac.drawDebugLine(car.position, car.position + vec3(0, 1, 0), rgbm(0, 1, 0, 1))

    local rawSteer = angleToTarget * -1.5
    -- low-pass filter to calm fast sign flips before rate limiting
    local damping = 1 - math.exp(-dt * aiSteerDampingHz)
    filteredAiSteer = filteredAiSteer + (rawSteer - filteredAiSteer) * damping

    local maxDelta = aiSteerRateLimit * dt
    local desiredDelta = filteredAiSteer - lastSteer
    local limitedDelta = math.clamp(desiredDelta, -maxDelta, maxDelta)
    local newSteer = lastSteer + limitedDelta

    game.car_cphys.steer = newSteer
    lastSteer = newSteer

    local minSpeedTerm = math.clamp(math.remap(car.speedKmh, 0, 20, 3, 0), 0, 3)

    local speedWant = math.clamp(120.0 + (bendChangeNorm * 100) - ((absAngleSum ^ 1.0) * 60), 20, 120)
    local speedRateHz = speedWant < filteredSpeedWant and speedFallHz or speedRiseHz
    local speedDamping = 1 - math.exp(-dt * speedRateHz)
    filteredSpeedWant = filteredSpeedWant + (speedWant - filteredSpeedWant) * speedDamping

    local accelWant = math.clamp((filteredSpeedWant - car.speedKmh) * 0.1, -1, 1)
    local accelRateHz = accelWant < filteredAccelWant and accelFallHz or accelRiseHz
    local accelDamping = 1 - math.exp(-dt * accelRateHz)
    filteredAccelWant = filteredAccelWant + (accelWant - filteredAccelWant) * accelDamping

    ac.debug("speedWant", speedWant, 0, 120, 4)
    ac.debug("filteredSpeedWant", filteredSpeedWant, 0, 120, 4)
    ac.debug("accelWant", accelWant, -1, 1, 4)
    ac.debug("filteredAccelWant", filteredAccelWant, -1, 1, 4)
    ac.debug("minSpeedTerm", minSpeedTerm)

    game.car_cphys.gas = math.clamp(filteredAccelWant + minSpeedTerm, 0, 1)
    game.car_cphys.brake = math.clamp(-filteredAccelWant - minSpeedTerm, 0, 0.5)
    game.car_cphys.requestedGearIndex = 2
end


-- Called when car teleports to pits or session resets
---@diagnostic disable-next-line: duplicate-set-field
function script.reset()
    lastSteer = 0.0
    filteredAiSteer = 0.0
    filteredAccelWant = 0
    lastAngleSum = 0
end

ac.onCarJumped(0, script.reset)

-- Run by game every physics tick (~333 Hz)
---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.awakeCarPhysics()
    if not useLimiter then
        ac.disableEngineLimiter()
    end

    brakeAutoHold()

    if car.isAIControlled then
        --runCustomAIControl(dt)

        local rawSteer = game.car_cphys.steer
        -- low-pass filter to calm fast sign flips before rate limiting
        local damping = 1 - math.exp(-dt * aiSteerDampingHz)
        filteredAiSteer = filteredAiSteer + (rawSteer - filteredAiSteer) * damping

        local maxDelta = aiSteerRateLimit * dt
        local desiredDelta = filteredAiSteer - lastSteer
        local limitedDelta = math.clamp(desiredDelta, -maxDelta, maxDelta)
        local newSteer = lastSteer + limitedDelta

        game.car_cphys.steer = newSteer
        lastSteer = newSteer
    else
        ffb.update(dt)
    end

    throttle.update(dt)
    sharedData.update()

    if DEBUG then showDebugValues() end
end
