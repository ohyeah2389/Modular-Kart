-- Modular Kart Class 2 CSP Physics Script - Internal Combustion Engine Physics Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local helpers = require('script_helpers')


local twoStroke = {}


function twoStroke.getEffectiveThrottle(rawGas)
    local effectiveThrottle = math.min(((22380 * rawGas ^ config.engine.throttle.gamma)/(math.pi * game.car_cphys.rpm * (config.engine.throttle.rho ^ config.engine.throttle.gamma) + config.engine.throttle.epsilon)), 1)
    local idleThrottle = helpers.mapRange(game.car_cphys.rpm, config.engine.throttle.idle.startRPM, config.engine.throttle.idle.endRPM, config.engine.throttle.idle.position, 0, true)
    return car.extraB and 0 or helpers.mapRange(helpers.quarticInverse(effectiveThrottle), 0, 1, idleThrottle, 1, true)
end


function twoStroke.update(dt)
    local zeroCurve = helpers.mapRange(game.car_cphys.rpm, 0, config.engine.zeroRPMRange, 0.001, config.engine.zeroRPMTorque, false)
    local coastCurve = helpers.mapRange(game.car_cphys.rpm, 0, config.engine.coastRPM, 0, config.engine.coastTorque, false)
    local powerCurve = config.engine.torqueCurveLUT:get(game.car_cphys.rpm) * config.engine.torqueTrimmer

    local angularVelocity = (helpers.mapRange(game.car_cphys.rpm, 5, 10, 0, game.car_cphys.rpm, true) * (2 * math.pi / 60)) -- Convert RPM to radians per second
    state.engine.angle = (state.engine.angle + (angularVelocity * dt)) % (2 * math.pi) -- Update angle in radians

    state.engine.compressionWave = -0.5 + (1 / (1 + math.exp(-config.engine.compressionOffsetGamma * (math.sin(-state.engine.angle * config.engine.cylindersAmount) - (config.engine.compressionOffset * ((twoStroke.getEffectiveThrottle(game.car_cphys.gas) - 0.5) * -2))))))
    state.engine.compressionTorque = state.engine.compressionWave * config.engine.compressionIntensity *
        helpers.mapRange(game.car_cphys.rpm, config.engine.compressionMinRPM, config.engine.compressionMaxRPM, 1, 0, true) *
        helpers.mapRange(game.car_cphys.rpm, 1, 200, 0, 1, true) -- *
        --helpers.mapRange(game.car_cphys.gas, 0, 1, 0.6, 1, true)

    state.engine.torque = helpers.mapRange(twoStroke.getEffectiveThrottle(game.car_cphys.gas), 0, 1,
        helpers.mapRange(game.car_cphys.rpm, config.engine.zeroRPMRange, config.engine.zeroRPMRange + 2000, zeroCurve, coastCurve, true),
        helpers.mapRange(game.car_cphys.rpm, config.engine.zeroRPMRange, config.engine.zeroRPMRange + 2000, zeroCurve, powerCurve * state.thermal.afrDetuneEffect, true),
        true) + state.engine.compressionTorque
end


return twoStroke