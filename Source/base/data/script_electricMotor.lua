-- Mach 5 CSP Physics Script - Starter Motor Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local physics = require('script_physics')


local electricMotor = class("ElectricMotor")


function electricMotor:initialize(params)
    -- Motor parameters
    self.resistance = params.resistance
    self.inductance = params.inductance or 0.001
    self.torqueConstant = params.torqueConstant
    self.backEMFConstant = params.backEMFConstant
    self.inertia = params.inertia
    self.frictionCoefficient = params.frictionCoefficient or 0.01
    self.maxCurrent = params.maxCurrent or 1000
    self.linkedRPM = params.linkedRPM -- This should be a function that returns the current RPM
    self.engaged = true

    -- State variables
    self.current = 0
    self.voltage = 0
    self.torque = 0

    self.physics = physics{
        rotary = true,
        inertia = self.inertia,
        frictionCoef = self.frictionCoefficient,
        forceMax = 10000,
        springCoef = 0,
        constantForce = 0,
    }
end


function electricMotor:update(appliedVoltage, loadTorque, dt)
    -- Calculate back EMF
    local backEMF = self.backEMFConstant * self.physics.angularSpeed

    -- Calculate current (using differential equation for RL circuit)
    local didt = (appliedVoltage - backEMF - self.resistance * self.current) / self.inductance
    self.current = math.max(-self.maxCurrent, math.min(self.maxCurrent, self.current + didt * dt))

    -- Calculate motor torque
    self.torque = self.torqueConstant * self.current

    -- Apply load torque
    local netTorque = self.torque - loadTorque

    -- Update physics
    self.physics:step(netTorque, dt)

    -- Update motor state
    self.voltage = appliedVoltage

    if self.engaged then
        local currentRPM = self.linkedRPM()
        self.physics.angularSpeed = currentRPM * (2 * math.pi / 60)
    end
end


return electricMotor
