-- Modular Kart Class 2 CSP Physics Script - Starter Motor Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')


local starter = {}


function starter.update(dt)
    if car.extraA and ((state.starter.rpm / config.starter.gearRatio) >= (game.car_cphys.rpm - config.starter.engagementThresholdRPM) and (state.starter.rpm / config.starter.gearRatio) <= (game.car_cphys.rpm + config.starter.engagementThresholdRPM)) then
        state.starter.engaged = true
    else
        state.starter.engaged = false
    end

    local appliedVoltage = 0.0

    if car.extraA then
        appliedVoltage = state.battery.voltage
    end

    local backEMF = state.starter.rpm * config.starter.backEMFConstant
    state.starter.voltageDraw = appliedVoltage - backEMF
    state.starter.current = state.starter.voltageDraw / config.starter.resistance
    state.starter.torque = ((state.starter.current * config.starter.efficiency) * config.starter.stallTorque / (config.starter.nominalVoltage / config.starter.resistance)) - (state.starter.rpm * config.starter.dragCoefficient)
    local angularAcceleration = state.starter.torque / config.starter.inertia

    state.starter.rpm = state.starter.rpm + (angularAcceleration * 60 / (2 * math.pi) * dt)

    local rpmDelta = (state.starter.rpm / config.starter.gearRatio) - game.car_cphys.rpm
    ac.debug("rpmDelta", rpmDelta)
    
    if state.starter.engaged then
        state.engine.torque = state.engine.torque + state.starter.torque
        state.starter.rpm = game.car_cphys.rpm * config.starter.gearRatio
    elseif car.extraA then
        state.starter.rpm = state.starter.rpm - (rpmDelta * config.starter.grindCoefficient)
    end
end


return starter