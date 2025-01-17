-- Modular Kart Class 2 CSP Physics Script - Starter Motor Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local electricMotor = require('script_electricMotor')


local starter = {}


local starterMotor = electricMotor{
    resistance = config.electricMotors.starter.resistance,
    inductance = config.electricMotors.starter.inductance,
    torqueConstant = config.electricMotors.starter.torqueConstant,
    backEMFConstant = config.electricMotors.starter.backEMFConstant,
    inertia = config.electricMotors.starter.inertia,
    frictionCoefficient = config.electricMotors.starter.frictionCoefficient,
    maxCurrent = config.electricMotors.starter.maxCurrent,
    linkedRPM = function() return game.car_cphys.rpm end,
}


function starter.update(dt)
    local starterRPM = (starterMotor.physics.angularSpeed * 60 / (2 * math.pi))
    local appliedVoltage = 0.0

    -- starter engagement logic
    if car.extraA and not car.extraB then
        if not starterMotor.engaged and (math.abs(starterRPM - game.car_cphys.rpm) <= config.starter.engagementThresholdRPM) and state.engine.torque < config.starter.bendixKickoffTorque then
            starterMotor.engaged = true
        end
        if starterMotor.engaged and state.engine.torque > (starterMotor.torque + config.starter.bendixKickoffTorque) then
            starterMotor.engaged = false
        end
        appliedVoltage = state.battery.voltage
    else
        starterMotor.engaged = false
    end

    -- Calculate load torque considering gear ratio
    local loadTorque = starterMotor.engaged and state.engine.torque or 0

    if state.starter.engaged then
        if state.engine.torque > starterMotor.torque + config.starter.bendixKickoffTorque then
            starterMotor.engaged = false
        end
    end

    starterMotor:update(appliedVoltage, loadTorque, dt)

    state.starter.torque = starterMotor.torque
    state.starter.engaged = starterMotor.engaged

    -- Debug output
    ac.debug("starterMotor.torque", starterMotor.torque)
    ac.debug("state.starter.torque", state.starter.torque)
    ac.debug("starterMotor.physics.angularSpeed", starterMotor.physics.angularSpeed)
    ac.debug("starterMotor.current", starterMotor.current)
    ac.debug("starterMotor.voltage", starterMotor.voltage)
    ac.debug("state.starter.engaged", state.starter.engaged)
    ac.debug("starterMotor.RPM", starterRPM)
end


return starter