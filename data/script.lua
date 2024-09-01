-- Modular Kart Class 2 CSP Physics Script - Main Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local twoStroke = require('script_twoStroke')
local starter = require('script_starter')
local clutch = require('script_clutch')
local drivetrain = require('script_drivetrain')
local thermal = require('script_thermal')

local lastDebugTime = os.clock()

-- Shows specific variables in debug
local function showDebugValues()
    if os.clock() - lastDebugTime > 0.2 then
        lastDebugTime = os.clock()
        ac.debug("state.engine.torque", state.engine.torque)
        ac.debug("state.engine.compressionTorque", state.engine.compressionTorque)
        ac.debug("state.engine.compressionWave", state.engine.compressionWave)
        ac.debug("state.engine.angle", state.engine.angle)
        ac.debug("state.starter.rpm", state.starter.rpm)
        ac.debug("state.starter.engaged", state.starter.engaged)
        ac.debug("state.starter.torque", state.starter.torque)
        ac.debug("state.starter.voltageDraw", state.starter.voltageDraw)
        ac.debug("state.thermal.airFuelRatio", state.thermal.airFuelRatio)
        ac.debug("state.thermal.afrDetuneEffect", state.thermal.afrDetuneEffect)
        for componentName, component in pairs(state.thermal.components) do
            ac.debug("state.thermal.components." .. componentName .. ".temp", component.temp)
        end
    end
end


local function resetState()
end


local jetHighClose = ac.ControlButton("__EXT_LIGHT_JETHIGH_CLOSE")
local jetHighOpen = ac.ControlButton("__EXT_LIGHT_JETHIGH_OPEN")
local jetLowClose = ac.ControlButton("__EXT_LIGHT_JETLOW_CLOSE")
local jetLowOpen = ac.ControlButton("__EXT_LIGHT_JETLOW_OPEN")

jetHighClose:onPressed(function()
    state.engine.highSpeedJet = math.max(0, math.min(8, state.engine.highSpeedJet - 0.25))
end)

jetHighOpen:onPressed(function()
    state.engine.highSpeedJet = math.max(0, math.min(8, state.engine.highSpeedJet + 0.25))
end)

jetLowClose:onPressed(function()
    state.engine.lowSpeedJet = math.max(0, math.min(8, state.engine.lowSpeedJet - 0.25))
end)

jetLowOpen:onPressed(function()
    state.engine.lowSpeedJet = math.max(0, math.min(8, state.engine.lowSpeedJet + 0.25))
end)


local function brakeAutoHold()
    if game.car_cphys.speedKmh < config.misc.brakeAutoHold.speed and game.car_cphys.gas == 0 then
        ac.overrideBrakesTorque(2, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
        ac.overrideBrakesTorque(3, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
    else
        ac.overrideBrakesTorque(2, math.nan, math.nan)
        ac.overrideBrakesTorque(3, math.nan, math.nan)
    end
end


-- Called when car teleports to pits or session resets
---@diagnostic disable-next-line: duplicate-set-field
function script.reset()
    resetState()
end


-- Run by game every physics tick (~333 Hz)
---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.awakeCarPhysics()

    brakeAutoHold()

    twoStroke.update(dt)
    starter.update(dt)
    drivetrain.update(dt)
    clutch.update(dt)
    thermal.update(dt)

    ac.overrideGasInput(1) -- physics gas input is required to be 1 at all times to correctly override stock engine model
    ac.disableEngineLimiter(true)
    ac.overrideEngineTorque(state.engine.torque)

    showDebugValues()
end