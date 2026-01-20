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

-- check for limiter being lower than threshold for LO206, etc
local useLimiter = ac.INIConfig.carData(car.index, "engine.ini"):get("ENGINE_DATA", "LIMITER", 20000) < 10000 and true or
false

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


-- Called when car teleports to pits or session resets
---@diagnostic disable-next-line: duplicate-set-field
function script.reset()
    lastSteer = 0.0
    filteredAiSteer = 0.0
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
