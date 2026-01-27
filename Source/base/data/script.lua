-- Modular Kart Class 2 CSP Physics Script - Main Module
-- Authored by ohyeah2389

local game = require('script_acConnection')
local config = require('script_config')
local sharedData = require('script_sharedData')
local ffb = require('script_ffb')
local throttle = require('script_throttle')
local PhysObj = require("physics_object")

local data = ac.accessCarPhysics()

local lastSteer = 0.0
local filteredAiSteer = 0.0
local aiSteerRateLimit = 100
local aiSteerDampingHz = 20

-- check for limiter being lower than threshold for LO206, etc
local useLimiter = ac.INIConfig.carData(car.index, "engine.ini"):get("ENGINE_DATA", "LIMITER", 20000) < 10000 and true or false

local function brakeAutoHold()
    if game.car_cphys.speedKmh < config.misc.brakeAutoHold.speed and not (game.car_cphys.gas > 0.05) then
        --ac.overrideBrakesTorque(2, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque) -- not functional due to ext brakes
        --ac.overrideBrakesTorque(3, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque) -- not functional due to ext brakes
        game.car_cphys.brake = math.max(0.1, game.car_cphys.brake) -- instead, we use this
    else
        ac.overrideBrakesTorque(2, math.nan, math.nan)
        ac.overrideBrakesTorque(3, math.nan, math.nan)
    end
end

local latFlexParamsFront = {
    posMax = 0.05,
    posMin = -0.05,
    center = 0.0,
    mass = 5.0,
    frictionCoef = 0,
    staticFrictionCoef = 0,
    dampingCoef = 50000,
    springCoef = 58500,
    forceMax = 10000,
    constantForce = 0
}

local vertFlexParamsFront = {
    posMax = 0.05,
    posMin = -0.05,
    center = 0.0,
    mass = 5.0,
    frictionCoef = 0,
    staticFrictionCoef = 0,
    dampingCoef = 50000,
    springCoef = 65000,
    forceMax = 10000,
    constantForce = 0
}

local latFlexParamsRear = {
    posMax = 0.05,
    posMin = -0.05,
    center = 0.0,
    mass = 5.0,
    frictionCoef = 0,
    staticFrictionCoef = 0,
    dampingCoef = 50000,
    springCoef = 63000,
    forceMax = 10000,
    constantForce = 0
}

local vertFlexParamsRear = {
    posMax = 0.05,
    posMin = -0.05,
    center = 0.0,
    mass = 5.0,
    frictionCoef = 0,
    staticFrictionCoef = 0,
    dampingCoef = 50000,
    springCoef = 70000,
    forceMax = 10000,
    constantForce = 0
}

local tireFlex = {
    leftFront = {
        latFlexObj = PhysObj(latFlexParamsFront),
        vertFlexObj = PhysObj(vertFlexParamsFront)
    },
    rightFront = {
        latFlexObj = PhysObj(latFlexParamsFront),
        vertFlexObj = PhysObj(vertFlexParamsFront)
    },
    leftRear = {
        latFlexObj = PhysObj(latFlexParamsRear),
        vertFlexObj = PhysObj(vertFlexParamsRear)
    },
    rightRear = {
        latFlexObj = PhysObj(latFlexParamsRear),
        vertFlexObj = PhysObj(vertFlexParamsRear)
    }
}

local function flexFilter(prev, input, dt, tau)
    -- Exponential smoothing filter (lowpass)
    local alpha = dt / (tau + dt)
    return prev + alpha * (input - prev)
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

    local tireLF_latFlexInput = car.wheels[0].fy --flexFilter(data.controllerInputs[0], car.wheels[0].fy, dt, 0.0005)
    local tireRF_latFlexInput = car.wheels[1].fy --flexFilter(data.controllerInputs[1], car.wheels[1].fy, dt, 0.05)
    local tireLR_latFlexInput = car.wheels[2].fy --flexFilter(data.controllerInputs[2], car.wheels[2].fy, dt, 0.05)
    local tireRR_latFlexInput = car.wheels[3].fy --flexFilter(data.controllerInputs[3], car.wheels[3].fy, dt, 0.05)

    local tireLF_vertFlexInput = car.wheels[0].load --flexFilter(data.controllerInputs[4], car.wheels[0].load, dt, 0.0005)
    local tireRF_vertFlexInput = car.wheels[1].load --flexFilter(data.controllerInputs[5], car.wheels[1].load, dt, 0.05)
    local tireLR_vertFlexInput = car.wheels[2].load --flexFilter(data.controllerInputs[6], car.wheels[2].load, dt, 0.05)
    local tireRR_vertFlexInput = car.wheels[3].load --flexFilter(data.controllerInputs[7], car.wheels[3].load, dt, 0.05)

    tireFlex.leftFront.latFlexObj:step(tireLF_latFlexInput or 0, dt)
    tireFlex.rightFront.latFlexObj:step(tireRF_latFlexInput or 0, dt)
    tireFlex.leftRear.latFlexObj:step(tireLR_latFlexInput or 0, dt)
    tireFlex.rightRear.latFlexObj:step(tireRR_latFlexInput or 0, dt)

    data.controllerInputs[0] = tireFlex.leftFront.latFlexObj.position
    data.controllerInputs[1] = tireFlex.rightFront.latFlexObj.position
    data.controllerInputs[2] = tireFlex.leftRear.latFlexObj.position
    data.controllerInputs[3] = tireFlex.rightRear.latFlexObj.position

    tireFlex.leftFront.vertFlexObj:step(tireLF_vertFlexInput or 0, dt)
    tireFlex.rightFront.vertFlexObj:step(tireRF_vertFlexInput or 0, dt)
    tireFlex.leftRear.vertFlexObj:step(tireLR_vertFlexInput or 0, dt)
    tireFlex.rightRear.vertFlexObj:step(tireRR_vertFlexInput or 0, dt)

    data.controllerInputs[4] = tireFlex.leftFront.vertFlexObj.position
    data.controllerInputs[5] = tireFlex.rightFront.vertFlexObj.position
    data.controllerInputs[6] = tireFlex.leftRear.vertFlexObj.position
    data.controllerInputs[7] = tireFlex.rightRear.vertFlexObj.position

    ac.debug("tireLF_latFlexInput: ", tireLF_latFlexInput)
    ac.debug("tireRF_latFlexInput: ", tireRF_latFlexInput)
    ac.debug("tireLR_latFlexInput: ", tireLR_latFlexInput)
    ac.debug("tireRR_latFlexInput: ", tireRR_latFlexInput)
    ac.debug("tireLF_vertFlexInput: ", tireLF_vertFlexInput)
    ac.debug("tireRF_vertFlexInput: ", tireRF_vertFlexInput)
    ac.debug("tireLR_vertFlexInput: ", tireLR_vertFlexInput)
    ac.debug("tireRR_vertFlexInput: ", tireRR_vertFlexInput)
    ac.debug("tireLF_latFlexObj.position: ", tireFlex.leftFront.latFlexObj.position)
    ac.debug("tireRF_latFlexObj.position: ", tireFlex.rightFront.latFlexObj.position)
    ac.debug("tireLR_latFlexObj.position: ", tireFlex.leftRear.latFlexObj.position)
    ac.debug("tireRR_latFlexObj.position: ", tireFlex.rightRear.latFlexObj.position)
    ac.debug("tireLF_vertFlexObj.position: ", tireFlex.leftFront.vertFlexObj.position)
    ac.debug("tireRF_vertFlexObj.position: ", tireFlex.rightFront.vertFlexObj.position)
    ac.debug("tireLR_vertFlexObj.position: ", tireFlex.leftRear.vertFlexObj.position)
    ac.debug("tireRR_vertFlexObj.position: ", tireFlex.rightRear.vertFlexObj.position)
    ac.debug("data.controllerInputs[0]: ", data.controllerInputs[0])
    ac.debug("data.controllerInputs[1]: ", data.controllerInputs[1])
    ac.debug("data.controllerInputs[2]: ", data.controllerInputs[2])
    ac.debug("data.controllerInputs[3]: ", data.controllerInputs[3])
    ac.debug("data.controllerInputs[4]: ", data.controllerInputs[4])
    ac.debug("data.controllerInputs[5]: ", data.controllerInputs[5])
    ac.debug("data.controllerInputs[6]: ", data.controllerInputs[6])
    ac.debug("data.controllerInputs[7]: ", data.controllerInputs[7])

    throttle.update(dt)
    sharedData.update()
end
