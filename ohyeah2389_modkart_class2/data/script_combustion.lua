-- Modular Kart Class 2 CSP Physics Script - Internal Combustion Engine Physics Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local helpers = require('script_helpers')


local twoStroke = {}


function twoStroke.getEffectiveThrottle(rawGas, dt)
    local rpmFactor = helpers.mapRange(game.car_cphys.rpm, config.engine.throttle.lagMinRPM, config.engine.throttle.lagMaxRPM, 0.5, 10, true)
    local lagCoefficient = math.exp(-rpmFactor * dt)
    local laggedThrottle = rawGas > state.engine.previousThrottle and math.lerp(rawGas, state.engine.previousThrottle, lagCoefficient) or rawGas
    local effectiveThrottle = math.clamp(game.car_cphys.rpm > (config.engine.throttle.curveTop * laggedThrottle ^ config.engine.throttle.gamma) and ((config.engine.throttle.curveTop / game.car_cphys.rpm) * laggedThrottle ^ config.engine.throttle.gamma) ^ config.engine.throttle.mapGamma or 1, 0, 1)
    local idleThrottle = helpers.mapRange(game.car_cphys.rpm, config.engine.throttle.idle.startRPM, config.engine.throttle.idle.endRPM, config.engine.throttle.idle.position, 0, true)
    local laggedIdleThrottle = idleThrottle > state.engine.previousIdleThrottle and math.lerp(idleThrottle, state.engine.previousIdleThrottle, lagCoefficient) or idleThrottle
    local throttleFadeout = helpers.mapRange(game.car_cphys.rpm, 0, 300, 0, 1, true)
    state.engine.previousThrottle = laggedThrottle
    state.engine.previousIdleThrottle = laggedIdleThrottle
    ac.debug("effectiveThrottle", effectiveThrottle)
    return car.extraB and 0 or helpers.mapRange(helpers.quarticInverse(effectiveThrottle), 0, 1, laggedIdleThrottle, 1, true) * throttleFadeout
end


function twoStroke.update(dt)
    local zeroCurve = helpers.mapRange(game.car_cphys.rpm, 0, config.engine.zeroRPMRange, 0.001, config.engine.zeroRPMTorque, false)
    local coastCurve = helpers.mapRange(game.car_cphys.rpm, 0, config.engine.coastRPM, 0, config.engine.coastTorque, false)
    local powerCurve = config.engine.torqueCurveLUT:get(game.car_cphys.rpm) * config.engine.torqueTrimmer

    local angularVelocity = (helpers.mapRange(game.car_cphys.rpm, 5, 10, 0, game.car_cphys.rpm, true) * (2 * math.pi / 60)) -- Convert RPM to radians per second
    state.engine.angle = (state.engine.angle + (angularVelocity * dt)) % (2 * math.pi) -- Update angle in radians

    state.engine.compressionWave = -0.5 + (1 / (1 + math.exp(-config.engine.compressionOffsetGamma * (math.sin(-state.engine.angle * config.engine.cylindersAmount) - (config.engine.compressionOffset * ((twoStroke.getEffectiveThrottle(game.car_cphys.gas, dt) - 0.5) * -2))))))
    state.engine.compressionTorque = state.engine.compressionWave * config.engine.compressionIntensity *
        helpers.mapRange(game.car_cphys.rpm, config.engine.compressionMinRPM, config.engine.compressionMaxRPM, 1, 0, true) *
        helpers.mapRange(game.car_cphys.rpm, 1, 200, 0, 1, true) -- *
        --helpers.mapRange(game.car_cphys.gas, 0, 1, 0.6, 1, true)

    state.engine.torque = helpers.mapRange(twoStroke.getEffectiveThrottle(game.car_cphys.gas, dt), 0, 1,
        helpers.mapRange(game.car_cphys.rpm, config.engine.zeroRPMRange, config.engine.zeroRPMRange + 2000, zeroCurve, coastCurve, true),
        helpers.mapRange(game.car_cphys.rpm, config.engine.zeroRPMRange, config.engine.zeroRPMRange + 2000, zeroCurve, powerCurve, true),
        true) + state.engine.compressionTorque
end


return twoStroke
