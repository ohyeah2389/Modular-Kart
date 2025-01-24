-- Modular Kart Class 2 CSP Physics Script - Internal Combustion Engine Physics Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local helpers = require('script_helpers')


local twoStroke = {}


function twoStroke.getEffectiveThrottle(rawGas, dt)
    local idledThrottle = math.clamp(helpers.mapRange(game.car_cphys.rpm, 0, config.engine.throttle.idleRPM, 1, 0, true), 0, config.engine.throttle.idleMaxThrottle) + rawGas
    local laggedThrottle = state.engine.previousThrottle and math.applyLag(state.engine.previousThrottle, idledThrottle, helpers.mapRange(game.car_cphys.rpm, config.engine.throttle.lagMaxRPM, config.engine.throttle.lagMinRPM, config.engine.throttle.lagMax, config.engine.throttle.lagMin, true), dt) or rawGas
    local realisticThrottle = math.clamp(
            (config.engine.throttle.topRPM / game.car_cphys.rpm)
            * laggedThrottle ^ (
                ((1 - ((game.car_cphys.rpm / config.engine.throttle.topRPM) ^ (config.engine.throttle.tilt / config.engine.throttle.shift)))
                * (config.engine.throttle.peel * config.engine.throttle.shift))
                + ((game.car_cphys.rpm / config.engine.throttle.topRPM) ^ (config.engine.throttle.tilt / config.engine.throttle.shift))
            ),
            0, 1)
    ac.debug("rawGas", rawGas)
    ac.debug("realisticThrottle", realisticThrottle)
    ac.debug("laggedThrottle", laggedThrottle)
    state.engine.previousThrottle = laggedThrottle
    return car.extraB and 0 or realisticThrottle ^ config.engine.throttle.gamma
end


function twoStroke.update(dt)
    local zeroCurve = helpers.mapRange(game.car_cphys.rpm, 0, config.engine.zeroRPMRangeBottom, 0, config.engine.zeroRPMTorque, false)
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
        helpers.mapRange(game.car_cphys.rpm, config.engine.zeroRPMRangeBottom, config.engine.zeroRPMRangeTop, zeroCurve, coastCurve, true),
        helpers.mapRange(game.car_cphys.rpm, config.engine.zeroRPMRangeBottom, config.engine.zeroRPMRangeTop, zeroCurve, powerCurve, true),
        true) + state.engine.compressionTorque
end


return twoStroke
